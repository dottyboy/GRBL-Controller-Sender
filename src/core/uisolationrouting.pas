unit uisolationrouting;

{ uisolationrouting: turns ugerberimport.pas's parsed Gerber features into
  isolation-routing toolpaths (plan Phase 33) - offset boundary rings
  around copper that a CNC end mill can follow without touching the
  copper, the same real technique Visolate/FlatCAM/pcb2gcode all use
  (all three read as reference before writing this - see ugerberimport.pas's
  own header for the license-verification details).

  Uses the real Clipper2 polygon-clipping/offsetting library (Angus
  Johnson, Boost license) that ships bundled with CodeTyphon itself
  (pl_Image32 package, components/packages_pl/pl_Image32/source/
  Clipper*.pas) - confirmed to have zero LCL/GUI dependencies (only
  SysUtils/Classes/Math) before using it here, so this unit stays
  LCL-free and standalone-testable like every other core unit. NOTE:
  the plan file's own Phase 33 text assumed Clipper was "already
  vendored" by an earlier phase - checked and found that was stale:
  Phase 12 explicitly DEFERRED adding Clipper rather than adding it, so
  this phase adds the real dependency (RequiredPackages gains
  pl_Image32) rather than reusing something already there.

  Aperture flash shapes (circle/rect/obround/regular-polygon) are
  hand-built as polygons via trigonometry, the same way camlib.py's own
  `create_flash_geometry()` builds them (Shapely's `.buffer()` for a
  circle, explicit corner math for rect, two-arc "stadium" for obround,
  explicit N-gon for polygon) - Clipper has no native circle/curve
  primitive, same as Shapely under the hood. Stroke widths use Clipper's
  own `InflatePaths` with `etRound` end/join type instead - the actual
  intended use of that API (buffering a line by its own width), not
  hand-rolled. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, ui18n, ugerberimport, Clipper, Clipper.Core;

type
  TIsoLoop = TGerberPointArray;       // one closed ring (first point implied closing back to itself)
  TIsoLoopArray = array of TIsoLoop;  // every loop belonging to one XY-offset pass
  TIsoPassArray = array of TIsoLoopArray; // every XY-offset pass, in cutting order

  TIsolationConfig = record
    ToolDiameter: Double;   // mm
    IsolationGap: Double;   // mm, extra clearance beyond the tool's own radius
    Passes: Integer;        // number of concentric offset rings (>=1)
    PassStepover: Double;   // mm between successive passes' offset distance
    CutDepth: Double;       // mm, positive (total depth below Z0)
    DepthPerPass: Double;   // mm, positive
    SafeZ: Double;          // mm, retract height
    FeedRate: Double;       // mm/min, XY cutting feed
    PlungeRate: Double;     // mm/min, Z plunge feed
    SpindleRPM: Integer;    // 0 = don'trk emit S/M3 (assume already running)
  end;

  TIsoDoubleArray = array of Double;

  EGenerateError = class(Exception);

function DefaultIsolationConfig: TIsolationConfig;
procedure ValidateIsolationConfig(const ACfg: TIsolationConfig);

{ BuildCopperSolidLoops: the unioned/polarity-resolved copper image, as
  closed loops in mm - exposed mainly for standalone testing (checking
  the union/difference step in isolation from the offset step). }
function BuildCopperSolidLoops(const AFeatures: TGerberFeatureArray): TIsoLoopArray;

{ GenerateIsolationToolpaths: the main entry point. Each pass p (0-based)
  offsets the copper solid outward by ToolDiameter/2 + IsolationGap +
  p*PassStepover; multiple disjoint copper islands each produce their own
  loop(s) within a pass. }
function GenerateIsolationToolpaths(const AFeatures: TGerberFeatureArray;
  const ACfg: TIsolationConfig): TIsoPassArray;

{ AppendIsolationGCode: emits G-code for every loop of every pass, cutting
  each loop to full depth (in DepthPerPass steps) before moving to the
  next - same ALines: TStrings convention as uspoilboard.pas. }
procedure AppendIsolationGCode(const APasses: TIsoPassArray;
  const ACfg: TIsolationConfig; ALines: TStrings);

implementation

const
  ISO_PRECISION = 5; // decimal digits Clipper's TPathsD overloads keep -
                      // plenty for PCB-scale mm geometry (sub-micron).
  FLASH_CIRCLE_SEGMENTS = 32;
  FLASH_STADIUM_SEGMENTS = 16; // per end-cap semicircle

var
  GInvFS: TFormatSettings;

function DefaultIsolationConfig: TIsolationConfig;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.ToolDiameter := 0.2;
  Result.IsolationGap := 0.1;
  Result.Passes := 1;
  Result.PassStepover := 0.15;
  Result.CutDepth := 0.1;
  Result.DepthPerPass := 0.1;
  Result.SafeZ := 5;
  Result.FeedRate := 300;
  Result.PlungeRate := 100;
  Result.SpindleRPM := 0;
end;

procedure ValidateIsolationConfig(const ACfg: TIsolationConfig);
begin
  if ACfg.ToolDiameter <= 0 then
    raise EGenerateError.Create(T('Isolation routing: tool diameter must be positive.'));
  if ACfg.IsolationGap < 0 then
    raise EGenerateError.Create(T('Isolation routing: isolation gap cannot be negative.'));
  if ACfg.Passes < 1 then
    raise EGenerateError.Create(T('Isolation routing: at least 1 pass is required.'));
  if (ACfg.Passes > 1) and (ACfg.PassStepover <= 0) then
    raise EGenerateError.Create(T('Isolation routing: pass stepover must be positive when more than 1 pass is requested.'));
  if ACfg.CutDepth <= 0 then
    raise EGenerateError.Create(T('Isolation routing: cut depth must be positive.'));
  if ACfg.DepthPerPass <= 0 then
    raise EGenerateError.Create(T('Isolation routing: depth per pass must be positive.'));
end;

{ ---- point-array <-> Clipper TPathD conversion ---- }

function ToPathD(const APoints: TGerberPointArray): TPathD;
var
  i: Integer;
begin
  SetLength(Result, Length(APoints));
  for i := 0 to High(APoints) do
  begin
    Result[i].X := APoints[i].X;
    Result[i].Y := APoints[i].Y;
  end;
end;

function FromPathD(const APath: TPathD): TGerberPointArray;
var
  i: Integer;
begin
  SetLength(Result, Length(APath));
  for i := 0 to High(APath) do
  begin
    Result[i].X := APath[i].X;
    Result[i].Y := APath[i].Y;
  end;
end;

const
  // Below this absolute area (mm^2), a "loop" is discarded as a
  // degenerate sliver rather than a real feature - general defensive
  // hygiene for any polygon-clipping pipeline (a literal zero/near-zero-
  // area "ring" is never something a real CNC job should try to cut),
  // independent of NormalizeWindingForOffset (see its own comment) which
  // fixes the actual root cause found during this phase's own testing:
  // an inconsistently-wound closed path fed into InflatePaths(...,
  // etPolygon, ...) reproducibly shattered into many disconnected
  // fragments instead of offsetting as one continuous boundary.
  MIN_LOOP_AREA_MM2 = 1.0E-4;

function PolygonAreaAbs(const ALoop: TGerberPointArray): Double;
var
  i, n: Integer;
  sum: Double;
begin
  n := Length(ALoop);
  if n < 3 then Exit(0);
  sum := 0;
  for i := 0 to n - 1 do
    sum := sum + (ALoop[i].X * ALoop[(i + 1) mod n].Y
                 - ALoop[(i + 1) mod n].X * ALoop[i].Y);
  Result := Abs(sum) / 2;
end;

function PathsDToLoops(const APaths: TPathsD): TIsoLoopArray;
var
  i, n: Integer;
  loop: TGerberPointArray;
begin
  SetLength(Result, Length(APaths));
  n := 0;
  for i := 0 to High(APaths) do
  begin
    loop := FromPathD(APaths[i]);
    if PolygonAreaAbs(loop) < MIN_LOOP_AREA_MM2 then Continue;
    Result[n] := loop;
    Inc(n);
  end;
  SetLength(Result, n);
end;

{ ---- Flash shape builders, ported from camlib.py's create_flash_geometry() ---- }

function CircleFlashPath(ACx, ACy, ARadius: Double): TPathD;
var
  i: Integer;
begin
  // Winding direction here doesn't matter - NormalizeWindingForOffset
  // (see its own comment) fixes up every shape's orientation uniformly
  // right before the actual offset step, once, in one place, rather
  // than needing every individual polygon builder to get it right.
  SetLength(Result, FLASH_CIRCLE_SEGMENTS);
  for i := 0 to FLASH_CIRCLE_SEGMENTS - 1 do
  begin
    Result[i].X := ACx + ARadius * Cos(2 * Pi * i / FLASH_CIRCLE_SEGMENTS);
    Result[i].Y := ACy + ARadius * Sin(2 * Pi * i / FLASH_CIRCLE_SEGMENTS);
  end;
end;

function RectFlashPath(ACx, ACy, AWidth, AHeight: Double): TPathD;
begin
  SetLength(Result, 4);
  Result[0].X := ACx - AWidth / 2; Result[0].Y := ACy - AHeight / 2;
  Result[1].X := ACx + AWidth / 2; Result[1].Y := ACy - AHeight / 2;
  Result[2].X := ACx + AWidth / 2; Result[2].Y := ACy + AHeight / 2;
  Result[3].X := ACx - AWidth / 2; Result[3].Y := ACy + AHeight / 2;
end;

{ Stadium shape (two semicircular end caps joined by straight sides),
  same construction as camlib.py's obround handling (two circles + convex
  hull) but built directly as one closed contour instead of computing a
  hull. }
function ObroundFlashPath(ACx, ACy, AWidth, AHeight: Double): TPathD;
var
  horizontal: Boolean;
  capRadius, halfSpan: Double;
  c1, c2: TGerberPoint;
  pts: array of TGerberPoint;
  i, n: Integer;
  ang, a0, a1: Double;
begin
  horizontal := AWidth > AHeight;
  if horizontal then
  begin
    capRadius := AHeight / 2;
    halfSpan := (AWidth - AHeight) / 2;
    c1.X := ACx + halfSpan; c1.Y := ACy; // right cap center
    c2.X := ACx - halfSpan; c2.Y := ACy; // left cap center
    a0 := -Pi / 2; a1 := Pi / 2; // right cap sweeps -90..+90 around c1
  end
  else
  begin
    capRadius := AWidth / 2;
    halfSpan := (AHeight - AWidth) / 2;
    c1.X := ACx; c1.Y := ACy + halfSpan; // top cap center
    c2.X := ACx; c2.Y := ACy - halfSpan; // bottom cap center
    a0 := 0; a1 := Pi; // "right"(top) cap sweeps 0..180 around c1
  end;

  SetLength(pts, 0);
  n := FLASH_STADIUM_SEGMENTS;
  for i := 0 to n do
  begin
    ang := a0 + (a1 - a0) * i / n;
    SetLength(pts, Length(pts) + 1);
    pts[High(pts)].X := c1.X + capRadius * Cos(ang);
    pts[High(pts)].Y := c1.Y + capRadius * Sin(ang);
  end;
  for i := 0 to n do
  begin
    ang := (a0 + Pi) + (a1 - a0) * i / n;
    SetLength(pts, Length(pts) + 1);
    pts[High(pts)].X := c2.X + capRadius * Cos(ang);
    pts[High(pts)].Y := c2.Y + capRadius * Sin(ang);
  end;
  Result := ToPathD(pts);
end;

function PolygonFlashPath(ACx, ACy, ADiameter: Double; ANVertices: Integer;
  ARotationDeg: Double): TPathD;
var
  i: Integer;
  ang, rot: Double;
begin
  if ANVertices < 3 then ANVertices := 3;
  rot := ARotationDeg * Pi / 180;
  SetLength(Result, ANVertices);
  for i := 0 to ANVertices - 1 do
  begin
    ang := rot + 2 * Pi * i / ANVertices;
    Result[i].X := ACx + 0.5 * ADiameter * Cos(ang);
    Result[i].Y := ACy + 0.5 * ADiameter * Sin(ang);
  end;
end;

function FlashToPathsD(const AFeature: TGerberFeature): TPathsD;
var
  cx, cy: Double;
  ap: TGerberAperture;
begin
  SetLength(Result, 0);
  if Length(AFeature.Points) < 1 then Exit;
  cx := AFeature.Points[0].X;
  cy := AFeature.Points[0].Y;
  ap := AFeature.Aperture;
  SetLength(Result, 1);
  case ap.Kind of
    gakCircle: Result[0] := CircleFlashPath(cx, cy, ap.Size / 2);
    gakRect: Result[0] := RectFlashPath(cx, cy, ap.Width, ap.Height);
    gakObround: Result[0] := ObroundFlashPath(cx, cy, ap.Width, ap.Height);
    gakPolygon: Result[0] := PolygonFlashPath(cx, cy, ap.Diameter, ap.NVertices, ap.Rotation);
  else
    SetLength(Result, 0); // gakMacro - ugerberimport.pas already skips
                           // emitting these as flash features, but stay
                           // safe if one ever slips through.
  end;
end;

function StrokeToPathsD(const AFeature: TGerberFeature): TPathsD;
var
  centerline: TPathsD;
  radius: Double;
begin
  SetLength(centerline, 1);
  centerline[0] := ToPathD(AFeature.Points);
  radius := AFeature.Aperture.Size / 2;
  if radius <= 0 then radius := 0.05; // degenerate/missing aperture guard,
                                       // mirrors ugerberimport.pas's own
                                       // "small but non-zero" fallback.
  Result := InflatePaths(centerline, radius, jtRound, etRound, 2.0, ISO_PRECISION, 0.0);
end;

function ConcatPathsD(const A, B: TPathsD): TPathsD;
var
  i: Integer;
begin
  SetLength(Result, Length(A) + Length(B));
  for i := 0 to High(A) do Result[i] := A[i];
  for i := 0 to High(B) do Result[Length(A) + i] := B[i];
end;

{ NormalizeWindingForOffset: Clipper2's InflatePaths(..., etPolygon, ...)
  needs each closed path consistently wound to reliably grow it outward -
  a real, empirically confirmed requirement (not a memory-corruption
  symptom, though it first looked exactly like one): a hand-built circle
  polygon wound the "wrong" way reproducibly shattered into N disconnected
  4-point fragments (N = vertex count) instead of one smooth offset ring,
  while the SAME points reversed offset correctly every time. Reverses
  every path with Area()>=0 to Area()<0 (the orientation that offsets
  correctly here) - uniformly, so the relative outer-boundary/hole
  relationship Union() already established between paths is preserved,
  only the overall absolute sign flips. }
function NormalizeWindingForOffset(const APaths: TPathsD): TPathsD;
var
  i, dominant: Integer;
  a, maxAbsArea: Double;
begin
  // Flip EVERY path uniformly, or none - never decide per-path. A
  // Union() result's outer boundaries and any holes within them are
  // ALWAYS oppositely wound relative to each other (that's the only way
  // a nonzero/even-odd fill can tell "solid" from "hole" at all) - a
  // real regression caught by this unit's own test suite: an earlier,
  // wrong version of this function reversed each path independently by
  // its own sign, which flips outer boundaries and holes onto the SAME
  // winding, destroying that relationship (the hole silently vanished
  // from InflatePaths's output entirely instead of correctly shrinking).
  // The single largest-area path is (by definition of what an "outer
  // boundary" is) never a hole, so its sign alone decides whether the
  // WHOLE set needs flipping to the orientation InflatePaths(...,
  // etPolygon, ...) needs to offset correctly (empirically confirmed
  // negative Area() in this Y-up coordinate convention).
  SetLength(Result, Length(APaths));
  dominant := -1;
  maxAbsArea := -1;
  for i := 0 to High(APaths) do
  begin
    a := Abs(Area(APaths[i]));
    if a > maxAbsArea then
    begin
      maxAbsArea := a;
      dominant := i;
    end;
  end;

  if (dominant >= 0) and (Area(APaths[dominant]) >= 0) then
  begin
    for i := 0 to High(APaths) do
      Result[i] := ReversePath(APaths[i]);
  end
  else
  begin
    for i := 0 to High(APaths) do
      Result[i] := APaths[i];
  end;
end;

function BuildCopperSolidPathsD(const AFeatures: TGerberFeatureArray): TPathsD;
var
  darkPaths, clearPaths, featurePaths: TPathsD;
  i: Integer;
  region: TPathsD;
begin
  SetLength(darkPaths, 0);
  SetLength(clearPaths, 0);
  for i := 0 to High(AFeatures) do
  begin
    case AFeatures[i].Kind of
      gfkStroke: featurePaths := StrokeToPathsD(AFeatures[i]);
      gfkFlash: featurePaths := FlashToPathsD(AFeatures[i]);
      gfkRegion:
        begin
          SetLength(region, 1);
          region[0] := ToPathD(AFeatures[i].Points);
          featurePaths := region;
        end;
    end;
    if AFeatures[i].Dark then
      darkPaths := ConcatPathsD(darkPaths, featurePaths)
    else
      clearPaths := ConcatPathsD(clearPaths, featurePaths);
  end;

  if Length(darkPaths) = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  Result := Union(darkPaths, frNonZero, ISO_PRECISION);
  if Length(clearPaths) > 0 then
    Result := Difference(Result, clearPaths, frNonZero, ISO_PRECISION);
end;

function BuildCopperSolidLoops(const AFeatures: TGerberFeatureArray): TIsoLoopArray;
begin
  Result := PathsDToLoops(BuildCopperSolidPathsD(AFeatures));
end;

function GenerateIsolationToolpaths(const AFeatures: TGerberFeatureArray;
  const ACfg: TIsolationConfig): TIsoPassArray;
var
  copper: TPathsD;
  p: Integer;
  offsetDist: Double;
begin
  ValidateIsolationConfig(ACfg);
  copper := NormalizeWindingForOffset(BuildCopperSolidPathsD(AFeatures));
  SetLength(Result, ACfg.Passes);
  // Explicitly nil every slot rather than trusting SetLength's implicit
  // zero-init alone - a real, reproduced FPC dynamic-array gotcha: when
  // the CALLER's destination variable previously held a larger/deeper
  // nested-array result (e.g. a prior board's real toolpaths), assigning
  // this function's Result into it can leave slot 0's OWN nested array
  // still pointing at the old backing data instead of being empty, even
  // though Result was "freshly" SetLength'd here. Costly to debug blind -
  // found via a real, empty-board-after-a-real-board standalone test.
  for p := 0 to ACfg.Passes - 1 do
    SetLength(Result[p], 0);
  if Length(copper) = 0 then Exit;
  for p := 0 to ACfg.Passes - 1 do
  begin
    offsetDist := ACfg.ToolDiameter / 2 + ACfg.IsolationGap + p * ACfg.PassStepover;
    Result[p] := PathsDToLoops(
      InflatePaths(copper, offsetDist, jtRound, etPolygon, 2.0, ISO_PRECISION, 0.0));
  end;
end;

function BuildDepthList(ATotalDepth, ADepthPerPass: Double): TIsoDoubleArray;
var
  n, i: Integer;
begin
  n := Ceil(ATotalDepth / ADepthPerPass);
  if n < 1 then n := 1;
  SetLength(Result, n);
  for i := 0 to n - 1 do
    Result[i] := -Min(ADepthPerPass * (i + 1), ATotalDepth);
end;

procedure AppendIsolationGCode(const APasses: TIsoPassArray;
  const ACfg: TIsolationConfig; ALines: TStrings);
var
  depths: TIsoDoubleArray;
  p, l, d, i: Integer;
  loop: TIsoLoop;
begin
  ValidateIsolationConfig(ACfg);
  depths := BuildDepthList(ACfg.CutDepth, ACfg.DepthPerPass);

  ALines.Add('(Isolation routing toolpath generated by GRBL-Controller-Sender)');
  ALines.Add('G21');
  ALines.Add('G90');
  ALines.Add(Format('G0Z%.4f', [ACfg.SafeZ], GInvFS));
  if ACfg.SpindleRPM > 0 then
    ALines.Add(Format('M3S%d', [ACfg.SpindleRPM], GInvFS));

  for p := 0 to High(APasses) do
  begin
    ALines.Add(Format('(--- Isolation pass %d/%d ---)', [p + 1, Length(APasses)]));
    for l := 0 to High(APasses[p]) do
    begin
      loop := APasses[p][l];
      if Length(loop) < 2 then Continue;
      for d := 0 to High(depths) do
      begin
        ALines.Add(Format('G0X%.4fY%.4f', [loop[0].X, loop[0].Y], GInvFS));
        ALines.Add(Format('G1Z%.4fF%g', [depths[d], ACfg.PlungeRate], GInvFS));
        for i := 1 to High(loop) do
          ALines.Add(Format('G1X%.4fY%.4fF%g', [loop[i].X, loop[i].Y, ACfg.FeedRate], GInvFS));
        // close the ring back to its own start point
        ALines.Add(Format('G1X%.4fY%.4fF%g', [loop[0].X, loop[0].Y, ACfg.FeedRate], GInvFS));
        ALines.Add(Format('G0Z%.4f', [ACfg.SafeZ], GInvFS));
      end;
    end;
  end;

  if ACfg.SpindleRPM > 0 then
    ALines.Add('M5');
  ALines.Add('M30');
end;

initialization
  GInvFS := DefaultFormatSettings;
  GInvFS.DecimalSeparator := '.';

end.
