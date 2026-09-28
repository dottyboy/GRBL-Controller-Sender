unit uspoilboard;

{ uspoilboard: parametric G-code generator for a fresh (blank) spoilboard -
  surfacing/facing the whole area, drilling a rectangular grid of peg
  (bench-dog) holes, and cutting one or more T-track/T-rail channels.

  Coordinate convention (documented in every generated program's header
  comment too): X0 Y0 is the work area's bottom-left corner, Z0 is the
  spoilboard's top surface *before* facing. The caller is responsible for
  actually zeroing the machine there (jog + zero, or a touch probe) before
  running the generated program - this unit only ever emits G-code, it
  never talks to the controller.

  Deliberately GRBL-portable: no canned cycles (G81/G83/...) since vanilla
  GRBL doesn'trk implement them - every drill/peck cycle is explicit G0/G1
  moves, same approach as usender.pas's other generators (uprobe.pas). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, ui18n;

type
  TTrackOrientation = (toHorizontal, toVertical);
  // toHorizontal: track runs along X, Position/Width measured along Y.
  // toVertical:   track runs along Y, Position/Width measured along X.

  { TTTrackDef: one T-track/T-rail channel. Position is measured from the
    work area's bottom (toHorizontal) or left (toVertical) edge to the
    channel's *centerline*. StartMargin/EndMargin trim the channel's own
    length from the work area's full width/height (0/0 = full length). }
  TTTrackDef = record
    Orientation: TTrackOrientation;
    Position: Double;
    Width: Double;
    Depth: Double;
    StartMargin: Double;
    EndMargin: Double;
  end;

  TTTrackDefArray = array of TTTrackDef;
  TDoubleArray = array of Double;

  { TSpoilboardConfig: every field the UI exposes. All linear values in mm,
    feeds in mm/min. A section's Enabled=False means it is skipped entirely
    (and its other fields are irrelevant / not validated). }
  TSpoilboardConfig = record
    WorkWidthX: Double;   // full spoilboard blank size, X
    WorkHeightY: Double;  // full spoilboard blank size, Y
    SafeZ: Double;        // retract height above the (unfaced) surface

    FacingEnabled: Boolean;
    FacingToolDiameter: Double;
    FacingStepoverPercent: Double; // of tool diameter, e.g. 50
    FacingDepthPerPass: Double;
    FacingTotalDepth: Double;
    FacingFeedRate: Double;    // XY cutting feed
    FacingPlungeRate: Double;  // Z plunge feed
    FacingSpindleRPM: Integer; // 0 = don'trk emit S/M3 (assume already running)
    FacingRowsAlongX: Boolean; // True: sweep in X, step in Y; False: reverse

    HolesEnabled: Boolean;
    HoleDiameter: Double;      // informational + drives peg-hole spacing math only;
                               // straight-plunge mode assumes the bit diameter
                               // equals this (no spiral/helix boring - see README)
    HoleMarginX: Double;       // first/last hole's distance from the X edges
    HoleMarginY: Double;
    HoleSpacingX: Double;
    HoleSpacingY: Double;
    HoleStaggered: Boolean;    // odd rows offset by SpacingX/2
    HoleDrillDepth: Double;
    HolePeckDepth: Double;     // 0 or >= HoleDrillDepth = single plunge, no pecking
    HolePlungeRate: Double;

    TrackToolDiameter: Double;
    TrackStepoverPercent: Double;
    TrackFeedRate: Double;
    TrackPlungeRate: Double;
    Tracks: TTTrackDefArray;
  end;

  { EGenerateError: raised (as a caught exception surfaced to a friendly
    string, never a raw exception dialog) when the given parameters cannot
    physically produce valid G-code - e.g. a T-track narrower than its own
    cutting tool. }
  EGenerateError = class(Exception);

{ BuildSpoilboardProgram: the one entry point the UI needs. Appends a
  complete, ready-to-run program (facing, then T-tracks, then peg holes,
  in that fixed order - facing always first so the reference surface is
  fresh before anything else is cut into it) to ALines. Raises
  EGenerateError with a human-readable message if ACfg is not physically
  valid; ALines is left untouched in that case. }
procedure BuildSpoilboardProgram(const ACfg: TSpoilboardConfig; ALines: TStrings);

{ Exposed separately (not just via BuildSpoilboardProgram) so a standalone
  test can check each section's coordinates in isolation. }
procedure ValidateConfig(const ACfg: TSpoilboardConfig);
procedure AppendFacingGCode(const ACfg: TSpoilboardConfig; ALines: TStrings);
procedure AppendTrackGCode(const ACfg: TSpoilboardConfig; ALines: TStrings);
procedure AppendHolesGCode(const ACfg: TSpoilboardConfig; ALines: TStrings);

function DefaultSpoilboardConfig: TSpoilboardConfig;

implementation

var
  GInvFS: TFormatSettings; // '.' decimal separator, regardless of locale

function DefaultSpoilboardConfig: TSpoilboardConfig;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.WorkWidthX := 600;
  Result.WorkHeightY := 900;
  Result.SafeZ := 5;

  Result.FacingEnabled := True;
  Result.FacingToolDiameter := 12.7;
  Result.FacingStepoverPercent := 50;
  Result.FacingDepthPerPass := 0.5;
  Result.FacingTotalDepth := 0.5;
  Result.FacingFeedRate := 2000;
  Result.FacingPlungeRate := 300;
  Result.FacingSpindleRPM := 0;
  Result.FacingRowsAlongX := True;

  Result.HolesEnabled := True;
  Result.HoleDiameter := 20;
  Result.HoleMarginX := 48;
  Result.HoleMarginY := 48;
  Result.HoleSpacingX := 96;
  Result.HoleSpacingY := 96;
  Result.HoleStaggered := False;
  Result.HoleDrillDepth := 10;
  Result.HolePeckDepth := 5;
  Result.HolePlungeRate := 150;

  Result.TrackToolDiameter := 6;
  Result.TrackStepoverPercent := 50;
  Result.TrackFeedRate := 800;
  Result.TrackPlungeRate := 200;
  SetLength(Result.Tracks, 0);
end;

procedure ValidateConfig(const ACfg: TSpoilboardConfig);
var
  i: Integer;
  trk: TTTrackDef;
  usableLen: Double;
begin
  if (ACfg.WorkWidthX <= 0) or (ACfg.WorkHeightY <= 0) then
    raise EGenerateError.Create(T('Work area width/height must be positive.'));

  if ACfg.FacingEnabled then
  begin
    if ACfg.FacingToolDiameter <= 0 then
      raise EGenerateError.Create(T('Facing: tool diameter must be positive.'));
    if (ACfg.FacingStepoverPercent <= 0) or (ACfg.FacingStepoverPercent > 100) then
      raise EGenerateError.Create(T('Facing: stepover % must be between 0 and 100.'));
    if ACfg.FacingDepthPerPass <= 0 then
      raise EGenerateError.Create(T('Facing: depth per pass must be positive.'));
    if ACfg.FacingTotalDepth <= 0 then
      raise EGenerateError.Create(T('Facing: total depth must be positive.'));
  end;

  if ACfg.HolesEnabled then
  begin
    if ACfg.HoleDiameter <= 0 then
      raise EGenerateError.Create(T('Peg holes: hole diameter must be positive.'));
    if (ACfg.HoleSpacingX <= 0) or (ACfg.HoleSpacingY <= 0) then
      raise EGenerateError.Create(T('Peg holes: grid spacing must be positive.'));
    if ACfg.HoleDrillDepth <= 0 then
      raise EGenerateError.Create(T('Peg holes: drill depth must be positive.'));
    if (ACfg.HoleMarginX * 2 > ACfg.WorkWidthX) or (ACfg.HoleMarginY * 2 > ACfg.WorkHeightY) then
      raise EGenerateError.Create(T('Peg holes: margins leave no room for any hole.'));
  end;

  if Length(ACfg.Tracks) > 0 then
  begin
    if ACfg.TrackToolDiameter <= 0 then
      raise EGenerateError.Create(T('T-tracks: tool diameter must be positive.'));
    for i := 0 to High(ACfg.Tracks) do
    begin
      trk := ACfg.Tracks[i];
      if trk.Width < ACfg.TrackToolDiameter then
        raise EGenerateError.Create(Format(T(
          'T-track #%d: width %.2f mm is smaller than the tool diameter %.2f mm.'),
          [i + 1, trk.Width, ACfg.TrackToolDiameter]));
      if trk.Depth <= 0 then
        raise EGenerateError.Create(Format(T('T-track #%d: depth must be positive.'), [i + 1]));
      if trk.Orientation = toHorizontal then
        usableLen := ACfg.WorkWidthX - trk.StartMargin - trk.EndMargin
      else
        usableLen := ACfg.WorkHeightY - trk.StartMargin - trk.EndMargin;
      if usableLen <= 0 then
        raise EGenerateError.Create(Format(T(
          'T-track #%d: start/end margins leave no length to cut.'), [i + 1]));
      if trk.Orientation = toHorizontal then
      begin
        if (trk.Position - trk.Width / 2 < 0) or (trk.Position + trk.Width / 2 > ACfg.WorkHeightY) then
          raise EGenerateError.Create(Format(T(
            'T-track #%d: channel falls outside the work area (check Position/Width vs Height).'), [i + 1]));
      end
      else
      begin
        if (trk.Position - trk.Width / 2 < 0) or (trk.Position + trk.Width / 2 > ACfg.WorkWidthX) then
          raise EGenerateError.Create(Format(T(
            'T-track #%d: channel falls outside the work area (check Position/Width vs Width).'), [i + 1]));
      end;
    end;
  end;
end;

{ GenerateRasterRows: shared raster-pocket coordinate generator, used by
  both facing (ExpandOutward=True: the tool is allowed - in fact required -
  to travel D/2 beyond the physical [AMinU,AMaxU]x[AMinV,AMaxV] rectangle
  so its cutting edge, not its center, reaches every true boundary) and
  T-track pocketing (ExpandOutward=False: the tool CENTER must stay inside
  the pocket by D/2 so the cutter's edge never crosses the pocket wall).

  U is the sweep axis (the long, fast-feed direction), V is the step axis
  (the direction stepped over between rows) - purely a naming/generality
  device, the caller maps U/V to X/Y however it needs (see AppendFacingGCode
  swapping them for FacingRowsAlongX). Returns one flat array of V row
  centerlines and the [uStart,uEnd] sweep range; the caller alternates
  sweep direction per row itself (boustrophedon) since that's shared with
  how the moves actually get emitted. }
procedure ComputeRasterRows(AMinU, AMaxU, AMinV, AMaxV, AToolDiameter,
  AStepoverPercent, AUInset, AVInset: Double;
  out AUStart, AUEnd: Double; out ARowsV: array of Double; out ARowCount: Integer);
var
  uLo, uHi, vLo, vHi: Double;
  stepover: Double;
  span: Double;
  n, i: Integer;
begin
  stepover := AToolDiameter * (AStepoverPercent / 100);
  uLo := AMinU + AUInset;
  uHi := AMaxU - AUInset;
  vLo := AMinV + AVInset;
  vHi := AMaxV - AVInset;
  AUStart := uLo;
  AUEnd := uHi;

  span := vHi - vLo;
  if span <= 0 then
  begin
    // pocket exactly tool-width (or the outward-expanded facing strip is
    // degenerate, which shouldn'trk happen given ValidateConfig): one
    // centered row.
    ARowCount := 1;
    if Length(ARowsV) > 0 then ARowsV[0] := (AMinV + AMaxV) / 2;
    Exit;
  end;

  n := Ceil(span / stepover) + 1;
  if n < 2 then n := 2;
  ARowCount := n;
  if Length(ARowsV) >= n then
    for i := 0 to n - 1 do
      ARowsV[i] := vLo + (span * i / (n - 1));
end;

function RowsCountOnly(AMinU, AMaxU, AMinV, AMaxV, AToolDiameter,
  AStepoverPercent, AUInset, AVInset: Double): Integer;
var
  uS, uE: Double;
  dummy: array of Double;
begin
  SetLength(dummy, 0);
  ComputeRasterRows(AMinU, AMaxU, AMinV, AMaxV, AToolDiameter, AStepoverPercent,
    AUInset, AVInset, uS, uE, dummy, Result);
end;

{ EmitRasterPasses: walks AMinU..AMaxU / AMinV..AMaxV in a boustrophedon
  raster at each of the requested Z depths (one full sweep of the area per
  depth, shallowest first), writing G0/G1 moves for the U/V axes mapped to
  X/Y by the caller via AAxisU/AAxisV ('X' or 'Y'). ADepths must already be
  in cutting order (least negative first). }
procedure EmitRasterPasses(ALines: TStrings; AMinU, AMaxU, AMinV, AMaxV,
  AToolDiameter, AStepoverPercent, AUInset, AVInset: Double;
  const ADepths: array of Double; AFeedRate, APlungeRate, ASafeZ: Double;
  AAxisU, AAxisV: Char);
var
  rows: array of Double;
  rowCount, r, d: Integer;
  uStart, uEnd, uFrom, uTo, v: Double;
  first: Boolean;
begin
  rowCount := RowsCountOnly(AMinU, AMaxU, AMinV, AMaxV, AToolDiameter,
    AStepoverPercent, AUInset, AVInset);
  SetLength(rows, rowCount);
  ComputeRasterRows(AMinU, AMaxU, AMinV, AMaxV, AToolDiameter, AStepoverPercent,
    AUInset, AVInset, uStart, uEnd, rows, rowCount);

  first := True;
  for d := 0 to High(ADepths) do
  begin
    ALines.Add(Format('G0Z%.4f', [ASafeZ], GInvFS));
    for r := 0 to rowCount - 1 do
    begin
      v := rows[r];
      if (r mod 2) = 0 then
      begin
        uFrom := uStart; uTo := uEnd;
      end
      else
      begin
        uFrom := uEnd; uTo := uStart;
      end;
      if first then
      begin
        // first move of the whole section: rapid to start XY at safe Z,
        // then plunge, so the very first cut is a controlled feed move.
        ALines.Add(Format('G0%s%.4f%s%.4f', [AAxisU, uFrom, AAxisV, v], GInvFS));
        ALines.Add(Format('G1Z%.4fF%g', [ADepths[d], APlungeRate], GInvFS));
        first := False;
      end
      else if r = 0 then
      begin
        // first row of a new (deeper) pass: already at a safe height from
        // the G0Z above, rapid across, then plunge.
        ALines.Add(Format('G0%s%.4f%s%.4f', [AAxisU, uFrom, AAxisV, v], GInvFS));
        ALines.Add(Format('G1Z%.4fF%g', [ADepths[d], APlungeRate], GInvFS));
      end
      else
      begin
        // step to the next row at depth: small feed move sideways, not a
        // rapid, so the tool never leaves the cut at full depth mid-pass.
        ALines.Add(Format('G1%s%.4fF%g', [AAxisV, v, AFeedRate], GInvFS));
      end;
      ALines.Add(Format('G1%s%.4fF%g', [AAxisU, uTo, AFeedRate], GInvFS));
    end;
  end;
  ALines.Add(Format('G0Z%.4f', [ASafeZ], GInvFS));
end;

function BuildDepthList(ATotalDepth, ADepthPerPass: Double): TDoubleArray;
var
  n, i: Integer;
begin
  n := Ceil(ATotalDepth / ADepthPerPass);
  if n < 1 then n := 1;
  SetLength(Result, n);
  for i := 0 to n - 1 do
  begin
    Result[i] := -Min(ADepthPerPass * (i + 1), ATotalDepth);
  end;
end;

procedure AppendFacingGCode(const ACfg: TSpoilboardConfig; ALines: TStrings);
var
  depths: TDoubleArray;
  axisU, axisV: Char;
  minU, maxU, minV, maxV: Double;
begin
  if not ACfg.FacingEnabled then Exit;
  ALines.Add('(--- Facing / surfacing ---)');
  if ACfg.FacingSpindleRPM > 0 then
    ALines.Add(Format('M3S%d', [ACfg.FacingSpindleRPM], GInvFS));

  depths := BuildDepthList(ACfg.FacingTotalDepth, ACfg.FacingDepthPerPass);
  if ACfg.FacingRowsAlongX then
  begin
    axisU := 'X'; axisV := 'Y';
    minU := 0; maxU := ACfg.WorkWidthX;
    minV := 0; maxV := ACfg.WorkHeightY;
  end
  else
  begin
    axisU := 'Y'; axisV := 'X';
    minU := 0; maxU := ACfg.WorkHeightY;
    minV := 0; maxV := ACfg.WorkWidthX;
  end;

  // both axes are real board edges here, so both get the outward D/2
  // expansion (negative inset) for full-edge coverage.
  EmitRasterPasses(ALines, minU, maxU, minV, maxV, ACfg.FacingToolDiameter,
    ACfg.FacingStepoverPercent, -ACfg.FacingToolDiameter / 2,
    -ACfg.FacingToolDiameter / 2, depths, ACfg.FacingFeedRate,
    ACfg.FacingPlungeRate, ACfg.SafeZ, axisU, axisV);
end;

procedure AppendTrackGCode(const ACfg: TSpoilboardConfig; ALines: TStrings);
var
  i: Integer;
  trk: TTTrackDef;
  depths: TDoubleArray;
  axisU, axisV: Char;
  minU, maxU, minV, maxV: Double;
begin
  if Length(ACfg.Tracks) = 0 then Exit;
  ALines.Add('(--- T-track / T-rail channels ---)');
  depths := BuildDepthList(1, 1); // placeholder, recomputed per track below (depth differs per track)

  for i := 0 to High(ACfg.Tracks) do
  begin
    trk := ACfg.Tracks[i];
    ALines.Add(Format('(T-track #%d)', [i + 1]));
    depths := BuildDepthList(trk.Depth, trk.Depth); // single full-depth pass per row; a track
                                                 // groove is usually shallow enough that
                                                 // multi-pass isn'trk needed, but if it ever
                                                 // is, raise TrackDepthPerPass to a field
                                                 // instead of hardcoding here.
    if trk.Orientation = toHorizontal then
    begin
      axisU := 'X'; axisV := 'Y';
      minU := trk.StartMargin; maxU := ACfg.WorkWidthX - trk.EndMargin;
      minV := trk.Position - trk.Width / 2; maxV := trk.Position + trk.Width / 2;
    end
    else
    begin
      axisU := 'Y'; axisV := 'X';
      minU := trk.StartMargin; maxU := ACfg.WorkHeightY - trk.EndMargin;
      minV := trk.Position - trk.Width / 2; maxV := trk.Position + trk.Width / 2;
    end;

    // U (the channel's length) has no real wall at its StartMargin/EndMargin
    // trim points - the tool center goes exactly there, no inset. V (the
    // channel's width) has real side walls, so it's inset inward by D/2 so
    // the cutter's edge - not its center - defines the wall.
    EmitRasterPasses(ALines, minU, maxU, minV, maxV, ACfg.TrackToolDiameter,
      ACfg.TrackStepoverPercent, 0, ACfg.TrackToolDiameter / 2, depths,
      ACfg.TrackFeedRate, ACfg.TrackPlungeRate, ACfg.SafeZ, axisU, axisV);
  end;
end;

procedure AppendHolesGCode(const ACfg: TSpoilboardConfig; ALines: TStrings);
var
  nx, ny, ix, iy: Integer;
  x, y, xOff: Double;
  peckDepth: Double;
  currentDepth: Double;
  rowLeftToRight: Boolean;
begin
  if not ACfg.HolesEnabled then Exit;
  ALines.Add('(--- Peg holes grid ---)');
  ALines.Add(Format('(hole diameter %.2f mm - use a bit of this diameter, straight plunge, no boring)',
    [ACfg.HoleDiameter], GInvFS));

  nx := Floor((ACfg.WorkWidthX - 2 * ACfg.HoleMarginX) / ACfg.HoleSpacingX) + 1;
  ny := Floor((ACfg.WorkHeightY - 2 * ACfg.HoleMarginY) / ACfg.HoleSpacingY) + 1;

  peckDepth := ACfg.HolePeckDepth;
  if (peckDepth <= 0) or (peckDepth >= ACfg.HoleDrillDepth) then
    peckDepth := ACfg.HoleDrillDepth;

  ALines.Add(Format('G0Z%.4f', [ACfg.SafeZ], GInvFS));
  rowLeftToRight := True;
  for iy := 0 to ny - 1 do
  begin
    y := ACfg.HoleMarginY + iy * ACfg.HoleSpacingY;
    xOff := 0;
    if ACfg.HoleStaggered and Odd(iy) then
      xOff := ACfg.HoleSpacingX / 2;
    for ix := 0 to nx - 1 do
    begin
      if rowLeftToRight then
        x := ACfg.HoleMarginX + xOff + ix * ACfg.HoleSpacingX
      else
        x := ACfg.HoleMarginX + xOff + (nx - 1 - ix) * ACfg.HoleSpacingX;
      if ACfg.HoleStaggered and (x > ACfg.WorkWidthX - ACfg.HoleMarginX + 0.001) then
        Continue; // staggered offset pushed this one past the margin - skip it
      ALines.Add(Format('G0X%.4fY%.4f', [x, y], GInvFS));
      currentDepth := 0;
      while currentDepth < ACfg.HoleDrillDepth - 1e-6 do
      begin
        currentDepth := Min(currentDepth + peckDepth, ACfg.HoleDrillDepth);
        ALines.Add(Format('G1Z%.4fF%g', [-currentDepth, ACfg.HolePlungeRate], GInvFS));
        if currentDepth < ACfg.HoleDrillDepth - 1e-6 then
          ALines.Add(Format('G0Z%.4f', [ACfg.SafeZ], GInvFS)); // peck: full retract for chip clearance
      end;
      ALines.Add(Format('G0Z%.4f', [ACfg.SafeZ], GInvFS));
    end;
    rowLeftToRight := not rowLeftToRight;
  end;
end;

procedure BuildSpoilboardProgram(const ACfg: TSpoilboardConfig; ALines: TStrings);
begin
  ValidateConfig(ACfg);
  ALines.Add('(Spoilboard program generated by GRBL-Controller-Sender)');
  ALines.Add(Format('(work area %.1f x %.1f mm, X0Y0 = bottom-left corner, Z0 = surface before facing)',
    [ACfg.WorkWidthX, ACfg.WorkHeightY], GInvFS));
  ALines.Add('G21'); // mm
  ALines.Add('G90'); // absolute
  ALines.Add(Format('G0Z%.4f', [ACfg.SafeZ], GInvFS));

  AppendFacingGCode(ACfg, ALines);
  AppendTrackGCode(ACfg, ALines);
  AppendHolesGCode(ACfg, ALines);

  if ACfg.FacingEnabled and (ACfg.FacingSpindleRPM > 0) then
    ALines.Add('M5');
  ALines.Add('M30');
end;

initialization
  GInvFS := DefaultFormatSettings;
  GInvFS.DecimalSeparator := '.';

end.
