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
  Classes, SysUtils, Math, ui18n, ugerberimport, Clipper, Clipper.Core,
  Clipper.Engine;

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

    // Plan Phase 39's "Clear all copper except traces" strategy (see
    // GenerateClearToolpaths below) - unused by Isolate/Draw, same as
    // Passes/PassStepover are unused by Draw. BoardMargin extends the
    // clear region beyond the copper layer's own bounding box on every
    // side (no separate board-outline Gerber layer needed - the
    // overwhelming common case is a rectangular board a bit bigger than
    // its own copper, and this covers that without the real complexity
    // of parsing/verifying a second Gerber layer for a case this simple
    // margin already handles). ClearStepoverPercent is the raster
    // scan-line spacing, as a % of ToolDiameter, same convention as
    // uspoilboard.pas's own FacingStepoverPercent.
    BoardMargin: Double;
    ClearStepoverPercent: Double;
  end;

  { TLaserConfig: plan Phase 39 - the laser-output sibling of TIsolationConfig.
    No Z field at all: mirrors usvgimportframe.pas's own laser g-code
    convention (M3 S<power>/M5, fixed working height, no Z axis motion). }
  TLaserConfig = record
    Power: Integer;     // S value
    FeedRate: Double;   // mm/min
  end;

  { TIsoPath: plan Phase 39's "Draw" strategy - unlike TIsoLoop (always a
    closed ring from offsetting), a drawn path may be OPEN (a stroke's own
    centerline, e.g. a straight trace segment - the tool should not return
    to its start point) or CLOSED (a region's own boundary, or a flash's
    own aperture outline - already a real closed shape). Closed must be
    tracked explicitly since TGerberPointArray alone can't distinguish the
    two, and forcibly closing an open stroke would draw a spurious return
    segment no real pen/dispenser job wants. }
  TIsoPath = record
    Points: TGerberPointArray;
    Closed: Boolean;
  end;
  TIsoPathArray = array of TIsoPath;

  TIsoDoubleArray = array of Double;

  { TClearSegment/TClearRowArray: plan Phase 39's "Clear all copper except
    traces" strategy - a raster scan-line fill of (board rectangle minus
    copper-plus-keepaway), grouped by row (constant Y) since the cutter
    must rapid over any gap where copper survives rather than plunging
    through it. X1 is always <= X2 within a segment; rows are in
    ascending-Y order, segments within a row in ascending-X1 order (see
    ComputeClearScanSegments). }
  TClearSegment = record
    X1, X2, Y: Double;
  end;
  TClearRow = array of TClearSegment;
  TClearRowArray = array of TClearRow;

  EGenerateError = class(Exception);

function DefaultIsolationConfig: TIsolationConfig;
function DefaultLaserConfig: TLaserConfig;
procedure ValidateIsolationConfig(const ACfg: TIsolationConfig);
procedure ValidateClearConfig(const ACfg: TIsolationConfig);

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

{ AppendIsolationGCodeLaser: the laser-output sibling of AppendIsolationGCode
  for the SAME ring geometry (plan Phase 39's "tool axis") - no Z-depth/
  pass-stepping loop at all, a single M3/M5-bracketed pass per ring per
  offset-pass, matching usvgimportframe.pas's own laser g-code convention. }
procedure AppendIsolationGCodeLaser(const APasses: TIsoPassArray;
  const ALaserCfg: TLaserConfig; ALines: TStrings);

{ GenerateDrawToolpaths: plan Phase 39's "Draw" strategy (CNC only) - walks
  the RAW parsed Gerber features directly (stroke centerlines, region
  outlines, flash aperture shapes at real size), not the offset/unioned
  copper solid. No Clipper offsetting involved, so Phase 33's own winding-
  normalization concern doesn't apply here - nothing gets offset. }
function GenerateDrawToolpaths(const AFeatures: TGerberFeatureArray): TIsoPathArray;

{ AppendDrawGCode: CNC-only (a laser "drawing" ink makes no physical sense,
  and a laser following copper geometry directly is just Isolate with a
  near-zero gap, already covered by that mode) - follows each path's own
  points, using Closed to decide whether to return to the start point. }
procedure AppendDrawGCode(const APaths: TIsoPathArray;
  const ACfg: TIsolationConfig; ALines: TStrings);

{ BuildClearRegion: the copper solid, expanded by ToolDiameter/2 +
  IsolationGap (the same keep-away distance Isolate uses, reused rather
  than duplicated as a separate field), subtracted from a rectangle
  covering the copper's own bounding box grown by BoardMargin on every
  side. Exposed mainly for standalone testing. }
function BuildClearRegion(const AFeatures: TGerberFeatureArray;
  const ACfg: TIsolationConfig): TPathsD;

{ ComputeClearScanSegments: turns a clear region into raster scan-line
  segments at ToolDiameter*ClearStepoverPercent/100 spacing, using
  Clipper2's exact open-path clipping (TClipperD.AddOpenSubject) rather
  than a thin-rectangle approximation - each row is a single infinite-
  looking straight line clipped against the closed region, so the
  returned segment endpoints are exact, not sampled. Exposed mainly for
  standalone testing. }
function ComputeClearScanSegments(const AClearRegion: TPathsD;
  AToolDiameter, AStepoverPercent: Double): TClearRowArray;

{ GenerateClearToolpaths: the main entry point, combining the two above.
  Works for either tool axis (CNC or laser) - ACfg.ToolDiameter doubles
  as the laser's own beam/kerf width for this strategy, same convention
  GenerateIsolationToolpaths already uses for its own ring geometry. }
function GenerateClearToolpaths(const AFeatures: TGerberFeatureArray;
  const ACfg: TIsolationConfig): TClearRowArray;

{ AppendClearGCode/AppendClearGCodeLaser: emit the raster as G-code, one
  row at a time - rapid to each segment's start, cut to its end, rapid
  (not cut) across any gap to the next segment on the same row. Mirrors
  AppendIsolationGCode/AppendIsolationGCodeLaser's own CNC/laser split. }
procedure AppendClearGCode(const ARows: TClearRowArray;
  const ACfg: TIsolationConfig; ALines: TStrings);
procedure AppendClearGCodeLaser(const ARows: TClearRowArray;
  const ALaserCfg: TLaserConfig; ALines: TStrings);

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
  Result.BoardMargin := 5;
  Result.ClearStepoverPercent := 50;
end;

function DefaultLaserConfig: TLaserConfig;
begin
  Result.Power := 200;
  Result.FeedRate := 800;
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

procedure ValidateClearConfig(const ACfg: TIsolationConfig);
begin
  if ACfg.ToolDiameter <= 0 then
    raise EGenerateError.Create(T('Clear copper: tool diameter must be positive.'));
  if ACfg.IsolationGap < 0 then
    raise EGenerateError.Create(T('Clear copper: isolation gap cannot be negative.'));
  if ACfg.BoardMargin < 0 then
    raise EGenerateError.Create(T('Clear copper: board margin cannot be negative.'));
  if (ACfg.ClearStepoverPercent <= 0) or (ACfg.ClearStepoverPercent > 100) then
    raise EGenerateError.Create(T('Clear copper: stepover % must be between 0 and 100.'));
  if ACfg.CutDepth <= 0 then
    raise EGenerateError.Create(T('Clear copper: cut depth must be positive.'));
  if ACfg.DepthPerPass <= 0 then
    raise EGenerateError.Create(T('Clear copper: depth per pass must be positive.'));
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

{ CopyGerberPath: ugerberimport.pas has its own CopyPath, but it's an
  implementation-section (non-exported) helper there - a tiny local copy
  is simpler than exporting it just for this one cross-unit use. }
function CopyGerberPath(const APath: TGerberPointArray): TGerberPointArray;
var
  i: Integer;
begin
  SetLength(Result, Length(APath));
  for i := 0 to High(APath) do
    Result[i] := APath[i];
end;

const
  // Below this absolute area (mm^2), a "loop" is discarded as a
  // degenerate sliver rather than a real feature - general defensive
  // hygiene for any polygon-clipping pipeline (a literal zero/near-zero-
  // area "ring" is never something a real CNC job should try to cut).
  MIN_LOOP_AREA_MM2 = 1.0E-4;
  // Below this gap width (mm), two adjacent clear-scan segments are
  // merged into one rather than cut as two separate moves - see
  // ComputeClearScanSegments's own merge step for why. 0.1mm chosen
  // deliberately generous: a real "obstruction" (keep-away corridor)
  // narrower than this is below what any real end mill/laser kerf could
  // usefully resolve anyway, so treating it as noise costs nothing real.
  MIN_GAP_MM = 0.1;

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
  // Winding direction here doesn't matter - BuildCopperSolidPathsD's own
  // Union()/Difference() step is what determines the final orientation
  // InflatePaths needs, not any individual shape builder's own
  // convention (see BuildCopperSolidPathsD's own doc comment).
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

{ BuildCopperSolidPathsD's output needs NO winding normalization before
  being passed to InflatePaths(..., etPolygon, ...) - Union()/Difference()
  already produce the winding this Clipper2 build offsets correctly
  in, and this unit used to run an extra "NormalizeWindingForOffset" flip
  on top of that (removed here, Phase 39's Clear-copper work) which was
  ACTIVELY WRONG: re-verified directly (three separate, isolated A/B
  tests outside this codebase entirely - a single square pad, a square
  pad with a real hole, two separate islands) that Union/Difference's
  OWN natural output already offsets cleanly with no flip at all, and
  that flipping it (the old function's whole job) reproducibly SHATTERS
  the result into one small fragment per vertex instead of one
  continuous ring - confirmed live via this project's own
  GenerateIsolationToolpaths on a plain 10mm round pad, which the old
  code turned into 32 disconnected 4-point fragments instead of one
  32-point ring. The old function's own comment cited a real empirical
  test (a hand-built circle that needed reversing) - almost certainly a
  RAW, pre-Union shape, a code path this app's actual pipeline never
  takes (every real caller goes through BuildCopperSolidPathsD's own
  Union/Difference first) - so that finding, while presumably accurate
  for what it tested, didn't generalize to the shape this function
  actually has to offset. }
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
  copper := BuildCopperSolidPathsD(AFeatures);
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

{ EmitCNCPointSequence: the shared per-point-sequence CNC emitter both
  AppendIsolationGCode (always-closed offset rings) and AppendDrawGCode
  (open strokes or closed regions/flashes, per APoints' own AClosed) walk
  once per requested depth - plunge, cut through every point, optionally
  close back to the start, retract to safe Z. Extracted rather than left
  duplicated between the two once Phase 39's Draw strategy made the same
  G0/G1-per-depth shape show up a second time with the only real
  difference being the closing segment's own condition. }
procedure EmitCNCPointSequence(const APoints: TGerberPointArray; AClosed: Boolean;
  const ACfg: TIsolationConfig; const ADepths: TIsoDoubleArray; ALines: TStrings);
var
  d, i: Integer;
begin
  for d := 0 to High(ADepths) do
  begin
    ALines.Add(Format('G0X%.4fY%.4f', [APoints[0].X, APoints[0].Y], GInvFS));
    ALines.Add(Format('G1Z%.4fF%g', [ADepths[d], ACfg.PlungeRate], GInvFS));
    for i := 1 to High(APoints) do
      ALines.Add(Format('G1X%.4fY%.4fF%g', [APoints[i].X, APoints[i].Y, ACfg.FeedRate], GInvFS));
    if AClosed then
      ALines.Add(Format('G1X%.4fY%.4fF%g', [APoints[0].X, APoints[0].Y, ACfg.FeedRate], GInvFS));
    ALines.Add(Format('G0Z%.4f', [ACfg.SafeZ], GInvFS));
  end;
end;

procedure AppendIsolationGCode(const APasses: TIsoPassArray;
  const ACfg: TIsolationConfig; ALines: TStrings);
var
  depths: TIsoDoubleArray;
  p, l: Integer;
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
      // an offset ring is always closed
      EmitCNCPointSequence(loop, True, ACfg, depths, ALines);
    end;
  end;

  if ACfg.SpindleRPM > 0 then
    ALines.Add('M5');
  ALines.Add('M30');
end;

procedure AppendIsolationGCodeLaser(const APasses: TIsoPassArray;
  const ALaserCfg: TLaserConfig; ALines: TStrings);
var
  p, l, i: Integer;
  loop: TIsoLoop;
begin
  ALines.Add('(Isolation routing toolpath generated by GRBL-Controller-Sender - laser)');
  ALines.Add('G21');
  ALines.Add('G90');

  for p := 0 to High(APasses) do
  begin
    ALines.Add(Format('(--- Isolation pass %d/%d ---)', [p + 1, Length(APasses)]));
    for l := 0 to High(APasses[p]) do
    begin
      loop := APasses[p][l];
      if Length(loop) < 2 then Continue;
      ALines.Add(Format('G0X%.4fY%.4f', [loop[0].X, loop[0].Y], GInvFS));
      ALines.Add(Format('M3S%d', [ALaserCfg.Power], GInvFS));
      for i := 1 to High(loop) do
        ALines.Add(Format('G1X%.4fY%.4fF%g', [loop[i].X, loop[i].Y, ALaserCfg.FeedRate], GInvFS));
      // close the ring back to its own start point
      ALines.Add(Format('G1X%.4fY%.4fF%g', [loop[0].X, loop[0].Y, ALaserCfg.FeedRate], GInvFS));
      ALines.Add('M5');
    end;
  end;

  ALines.Add('M30');
end;

function GenerateDrawToolpaths(const AFeatures: TGerberFeatureArray): TIsoPathArray;
var
  n, i: Integer;
  ap: TGerberAperture;
  shape: TPathD;
begin
  SetLength(Result, 0);
  n := 0;
  for i := 0 to High(AFeatures) do
  begin
    case AFeatures[i].Kind of
      gfkStroke:
        begin
          if Length(AFeatures[i].Points) < 2 then Continue;
          SetLength(Result, n + 1);
          Result[n].Points := CopyGerberPath(AFeatures[i].Points);
          Result[n].Closed := False;
          Inc(n);
        end;
      gfkRegion:
        begin
          if Length(AFeatures[i].Points) < 3 then Continue;
          SetLength(Result, n + 1);
          Result[n].Points := CopyGerberPath(AFeatures[i].Points);
          Result[n].Closed := True;
          Inc(n);
        end;
      gfkFlash:
        begin
          if Length(AFeatures[i].Points) < 1 then Continue;
          ap := AFeatures[i].Aperture;
          if ap.Kind = gakMacro then Continue; // unsupported, same disclosed gap as everywhere else
          case ap.Kind of
            gakCircle: shape := CircleFlashPath(AFeatures[i].Points[0].X, AFeatures[i].Points[0].Y, ap.Size / 2);
            gakRect: shape := RectFlashPath(AFeatures[i].Points[0].X, AFeatures[i].Points[0].Y, ap.Width, ap.Height);
            gakObround: shape := ObroundFlashPath(AFeatures[i].Points[0].X, AFeatures[i].Points[0].Y, ap.Width, ap.Height);
            gakPolygon: shape := PolygonFlashPath(AFeatures[i].Points[0].X, AFeatures[i].Points[0].Y, ap.Diameter, ap.NVertices, ap.Rotation);
          else
            Continue;
          end;
          SetLength(Result, n + 1);
          Result[n].Points := FromPathD(shape);
          Result[n].Closed := True;
          Inc(n);
        end;
    end;
  end;
end;

procedure AppendDrawGCode(const APaths: TIsoPathArray;
  const ACfg: TIsolationConfig; ALines: TStrings);
var
  depths: TIsoDoubleArray;
  pth: Integer;
  path: TIsoPath;
begin
  ValidateIsolationConfig(ACfg);
  depths := BuildDepthList(ACfg.CutDepth, ACfg.DepthPerPass);

  ALines.Add('(Draw toolpath generated by GRBL-Controller-Sender)');
  ALines.Add('G21');
  ALines.Add('G90');
  ALines.Add(Format('G0Z%.4f', [ACfg.SafeZ], GInvFS));
  if ACfg.SpindleRPM > 0 then
    ALines.Add(Format('M3S%d', [ACfg.SpindleRPM], GInvFS));

  for pth := 0 to High(APaths) do
  begin
    path := APaths[pth];
    if Length(path.Points) < 2 then Continue;
    EmitCNCPointSequence(path.Points, path.Closed, ACfg, depths, ALines);
  end;

  if ACfg.SpindleRPM > 0 then
    ALines.Add('M5');
  ALines.Add('M30');
end;

function BuildClearRegion(const AFeatures: TGerberFeatureArray;
  const ACfg: TIsolationConfig): TPathsD;
var
  copper, expandedCopper, boardRect: TPathsD;
  bounds: TRectD;
  keepAway: Double;
begin
  Result := nil;
  copper := BuildCopperSolidPathsD(AFeatures);
  if Length(copper) = 0 then Exit;

  bounds := GetBounds(copper);
  InflateRect(bounds, ACfg.BoardMargin, ACfg.BoardMargin);
  SetLength(boardRect, 1);
  boardRect[0] := bounds.AsPath;

  keepAway := ACfg.ToolDiameter / 2 + ACfg.IsolationGap;
  expandedCopper := InflatePaths(copper, keepAway, jtRound, etPolygon, 2.0, ISO_PRECISION, 0.0);

  Result := Difference(boardRect, expandedCopper, frNonZero, ISO_PRECISION);
end;

function ComputeClearScanSegments(const AClearRegion: TPathsD;
  AToolDiameter, AStepoverPercent: Double): TClearRowArray;
var
  bounds: TRectD;
  stepover, minY, maxY, loX, hiX, y: Double;
  rowCount, i, j, k, bestIdx: Integer;
  rowLines: TPathsD;
  rowYs: TIsoDoubleArray;
  clipper: TClipperD;
  closedDummy, openSolutions: TPathsD;
  seg: TClearSegment;
  x1, x2, tmp, bestDist, dist: Double;
begin
  Result := nil;
  if Length(AClearRegion) = 0 then Exit;

  bounds := GetBounds(AClearRegion);
  loX := Min(bounds.Left, bounds.Right);
  hiX := Max(bounds.Left, bounds.Right);
  minY := Min(bounds.Top, bounds.Bottom);
  maxY := Max(bounds.Top, bounds.Bottom);

  stepover := AToolDiameter * (AStepoverPercent / 100);
  if stepover <= 0 then stepover := AToolDiameter;

  if (maxY - minY) <= stepover then
    rowCount := 1
  else
    rowCount := Ceil((maxY - minY) / stepover) + 1;
  if rowCount < 1 then rowCount := 1;

  SetLength(rowYs, rowCount);
  SetLength(rowLines, rowCount);
  for i := 0 to rowCount - 1 do
  begin
    if rowCount = 1 then
      y := (minY + maxY) / 2
    else
      y := minY + (maxY - minY) * i / (rowCount - 1);
    rowYs[i] := y;
    SetLength(rowLines[i], 2);
    // extend 1mm past the region's own bounds on each side - InflateRect/
    // GetBounds precision noise could otherwise leave the line's own
    // endpoint exactly AT the boundary, an edge case Clipper doesn'trk
    // need to be pushed into.
    rowLines[i][0] := PointD(loX - 1, y);
    rowLines[i][1] := PointD(hiX + 1, y);
  end;

  clipper := TClipperD.Create(ISO_PRECISION);
  try
    clipper.AddOpenSubject(rowLines);
    clipper.AddClip(AClearRegion);
    clipper.Execute(ctIntersection, frNonZero, closedDummy, openSolutions);
  finally
    clipper.Free;
  end;

  SetLength(Result, rowCount);
  for i := 0 to rowCount - 1 do
    SetLength(Result[i], 0);

  // Each open-path result is an exact straight sub-segment of its own
  // originating row line (Clipper only ever inserts points that lie ON
  // the original line when clipping a straight open path against a
  // closed polygon) - so every point in one result shares the same Y,
  // and matching it back to "which row" only needs the first point's Y.
  for i := 0 to High(openSolutions) do
  begin
    if Length(openSolutions[i]) < 2 then Continue;
    y := openSolutions[i][0].Y;

    bestIdx := -1;
    bestDist := MaxDouble;
    for j := 0 to rowCount - 1 do
    begin
      dist := Abs(rowYs[j] - y);
      if dist < bestDist then
      begin
        bestDist := dist;
        bestIdx := j;
      end;
    end;
    if bestIdx < 0 then Continue;

    x1 := openSolutions[i][0].X;
    x2 := openSolutions[i][High(openSolutions[i])].X;
    if x1 > x2 then
    begin
      tmp := x1; x1 := x2; x2 := tmp;
    end;

    seg.X1 := x1;
    seg.X2 := x2;
    seg.Y := rowYs[bestIdx];
    SetLength(Result[bestIdx], Length(Result[bestIdx]) + 1);
    Result[bestIdx][High(Result[bestIdx])] := seg;
  end;

  // Sort segments within each row by X1 ascending - a plain insertion
  // sort is fine, real PCBs produce at most a handful of gaps per row.
  for i := 0 to rowCount - 1 do
    for j := 1 to High(Result[i]) do
    begin
      seg := Result[i][j];
      k := j - 1;
      while (k >= 0) and (Result[i][k].X1 > seg.X1) do
      begin
        Result[i][k + 1] := Result[i][k];
        Dec(k);
      end;
      Result[i][k + 1] := seg;
    end;

  // Merge adjacent segments whose gap is a numerical sliver rather than a
  // real one - a real, observed artifact: a scan line passing extremely
  // close to a vertex of an offset-circle's round-join polygon approximation
  // (see BuildClearRegion) can produce a spurious near-zero-width "cut" at
  // that vertex, splitting what should be one continuous segment into two
  // with a ~0.001-0.01mm gap between them - real copper never produces a
  // gap that thin (way below any real machining tolerance), so treat
  // anything under MIN_GAP_MM as noise and merge across it.
  for i := 0 to rowCount - 1 do
  begin
    j := 0;
    while j < High(Result[i]) do
    begin
      if Result[i][j + 1].X1 - Result[i][j].X2 < MIN_GAP_MM then
      begin
        Result[i][j].X2 := Result[i][j + 1].X2;
        for k := j + 1 to High(Result[i]) - 1 do
          Result[i][k] := Result[i][k + 1];
        SetLength(Result[i], Length(Result[i]) - 1);
      end
      else
        Inc(j);
    end;
  end;
end;

function GenerateClearToolpaths(const AFeatures: TGerberFeatureArray;
  const ACfg: TIsolationConfig): TClearRowArray;
var
  region: TPathsD;
begin
  ValidateClearConfig(ACfg);
  region := BuildClearRegion(AFeatures, ACfg);
  Result := ComputeClearScanSegments(region, ACfg.ToolDiameter, ACfg.ClearStepoverPercent);
end;

procedure AppendClearGCode(const ARows: TClearRowArray;
  const ACfg: TIsolationConfig; ALines: TStrings);
var
  depths: TIsoDoubleArray;
  d, r, s, idx: Integer;
  row: TClearRow;
  leftToRight: Boolean;
  fromX, toX: Double;
begin
  ValidateClearConfig(ACfg);
  depths := BuildDepthList(ACfg.CutDepth, ACfg.DepthPerPass);

  ALines.Add('(Clear-copper toolpath generated by GRBL-Controller-Sender)');
  ALines.Add('G21');
  ALines.Add('G90');
  ALines.Add(Format('G0Z%.4f', [ACfg.SafeZ], GInvFS));
  if ACfg.SpindleRPM > 0 then
    ALines.Add(Format('M3S%d', [ACfg.SpindleRPM], GInvFS));

  for d := 0 to High(depths) do
  begin
    leftToRight := True;
    for r := 0 to High(ARows) do
    begin
      row := ARows[r];
      if Length(row) = 0 then
      begin
        leftToRight := not leftToRight;
        Continue; // whole row covered by copper/keepaway - nothing to cut
      end;
      for s := 0 to High(row) do
      begin
        if leftToRight then idx := s else idx := High(row) - s;
        if leftToRight then
        begin
          fromX := row[idx].X1; toX := row[idx].X2;
        end
        else
        begin
          fromX := row[idx].X2; toX := row[idx].X1;
        end;
        // full retract/replunge per segment, not just per row - a gap
        // between segments on the same row is exactly where copper
        // survives, and the tool must never coast across it at depth.
        ALines.Add(Format('G0X%.4fY%.4f', [fromX, row[idx].Y], GInvFS));
        ALines.Add(Format('G1Z%.4fF%g', [depths[d], ACfg.PlungeRate], GInvFS));
        ALines.Add(Format('G1X%.4fY%.4fF%g', [toX, row[idx].Y, ACfg.FeedRate], GInvFS));
        ALines.Add(Format('G0Z%.4f', [ACfg.SafeZ], GInvFS));
      end;
      leftToRight := not leftToRight;
    end;
  end;

  if ACfg.SpindleRPM > 0 then
    ALines.Add('M5');
  ALines.Add('M30');
end;

procedure AppendClearGCodeLaser(const ARows: TClearRowArray;
  const ALaserCfg: TLaserConfig; ALines: TStrings);
var
  r, s, idx: Integer;
  row: TClearRow;
  leftToRight: Boolean;
  fromX, toX: Double;
begin
  ALines.Add('(Clear-copper toolpath generated by GRBL-Controller-Sender - laser)');
  ALines.Add('G21');
  ALines.Add('G90');

  leftToRight := True;
  for r := 0 to High(ARows) do
  begin
    row := ARows[r];
    if Length(row) = 0 then
    begin
      leftToRight := not leftToRight;
      Continue;
    end;
    for s := 0 to High(row) do
    begin
      if leftToRight then idx := s else idx := High(row) - s;
      if leftToRight then
      begin
        fromX := row[idx].X1; toX := row[idx].X2;
      end
      else
      begin
        fromX := row[idx].X2; toX := row[idx].X1;
      end;
      ALines.Add(Format('G0X%.4fY%.4f', [fromX, row[idx].Y], GInvFS));
      ALines.Add(Format('M3S%d', [ALaserCfg.Power], GInvFS));
      ALines.Add(Format('G1X%.4fY%.4fF%g', [toX, row[idx].Y, ALaserCfg.FeedRate], GInvFS));
      ALines.Add('M5');
    end;
    leftToRight := not leftToRight;
  end;

  ALines.Add('M30');
end;

initialization
  GInvFS := DefaultFormatSettings;
  GInvFS.DecimalSeparator := '.';

end.
