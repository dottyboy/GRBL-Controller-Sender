unit ugerberimport;

{ ugerberimport: RS-274X Gerber parser (plan Phase 33), pure/LCL-free -
  turns a Gerber file's lines into a flat list of geometric features
  (stroked paths, flashed apertures, filled regions) in millimeters,
  tagged with polarity. Deliberately does NOT do any polygon union/offset
  math itself - that is uisolationrouting.pas's job (via the real Clipper2
  library already bundled with CodeTyphon, pl_Image32), keeping this unit
  free of that dependency and independently standalone-testable.

  Ported (Python to Pascal reimplementation, not copied - same discipline
  as every other reference-source phase in this plan) from FlatCAM's
  real, MIT-licensed `camlib.py` `Gerber.parse_lines()` state machine
  (read directly from the local references/FlatCAM-master.zip before
  writing anything): same per-line statement grammar (%FS/%MO/%ADD/%AM/
  %LP/G01/G02/G03/G36/G37/G74/G75/D-codes), same arc-expansion math
  (`arc()`), same aperture shapes (C/R/O/P), same D02/D03/region/polarity
  finalization points.

  One generic token scanner (ScanCoordLine) replaces camlib.py's six
  separate per-command regexes (lin_re/circ_re/tool_re/opcode_re/
  interp_re/quad_re) - a single "letter + signed digits" pass covers the
  same grammar those regexes each hand-carve a piece of. Assumes one
  Gerber statement per physical line, the same assumption camlib.py's
  own parser makes - true of every real generator checked for this
  phase, including KiCad's own Gerber plotter (Phase 32).

  Real, disclosed scope reduction (same honesty this project applies to
  every other reference port): Aperture Macros (%AM...%, a small
  embedded shape-description language) are recognized and skipped, not
  interpreted - a flash using a macro aperture is dropped with a warning
  rather than crashing. Gerber's most common real-world apertures
  (circle/rect/obround/regular-polygon, plus filled regions for pours)
  are what actually matters for isolation-routing a simple board; full
  macro-aperture support is a separate, larger undertaking - Visolate's
  own project page discloses skipping something analogous too (there:
  polygon regions; here: macros). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math;

type
  TGerberStringArray = array of string;

  TGerberPoint = record
    X, Y: Double; // millimeters, always - inch-unit files are normalized
                  // to mm once parsing completes.
  end;
  TGerberPointArray = array of TGerberPoint;

  TGerberApertureKind = (gakCircle, gakRect, gakObround, gakPolygon, gakMacro);

  TGerberAperture = record
    Kind: TGerberApertureKind;
    Size: Double;      // circle: diameter. rect/obround: diagonal hack
                        // (sqrt(w^2+h^2)) used only as a STROKE width
                        // fallback - the same "# Hack" camlib.py's own
                        // aperture_parse() comment admits to.
    Width, Height: Double;  // rect/obround
    Diameter: Double;       // regular polygon circumscribed diameter
    NVertices: Integer;     // regular polygon
    Rotation: Double;       // regular polygon, degrees
  end;

  TGerberFeatureKind = (gfkStroke, gfkFlash, gfkRegion);

  TGerberFeature = record
    Kind: TGerberFeatureKind;
    Points: TGerberPointArray; // gfkStroke: the centerline path (>=2 pts).
                                // gfkFlash: exactly one point (the flash
                                //   location).
                                // gfkRegion: the closed outline.
    Aperture: TGerberAperture;  // gfkStroke: gives the stroke width.
                                 // gfkFlash: gives the flashed shape.
                                 // gfkRegion: unused.
    Dark: Boolean; // True = add (normal "dark" polarity), False = subtract
                    // (%LPC "clear" polarity - e.g. a pad cut from a pour).
  end;
  TGerberFeatureArray = array of TGerberFeature;

  TGerberUnits = (guInch, guMM);

{ ParseGerberLines: the one entry point. ALines is the raw file content,
  one Gerber statement per physical line. Returns False only on a
  structurally unrecoverable error (caught internally, never raises);
  AWarnings collects non-fatal issues (unknown statements, macro-aperture
  flashes skipped, missing aperture, etc.) the caller can surface to the
  user without aborting the import. }
function ParseGerberLines(const ALines: TGerberStringArray;
  out AFeatures: TGerberFeatureArray; out AUnits: TGerberUnits;
  out AWarnings: TGerberStringArray): Boolean;

function ParseGerberNumber(const AStrNumber: string; AFracDigits: Integer): Double;
function GerberStrToFloat(const AStr: string): Double;

{ MirrorFeaturesX: plan Phase 40 - reflects every already-parsed feature's
  own points around the vertical line X = AAxisX (X' := 2*AAxisX - X, Y
  unchanged), for generating a second PCB side's toolpath so it lands
  correctly once the board is physically flipped around dowel pins at
  that same X. A gakPolygon aperture's own Rotation is negated too - a
  reflection reverses a rotation's sense, so a regular-polygon pad
  mirrors exactly rather than only approximately. Any resulting winding-
  order flip on closed regions needs no handling here: Isolate mode's
  own NormalizeWindingForOffset already tolerates arbitrary input
  winding, and Draw mode never depends on winding at all. }
function MirrorFeaturesX(const AFeatures: TGerberFeatureArray; AAxisX: Double): TGerberFeatureArray;

implementation

const
  MM_PER_INCH = 25.4;
  DEFAULT_STEPS_PER_CIRCLE = 40;

var
  GGerberFS: TFormatSettings; // '.' decimal separator regardless of locale

function GerberStrToFloat(const AStr: string): Double;
begin
  Result := StrToFloatDef(Trim(AStr), 0, GGerberFS);
end;

function ParseGerberNumber(const AStrNumber: string; AFracDigits: Integer): Double;
var
  n: Int64;
begin
  if AStrNumber = '' then Exit(0);
  n := StrToInt64Def(AStrNumber, 0);
  Result := n * Power(10, -AFracDigits);
end;

{ ---- Small growable helpers (kept simple/explicit rather than pulling
  in FPC's generic container units, matching this project's general
  low-ceremony style for core units) ---- }

type
  TWarnings = record
    Items: TGerberStringArray;
  end;

procedure AddWarning(var AList: TWarnings; const AMsg: string);
begin
  SetLength(AList.Items, Length(AList.Items) + 1);
  AList.Items[High(AList.Items)] := AMsg;
end;

type
  TFeatures = record
    Items: TGerberFeatureArray;
  end;

procedure AddFeature(var AList: TFeatures; const AFeature: TGerberFeature);
begin
  SetLength(AList.Items, Length(AList.Items) + 1);
  AList.Items[High(AList.Items)] := AFeature;
end;

type
  TApertureEntry = record
    Id: Integer;
    Aperture: TGerberAperture;
    Valid: Boolean;
  end;
  TApertureTable = record
    Items: array of TApertureEntry;
  end;

function FindApertureIdx(const ATable: TApertureTable; AId: Integer): Integer;
var
  i: Integer;
begin
  for i := 0 to High(ATable.Items) do
    if ATable.Items[i].Id = AId then Exit(i);
  Result := -1;
end;

procedure SetAperture(var ATable: TApertureTable; AId: Integer; const AAp: TGerberAperture);
var
  idx: Integer;
begin
  idx := FindApertureIdx(ATable, AId);
  if idx < 0 then
  begin
    SetLength(ATable.Items, Length(ATable.Items) + 1);
    idx := High(ATable.Items);
    ATable.Items[idx].Id := AId;
  end;
  ATable.Items[idx].Aperture := AAp;
  ATable.Items[idx].Valid := True;
end;

{ ---- Point-array helpers ---- }

procedure AppendPoint(var APath: TGerberPointArray; AX, AY: Double);
begin
  SetLength(APath, Length(APath) + 1);
  APath[High(APath)].X := AX;
  APath[High(APath)].Y := AY;
end;

function CopyPath(const APath: TGerberPointArray): TGerberPointArray;
var
  i: Integer;
begin
  SetLength(Result, Length(APath));
  for i := 0 to High(APath) do
    Result[i] := APath[i];
end;

procedure AppendArc(var APath: TGerberPointArray; const AArc: TGerberPointArray);
var
  i: Integer;
begin
  for i := 0 to High(AArc) do
    AppendPoint(APath, AArc[i].X, AArc[i].Y);
end;

{ ---- Arc expansion, ported from camlib.py's arc()/arc_angle() ---- }

function GerberArc(ACenterX, ACenterY, ARadius, AStart, AStop: Double;
  AClockwise: Boolean; AStepsPerCircle: Integer): TGerberPointArray;
var
  stop_: Double;
  angle, deltaAngle, sign_: Double;
  steps, i: Integer;
  theta: Double;
begin
  stop_ := AStop;
  sign_ := 1.0;
  if AClockwise then
  begin
    if stop_ >= AStart then stop_ := stop_ - 2 * Pi;
    sign_ := -1.0;
  end
  else
  begin
    if stop_ <= AStart then stop_ := stop_ + 2 * Pi;
  end;

  angle := Abs(stop_ - AStart);
  steps := Max(Ceil(angle / (2 * Pi) * AStepsPerCircle), 2);
  deltaAngle := sign_ * angle / steps;

  SetLength(Result, steps + 1);
  for i := 0 to steps do
  begin
    theta := AStart + deltaAngle * i;
    Result[i].X := ACenterX + ARadius * Cos(theta);
    Result[i].Y := ACenterY + ARadius * Sin(theta);
  end;
end;

function ArcSweepAngle(AStart, AStop: Double; AClockwise: Boolean): Double;
var
  stop_: Double;
begin
  stop_ := AStop;
  if AClockwise then
  begin
    if stop_ >= AStart then stop_ := stop_ - 2 * Pi;
  end
  else
  begin
    if stop_ <= AStart then stop_ := stop_ + 2 * Pi;
  end;
  Result := Abs(stop_ - AStart);
end;

{ ---- Generic coordinate-line token scanner ---- }

type
  TGerberLineInfo = record
    HasG: Boolean; GCode: Integer;
    HasX: Boolean; X: Double;
    HasY: Boolean; Y: Double;
    HasI: Boolean; I: Double;
    HasJ: Boolean; J: Double;
    HasD: Boolean; DCode: Integer;
  end;

function ScanCoordLine(const ABody: string; AFracDigits: Integer): TGerberLineInfo;
var
  i, len: Integer;
  ch: Char;
  numStart: Integer;
  numStr: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  len := Length(ABody);
  i := 1;
  while i <= len do
  begin
    ch := ABody[i];
    if ch in ['G', 'X', 'Y', 'I', 'J', 'D'] then
    begin
      numStart := i + 1;
      i := numStart;
      if (i <= len) and (ABody[i] in ['+', '-']) then Inc(i);
      while (i <= len) and (ABody[i] in ['0'..'9']) do Inc(i);
      numStr := Copy(ABody, numStart, i - numStart);
      case ch of
        'G': begin Result.HasG := True; Result.GCode := StrToIntDef(numStr, 0); end;
        'X': begin Result.HasX := True; Result.X := ParseGerberNumber(numStr, AFracDigits); end;
        'Y': begin Result.HasY := True; Result.Y := ParseGerberNumber(numStr, AFracDigits); end;
        'I': begin Result.HasI := True; Result.I := ParseGerberNumber(numStr, AFracDigits); end;
        'J': begin Result.HasJ := True; Result.J := ParseGerberNumber(numStr, AFracDigits); end;
        'D': begin Result.HasD := True; Result.DCode := StrToIntDef(numStr, 0); end;
      end;
    end
    else
      Inc(i);
  end;
end;

{ Splits an aperture parameter list on 'X' (Gerber's own separator, e.g.
  "0.05X0.12" for a rectangle's width/height), ported from
  aperture_parse()'s `apParameters.split('X')`. }
function SplitApertureParams(const AParams: string): TGerberStringArray;
var
  s: string;
  p: Integer;
  n: Integer;
begin
  SetLength(Result, 0);
  s := AParams;
  if s = '' then Exit;
  n := 0;
  while True do
  begin
    Inc(n);
    SetLength(Result, n);
    p := Pos('X', s);
    if p > 0 then
    begin
      Result[n - 1] := Copy(s, 1, p - 1);
      s := Copy(s, p + 1, MaxInt);
    end
    else
    begin
      Result[n - 1] := s;
      Break;
    end;
  end;
end;

function ParseApertureDef(const AApId, AApType, AApParams: string;
  var AWarnings: TWarnings): TGerberAperture;
var
  parts: TGerberStringArray;
begin
  FillChar(Result, SizeOf(Result), 0);
  parts := SplitApertureParams(AApParams);

  if AApType = 'C' then
  begin
    Result.Kind := gakCircle;
    if Length(parts) >= 1 then Result.Size := GerberStrToFloat(parts[0]);
  end
  else if AApType = 'R' then
  begin
    Result.Kind := gakRect;
    if Length(parts) >= 2 then
    begin
      Result.Width := GerberStrToFloat(parts[0]);
      Result.Height := GerberStrToFloat(parts[1]);
      Result.Size := Sqrt(Sqr(Result.Width) + Sqr(Result.Height));
    end;
  end
  else if AApType = 'O' then
  begin
    Result.Kind := gakObround;
    if Length(parts) >= 2 then
    begin
      Result.Width := GerberStrToFloat(parts[0]);
      Result.Height := GerberStrToFloat(parts[1]);
      Result.Size := Sqrt(Sqr(Result.Width) + Sqr(Result.Height));
    end;
  end
  else if AApType = 'P' then
  begin
    Result.Kind := gakPolygon;
    if Length(parts) >= 2 then
    begin
      Result.Diameter := GerberStrToFloat(parts[0]);
      Result.NVertices := Round(GerberStrToFloat(parts[1]));
      Result.Size := Result.Diameter;
      if Length(parts) >= 3 then
        Result.Rotation := GerberStrToFloat(parts[2]);
    end;
  end
  else
  begin
    Result.Kind := gakMacro;
    AddWarning(AWarnings, Format(
      'Aperture D%s uses macro/unsupported type "%s" - flashes with it will be skipped.',
      [AApId, AApType]));
  end;
end;

{ ================= Main parser ================= }

function ParseGerberLines(const ALines: TGerberStringArray;
  out AFeatures: TGerberFeatureArray; out AUnits: TGerberUnits;
  out AWarnings: TGerberStringArray): Boolean;
var
  warnings: TWarnings;
  features: TFeatures;
  apertures: TApertureTable;

  fracDigits: Integer;
  currentApId: Integer;
  lastPathApId: Integer;
  currentInterpMode: Integer; // 1, 2 or 3 (G01/G02/G03), 0 = none yet
  currentOpCode: Integer;     // 1, 2 or 3 (D01/D02/D03), 0 = none yet
  currentX, currentY: Double;
  quadrantMulti: Boolean;     // True = MULTI (G75), False = SINGLE (G74)
  quadrantSet: Boolean;
  polarityDark: Boolean;
  parsingMacro: Boolean;
  path: TGerberPointArray;
  units: TGerberUnits;
  sawMO: Boolean;

  function ApertureByIdOrDefault(AId: Integer; out AAp: TGerberAperture): Boolean;
  var
    idx: Integer;
  begin
    idx := FindApertureIdx(apertures, AId);
    if idx < 0 then
    begin
      FillChar(AAp, SizeOf(AAp), 0);
      AAp.Kind := gakCircle;
      AAp.Size := 0.1; // small but non-zero, mirrors camlib.py's own
                        // "aperture value is zero -> something quite
                        // small" fallback for a missing/degenerate aperture
      Exit(False);
    end;
    AAp := apertures.Items[idx].Aperture;
    Result := True;
  end;

  // Finish whatever is in `path` as a stroked feature, using the
  // aperture that was active when the path was DRAWN (lastPathApId) -
  // exactly camlib.py's own `last_path_aperture` distinction (the
  // aperture may have changed since, e.g. a tool-change line).
  procedure FinishStrokeIfAny;
  var
    ap: TGerberAperture;
    feat: TGerberFeature;
  begin
    if Length(path) <= 1 then Exit;
    if lastPathApId < 0 then
      AddWarning(warnings, 'Stroke with no aperture selected - using a default hairline width.');
    ApertureByIdOrDefault(lastPathApId, ap);
    feat.Kind := gfkStroke;
    feat.Points := CopyPath(path);
    feat.Aperture := ap;
    feat.Dark := polarityDark;
    AddFeature(features, feat);
  end;

  // After finishing a stroke (or when there was none pending), restart
  // `path` with a single point: the path's own last point if it had one,
  // else the current pen position. Mirrors camlib.py's own
  // `path = [path[-1]]` (region-start/tool-change/polarity-change) resets
  // - getting this wrong (e.g. keeping path[0] instead of the LAST point)
  // would silently start the next segment from the wrong place.
  procedure KeepLastPathPoint;
  begin
    if Length(path) > 0 then
    begin
      path[0] := path[High(path)];
      SetLength(path, 1);
    end
    else
    begin
      SetLength(path, 1);
      path[0].X := currentX; path[0].Y := currentY;
    end;
  end;

  procedure DoFlash;
  var
    ap: TGerberAperture;
    feat: TGerberFeature;
  begin
    if not ApertureByIdOrDefault(currentApId, ap) then
      AddWarning(warnings, Format('Flash with unknown aperture D%d - using a default.', [currentApId]));
    if ap.Kind = gakMacro then
    begin
      AddWarning(warnings, 'Flash skipped (macro aperture not supported).');
      Exit;
    end;
    feat.Kind := gfkFlash;
    SetLength(feat.Points, 1);
    feat.Points[0].X := currentX;
    feat.Points[0].Y := currentY;
    feat.Aperture := ap;
    feat.Dark := polarityDark;
    AddFeature(features, feat);
  end;

var
  rawLine, gline: string;
  lineNum: Integer;
  info: TGerberLineInfo;
  body: string;
  p: Integer;
  adId, adType, adParams: string;
  amName: string;
  center: TGerberPoint;
  radius, startAngle, stopAngle: Double;
  candCenters: array[0..3] of TGerberPoint;
  ci: Integer;
  validArc: Boolean;
  arcPts: TGerberPointArray;
  region: TGerberFeature;
  scaleToMM: Double;
  i, j: Integer;
begin
  Result := True;
  SetLength(warnings.Items, 0);
  SetLength(features.Items, 0);
  SetLength(apertures.Items, 0);

  fracDigits := 4;
  currentApId := -1;
  lastPathApId := -1;
  currentInterpMode := 0;
  currentOpCode := 0;
  currentX := 0; currentY := 0;
  quadrantMulti := True;
  quadrantSet := False;
  polarityDark := True;
  parsingMacro := False;
  SetLength(path, 0);
  units := guMM;
  sawMO := False;

  try
    for lineNum := 0 to High(ALines) do
    begin
      rawLine := ALines[lineNum];
      gline := Trim(rawLine);
      if gline = '' then Continue;

      // ---- Aperture macro body: fully skipped, disclosed limitation ----
      if parsingMacro then
      begin
        if (Length(gline) > 0) and (gline[Length(gline)] = '%') then
          parsingMacro := False;
        Continue;
      end;
      if (Length(gline) >= 3) and (Copy(gline, 1, 3) = '%AM') then
      begin
        amName := Copy(gline, 4, MaxInt);
        p := Pos('*', amName);
        if p > 0 then amName := Copy(amName, 1, p - 1);
        AddWarning(warnings, Format('Aperture macro "%s" definition skipped (not supported) - any flash using it will be dropped.', [amName]));
        if not ((Length(gline) > 0) and (gline[Length(gline)] = '%')) then
          parsingMacro := True;
        Continue;
      end;

      // ---- Gerber X2 file/aperture/object attributes (%TF/%TA/%TO/%TD/
      //      %TM/%TR...*%) - metadata only, no geometric effect. Real,
      //      disclosed gap found via testing against an actual KiCad-
      //      plotted Gerber (Phase 32's own board): these did not exist
      //      when camlib.py's own parser (this unit's reference) was
      //      written, and without this explicit skip a line like
      //      "%TD*%" would otherwise fall through to the generic
      //      coordinate scanner, which sees its stray capital "D" and
      //      misreads it as a bare D0-operation-code statement,
      //      corrupting the real draw/move/flash state machine mid-file. }
      if (Length(gline) >= 2) and (gline[1] = '%') and (gline[2] = 'T') then Continue;

      // ---- %FS format spec ----
      if (Length(gline) >= 3) and (Copy(gline, 1, 3) = '%FS') then
      begin
        // %FSLAX34Y34*% (or T/I variants) - only X's int/frac digit
        // counts are used (X and Y must match per spec).
        p := Pos('X', gline);
        if (p > 0) and (p + 2 <= Length(gline)) then
        begin
          fracDigits := StrToIntDef(Copy(gline, p + 2, 1), fracDigits);
        end;
        Continue;
      end;

      // ---- %MO units ----
      if (Length(gline) >= 3) and (Copy(gline, 1, 3) = '%MO') then
      begin
        if Pos('MM', gline) > 0 then units := guMM
        else if Pos('IN', gline) > 0 then units := guInch;
        sawMO := True;
        Continue;
      end;

      // ---- %ADD aperture definition ----
      if (Length(gline) >= 4) and (Copy(gline, 1, 4) = '%ADD') then
      begin
        body := Copy(gline, 5, MaxInt);
        p := Pos('*', body);
        if p > 0 then body := Copy(body, 1, p - 1);
        if (Length(body) > 0) and (body[Length(body)] = '%') then
          Delete(body, Length(body), 1);
        // body now e.g. "10C,0.254" or "11R,0.05X0.12"
        p := 1;
        while (p <= Length(body)) and (body[p] in ['0'..'9']) do Inc(p);
        adId := Copy(body, 1, p - 1);
        body := Copy(body, p, MaxInt);
        p := Pos(',', body);
        if p > 0 then
        begin
          adType := Copy(body, 1, p - 1);
          adParams := Copy(body, p + 1, MaxInt);
        end
        else
        begin
          adType := body;
          adParams := '';
        end;
        SetAperture(apertures, StrToIntDef(adId, -1),
          ParseApertureDef(adId, adType, adParams, warnings));
        Continue;
      end;

      // ---- %LP polarity ----
      if (Length(gline) >= 3) and (Copy(gline, 1, 3) = '%LP') then
      begin
        FinishStrokeIfAny;
        KeepLastPathPoint;
        if (Length(gline) >= 4) and (gline[4] = 'C') then
          polarityDark := False
        else
          polarityDark := True;
        Continue;
      end;

      // ---- %IP image polarity - consumed, not acted on (disclosed) ----
      if (Length(gline) >= 3) and (Copy(gline, 1, 3) = '%IP') then Continue;

      // ---- Comments (G04/G4) ----
      if (Length(gline) >= 3) and (Copy(gline, 1, 3) = 'G04') then Continue;
      if (Length(gline) >= 2) and (Copy(gline, 1, 2) = 'G4') and
         ((Length(gline) = 2) or not (gline[3] in ['0'..'9'])) then Continue;

      // ---- End of file ----
      if (gline = 'M02*') or (gline = 'M00*') or (gline = 'M01*') then Continue;

      // ---- G74/G75 quadrant mode ----
      if gline = 'G74*' then begin quadrantMulti := False; quadrantSet := True; Continue; end;
      if gline = 'G75*' then begin quadrantMulti := True; quadrantSet := True; Continue; end;

      // ---- G36 region on ----
      if gline = 'G36*' then
      begin
        FinishStrokeIfAny;
        KeepLastPathPoint;
        Continue;
      end;

      // ---- G37 region off ----
      if gline = 'G37*' then
      begin
        if Length(path) >= 3 then
        begin
          region.Kind := gfkRegion;
          region.Points := CopyPath(path);
          FillChar(region.Aperture, SizeOf(region.Aperture), 0);
          region.Dark := polarityDark;
          AddFeature(features, region);
        end;
        SetLength(path, 1);
        path[0].X := currentX; path[0].Y := currentY;
        Continue;
      end;

      // ---- D-code alone: aperture select (>=10, or not 1/2/3) vs bare
      //      operation code (D01/D02/D03, incl. one-digit D1/D2/D3) ----
      if (gline <> '') and (gline[1] = 'D') then
      begin
        info := ScanCoordLine(gline, fracDigits);
        if info.HasD and not info.HasX and not info.HasY and not info.HasI
           and not info.HasJ and not info.HasG then
        begin
          if info.DCode in [1, 2, 3] then
          begin
            currentOpCode := info.DCode;
            if currentOpCode = 3 then DoFlash;
          end
          else
          begin
            // Aperture (tool) change: finish whatever path was pending
            // under the OLD aperture first - otherwise a subsequent draw
            // continuing the same path array would get misattributed to
            // the NEW aperture's width when the stroke is eventually
            // finalized. Mirrors camlib.py's own tool-change handling.
            FinishStrokeIfAny;
            KeepLastPathPoint;
            currentApId := info.DCode;
          end;
          Continue;
        end;
      end;

      // ---- Everything else: a coordinate/motion statement, optionally
      //      with a leading G01/G02/G03 and a trailing D01/D02/D03 ----
      if (Length(gline) > 0) and (gline[Length(gline)] = '*') then
        body := Copy(gline, 1, Length(gline) - 1)
      else
        body := gline;

      info := ScanCoordLine(body, fracDigits);

      if not (info.HasX or info.HasY or info.HasI or info.HasJ or info.HasD or info.HasG) then
      begin
        AddWarning(warnings, Format('Line %d ignored (unrecognized): %s', [lineNum + 1, gline]));
        Continue;
      end;

      // Pure interpolation-mode statement (e.g. "G01*") with no coordinates.
      if info.HasG and not (info.HasX or info.HasY or info.HasI or info.HasJ or info.HasD) then
      begin
        if info.GCode in [1, 2, 3] then currentInterpMode := info.GCode;
        Continue;
      end;

      if info.HasD then currentOpCode := info.DCode;

      // Linear (G01, or interpolation mode already G01) - or a flash/move
      // with no explicit G this line (deprecated but tolerated, same as
      // camlib.py).
      if (info.HasG and (info.GCode = 1)) or
         ((not info.HasG) and (currentInterpMode <> 2) and (currentInterpMode <> 3)) then
      begin
        if info.HasX then currentX := info.X;
        if info.HasY then currentY := info.Y;

        case currentOpCode of
          1: // draw
            begin
              AppendPoint(path, currentX, currentY);
              lastPathApId := currentApId;
            end;
          2: // move (pen up)
            begin
              FinishStrokeIfAny;
              SetLength(path, 1);
              path[0].X := currentX; path[0].Y := currentY;
            end;
          3: // flash
            begin
              FinishStrokeIfAny;
              SetLength(path, 1);
              path[0].X := currentX; path[0].Y := currentY;
              DoFlash;
            end;
        end;
        Continue;
      end;

      // Circular (G02/G03, or interpolation mode already set to one of
      // them and this line only carries coordinates).
      if (info.HasG and (info.GCode in [2, 3])) or
         ((not info.HasG) and (currentInterpMode in [2, 3])) then
      begin
        if info.HasG then currentInterpMode := info.GCode;
        if not quadrantSet then
        begin
          AddWarning(warnings, Format('Line %d: arc without a preceding G74/G75 quadrant mode - skipped.', [lineNum + 1]));
          Continue;
        end;

        if currentOpCode = 2 then
        begin
          // Arc with pen up - not a real cut, just finish what we had.
          FinishStrokeIfAny;
          if info.HasX then currentX := info.X;
          if info.HasY then currentY := info.Y;
          SetLength(path, 1);
          path[0].X := currentX; path[0].Y := currentY;
          Continue;
        end;

        if currentOpCode = 3 then
        begin
          AddWarning(warnings, Format('Line %d: flash requested mid-arc - ignored.', [lineNum + 1]));
          Continue;
        end;

        if quadrantMulti then
        begin
          center.X := currentX + info.I;
          center.Y := currentY + info.J;
          radius := Sqrt(Sqr(info.I) + Sqr(info.J));
          startAngle := ArcTan2(-info.J, -info.I);
          if (not info.HasX or (info.X = currentX)) and (not info.HasY or (info.Y = currentY)) and
             (Abs(currentX - IfThen(info.HasX, info.X, currentX)) < 1e-9) then
            stopAngle := startAngle
          else
            stopAngle := ArcTan2(-(center.Y - IfThen(info.HasY, info.Y, currentY)),
                                  -(center.X - IfThen(info.HasX, info.X, currentX)));

          arcPts := GerberArc(center.X, center.Y, radius, startAngle, stopAngle,
            currentInterpMode = 2, DEFAULT_STEPS_PER_CIRCLE);
          if Length(arcPts) > 0 then
          begin
            arcPts[High(arcPts)].X := IfThen(info.HasX, info.X, currentX);
            arcPts[High(arcPts)].Y := IfThen(info.HasY, info.Y, currentY);
          end;
          AppendArc(path, arcPts);
          currentX := IfThen(info.HasX, info.X, currentX);
          currentY := IfThen(info.HasY, info.Y, currentY);
          lastPathApId := currentApId;
        end
        else
        begin
          // SINGLE quadrant: try the 4 sign combinations for I/J and
          // accept the first that (a) has a consistent radius to the
          // end point and (b) sweeps <= 90 degrees - camlib.py's own
          // documented disambiguation rule for single-quadrant arcs.
          candCenters[0].X := currentX + info.I; candCenters[0].Y := currentY + info.J;
          candCenters[1].X := currentX - info.I; candCenters[1].Y := currentY + info.J;
          candCenters[2].X := currentX + info.I; candCenters[2].Y := currentY - info.J;
          candCenters[3].X := currentX - info.I; candCenters[3].Y := currentY - info.J;
          validArc := False;
          for ci := 0 to 3 do
          begin
            radius := Sqrt(Sqr(info.I) + Sqr(info.J));
            if radius < 1e-12 then Continue;
            if Abs(Sqrt(Sqr(candCenters[ci].X - IfThen(info.HasX, info.X, currentX)) +
                        Sqr(candCenters[ci].Y - IfThen(info.HasY, info.Y, currentY))) - radius)
               > radius * 0.05 then Continue;

            startAngle := ArcTan2(currentY - candCenters[ci].Y, currentX - candCenters[ci].X);
            stopAngle := ArcTan2(IfThen(info.HasY, info.Y, currentY) - candCenters[ci].Y,
                                  IfThen(info.HasX, info.X, currentX) - candCenters[ci].X);
            if ArcSweepAngle(startAngle, stopAngle, currentInterpMode = 2) <= (Pi + 1e-6) / 2 then
            begin
              arcPts := GerberArc(candCenters[ci].X, candCenters[ci].Y, radius,
                startAngle, stopAngle, currentInterpMode = 2, DEFAULT_STEPS_PER_CIRCLE);
              if Length(arcPts) > 0 then
              begin
                arcPts[High(arcPts)].X := IfThen(info.HasX, info.X, currentX);
                arcPts[High(arcPts)].Y := IfThen(info.HasY, info.Y, currentY);
              end;
              AppendArc(path, arcPts);
              currentX := IfThen(info.HasX, info.X, currentX);
              currentY := IfThen(info.HasY, info.Y, currentY);
              lastPathApId := currentApId;
              validArc := True;
              Break;
            end;
          end;
          if not validArc then
            AddWarning(warnings, Format('Line %d: invalid single-quadrant arc.', [lineNum + 1]));
        end;
        Continue;
      end;

      // Tool/aperture change alone was already handled above (the
      // "D-code alone" branch); anything reaching here is a statement
      // this parser doesn't recognize.
      AddWarning(warnings, Format('Line %d ignored (unrecognized): %s', [lineNum + 1, gline]));
    end;

    FinishStrokeIfAny;

    if not sawMO then
      AddWarning(warnings, 'No %MO (units) statement found - assuming millimeters.');

    AUnits := units;
    if units = guInch then scaleToMM := MM_PER_INCH else scaleToMM := 1.0;

    if scaleToMM <> 1.0 then
      for i := 0 to High(features.Items) do
      begin
        // scale points (Points/Aperture sizes both need the same factor)
        for j := 0 to High(features.Items[i].Points) do
        begin
          features.Items[i].Points[j].X := features.Items[i].Points[j].X * scaleToMM;
          features.Items[i].Points[j].Y := features.Items[i].Points[j].Y * scaleToMM;
        end;
        features.Items[i].Aperture.Size := features.Items[i].Aperture.Size * scaleToMM;
        features.Items[i].Aperture.Width := features.Items[i].Aperture.Width * scaleToMM;
        features.Items[i].Aperture.Height := features.Items[i].Aperture.Height * scaleToMM;
        features.Items[i].Aperture.Diameter := features.Items[i].Aperture.Diameter * scaleToMM;
      end;

    AFeatures := features.Items;
    AWarnings := warnings.Items;
    Result := True;
  except
    on E: Exception do
    begin
      AddWarning(warnings, 'Parse error: ' + E.Message);
      AFeatures := features.Items;
      AWarnings := warnings.Items;
      Result := False;
    end;
  end;
end;

function MirrorFeaturesX(const AFeatures: TGerberFeatureArray; AAxisX: Double): TGerberFeatureArray;
var
  i, p: Integer;
begin
  SetLength(Result, Length(AFeatures));
  for i := 0 to High(AFeatures) do
  begin
    Result[i] := AFeatures[i];
    SetLength(Result[i].Points, Length(AFeatures[i].Points));
    for p := 0 to High(AFeatures[i].Points) do
    begin
      Result[i].Points[p].X := 2 * AAxisX - AFeatures[i].Points[p].X;
      Result[i].Points[p].Y := AFeatures[i].Points[p].Y;
    end;
    if AFeatures[i].Aperture.Kind = gakPolygon then
      Result[i].Aperture.Rotation := -AFeatures[i].Aperture.Rotation;
  end;
end;

initialization
  GGerberFS := DefaultFormatSettings;
  GGerberFS.DecimalSeparator := '.';

end.
