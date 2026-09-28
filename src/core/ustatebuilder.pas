unit ustatebuilder;

{ Replays a g-code program's modal/positional state up to a given line
  WITHOUT executing it, and builds the safe g-code prefix used to resume an
  interrupted laser job from that line (plan Phase 5). Port of LaserGRBL's
  StateBuilder.cs / GrblCore.ContinueProgramFromKnown, LCL-free so it stays
  standalone-testable like every other src/core unit.

  Deliberate differences from LaserGRBL's resume sequence, all for safety:
  - units, WCS (G54-G59) and plane are restored BEFORE the repositioning
    move (LaserGRBL sends its modals after the move, so a G55 program would
    be repositioned in whatever WCS happened to be active);
  - Z is only moved if the replayed program actually commanded Z (LaserGRBL
    always moves Z, to 0 if never set);
  - position is tracked in mm and the move is sent under G21, so a G20
    program repositions correctly;
  - the replayed motion mode is re-applied to the first remaining line that
    depends on it, not just the very first remaining line. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ugcode;

type
  TReplayState = record
    X, Y, Z: Double;            // mm, in the program's own work frame
    XKnown, YKnown, ZKnown: Boolean;
    Motion: Integer;            // 0..3, or -1 (none / G80 / G38.x)
    Absolute: Boolean;
    Inches: Boolean;
    WCS: Integer;               // 54..59
    WCSSet: Boolean;
    Plane: Integer;             // 17 / 18 / 19
    InverseTime: Boolean;
    Feed: Double;               // mm/min
    FeedSet: Boolean;
    Power: Double;              // S
    PowerSet: Boolean;
    Spindle: Integer;           // 3, 4 or 5
    Mist, Flood: Boolean;
    // G92/G10/G28/G30/G53/G38 seen: the machine's own offsets/position at
    // that point can't be reconstructed from the text alone, so the
    // replayed position may not match reality - the resume UI warns.
    FrameWarning: Boolean;
  end;

  TResumeOptions = record
    DoHoming: Boolean;
    DoUnlock: Boolean;          // $X, only used when DoHoming is False
    RestoreWCO: Boolean;
    WCOX, WCOY, WCOZ: Double;   // mm, machine coordinates
  end;

procedure InitReplayState(out AState: TReplayState);
procedure ReplayLine(var AState: TReplayState; const ALine: string);
// State just before ALines[ALineIndex] runs (lines 0..ALineIndex-1 replayed).
function StateAtLine(ALines: TStrings; ALineIndex: Integer): TReplayState;
function BuildResumePreamble(const AState: TReplayState; const AOpts: TResumeOptions): TStringList;
// Preamble + ALines[ALineIndex..]. Caller frees the result.
function BuildResumeProgram(ALines: TStrings; ALineIndex: Integer;
  const AOpts: TResumeOptions; out APreambleCount: Integer): TStringList;
// Prefixes the first line at/after AStart whose axis words would run under
// the modal motion mode with 'G<AMotion> ' - after the preamble's own G0
// move, grbl's modal motion is G0, not the program's.
procedure ApplyMotionMode(ALines: TStrings; AStart, AMotion: Integer);
function GCodeNum(AValue: Double): string;

implementation

var
  InvFS: TFormatSettings;

function GCodeNum(AValue: Double): string;
begin
  Result := FormatFloat('0.####', AValue, InvFS);
  if Result = '-0' then Result := '0';
end;

function ParseWord(const ATok: string; out ALetter: Char; out AValue: Double): Boolean;
begin
  Result := False;
  if Length(ATok) < 2 then Exit;
  ALetter := ATok[1];
  Result := TryStrToFloat(Copy(ATok, 2, MaxInt), AValue, InvFS);
end;

procedure InitReplayState(out AState: TReplayState);
begin
  AState.X := 0; AState.Y := 0; AState.Z := 0;
  AState.XKnown := False; AState.YKnown := False; AState.ZKnown := False;
  AState.Motion := 0;
  AState.Absolute := True;
  AState.Inches := False;
  AState.WCS := 54;
  AState.WCSSet := False;
  AState.Plane := 17;
  AState.InverseTime := False;
  AState.Feed := 0;
  AState.FeedSet := False;
  AState.Power := 0;
  AState.PowerSet := False;
  AState.Spindle := 5;
  AState.Mist := False;
  AState.Flood := False;
  AState.FrameWarning := False;
end;

procedure ForgetPosition(var AState: TReplayState);
begin
  AState.XKnown := False;
  AState.YKnown := False;
  AState.ZKnown := False;
end;

procedure MoveAxis(var APos: Double; var AKnown: Boolean; AValue: Double; AAbsolute: Boolean);
begin
  if AAbsolute then
  begin
    APos := AValue;
    AKnown := True;
  end
  else
    APos := APos + AValue; // relative from an unknown position stays unknown
end;

procedure ReplayLine(var AState: TReplayState; const ALine: string);
var
  tokens: TStringArray;
  i, gInt, gDec, mInt: Integer;
  letter: Char;
  v, scale, fVal: Double;
  hasX, hasY, hasZ, hasF: Boolean;
  vx, vy, vz: Double;
  lineMotion: Integer;
  isG92, otherAxisUser, programEnd: Boolean;
  trimmed: string;
begin
  trimmed := Trim(ALine);
  if trimmed = '' then Exit;
  if trimmed[1] = '$' then
  begin
    if SameText(Copy(trimmed, 1, 2), '$H') then ForgetPosition(AState);
    Exit;
  end;

  tokens := TokenizeGCodeLine(trimmed);
  hasX := False; hasY := False; hasZ := False; hasF := False;
  vx := 0; vy := 0; vz := 0; fVal := 0;
  isG92 := False; otherAxisUser := False; programEnd := False;
  lineMotion := AState.Motion;

  // Modal words first, then this line's own motion - grbl's order of
  // execution, so e.g. "G91 X5" or "G20 X1" in one block replays correctly.
  for i := 0 to High(tokens) do
  begin
    if not ParseWord(tokens[i], letter, v) then Continue;
    case letter of
      'G':
        begin
          gInt := Trunc(v);
          gDec := Round((v - gInt) * 10);
          case gInt of
            0, 1, 2, 3: lineMotion := gInt;
            80: lineMotion := -1;
            38: begin lineMotion := -1; otherAxisUser := True; end;
            17, 18, 19: AState.Plane := gInt;
            20: AState.Inches := True;
            21: AState.Inches := False;
            54..59: begin AState.WCS := gInt; AState.WCSSet := True; end;
            90: if gDec = 0 then AState.Absolute := True;
            91: if gDec = 0 then AState.Absolute := False;
            93: AState.InverseTime := True;
            94: AState.InverseTime := False;
            92: if gDec = 0 then isG92 := True else otherAxisUser := True;
            10, 28, 30, 53: otherAxisUser := True;
          end;
        end;
      'M':
        begin
          mInt := Trunc(v);
          case mInt of
            3, 4, 5: AState.Spindle := mInt;
            7: AState.Mist := True;
            8: AState.Flood := True;
            9: begin AState.Mist := False; AState.Flood := False; end;
            2, 30: programEnd := True;
          end;
        end;
      'S': begin AState.Power := v; AState.PowerSet := True; end;
      'F': begin fVal := v; hasF := True; end;
      'X': begin vx := v; hasX := True; end;
      'Y': begin vy := v; hasY := True; end;
      'Z': begin vz := v; hasZ := True; end;
    end;
  end;

  if AState.Inches then scale := 25.4 else scale := 1.0;
  AState.Motion := lineMotion;

  // In G93 (inverse time) F isn't a rate and must be restated per block
  // anyway, so it isn't carried as modal state.
  if hasF and not AState.InverseTime then
  begin
    AState.Feed := fVal * scale;
    AState.FeedSet := True;
  end;

  if isG92 then
  begin
    AState.FrameWarning := True;
    if hasX then begin AState.X := vx * scale; AState.XKnown := True; end;
    if hasY then begin AState.Y := vy * scale; AState.YKnown := True; end;
    if hasZ then begin AState.Z := vz * scale; AState.ZKnown := True; end;
  end
  else if otherAxisUser then
  begin
    AState.FrameWarning := True;
    ForgetPosition(AState);
  end
  else if (lineMotion >= 0) and (hasX or hasY or hasZ) then
  begin
    if hasX then MoveAxis(AState.X, AState.XKnown, vx * scale, AState.Absolute);
    if hasY then MoveAxis(AState.Y, AState.YKnown, vy * scale, AState.Absolute);
    if hasZ then MoveAxis(AState.Z, AState.ZKnown, vz * scale, AState.Absolute);
  end;

  if programEnd then
  begin
    // grbl's M2/M30 program-end reset (gcode.c): units and position kept.
    AState.Motion := 1;
    AState.Plane := 17;
    AState.Absolute := True;
    AState.InverseTime := False;
    AState.WCS := 54;
    AState.Spindle := 5;
    AState.Mist := False;
    AState.Flood := False;
  end;
end;

function StateAtLine(ALines: TStrings; ALineIndex: Integer): TReplayState;
var
  i: Integer;
begin
  InitReplayState(Result);
  if ALineIndex > ALines.Count then ALineIndex := ALines.Count;
  for i := 0 to ALineIndex - 1 do
    ReplayLine(Result, ALines[i]);
end;

function BuildResumePreamble(const AState: TReplayState; const AOpts: TResumeOptions): TStringList;
var
  move: string;
  scale: Double;
begin
  Result := TStringList.Create;
  Result.Add('M5');
  if AOpts.DoHoming then
    Result.Add('$H')
  else if AOpts.DoUnlock then
    Result.Add('$X');

  Result.Add('G21');
  if AState.WCSSet then
    Result.Add('G' + IntToStr(AState.WCS));
  if AOpts.RestoreWCO then
  begin
    // Position-independent (unlike LaserGRBL's G92, which needs the machine
    // position at execution time - unknown right after $H): sets the active
    // WCS offset so WCO equals the last known value. Persists in EEPROM.
    Result.Add('G92.1');
    Result.Add('G10 L2 P0 X' + GCodeNum(AOpts.WCOX) + ' Y' + GCodeNum(AOpts.WCOY) +
      ' Z' + GCodeNum(AOpts.WCOZ));
  end;
  Result.Add('G' + IntToStr(AState.Plane));

  if AState.XKnown or AState.YKnown or AState.ZKnown then
  begin
    move := 'G90 G0';
    if AState.XKnown then move := move + ' X' + GCodeNum(AState.X);
    if AState.YKnown then move := move + ' Y' + GCodeNum(AState.Y);
    if AState.ZKnown then move := move + ' Z' + GCodeNum(AState.Z);
    Result.Add(move);
  end;

  if AState.Inches then
  begin
    Result.Add('G20');
    scale := 25.4;
  end
  else
    scale := 1.0;
  if AState.Absolute then Result.Add('G90') else Result.Add('G91');
  if AState.InverseTime then Result.Add('G93') else Result.Add('G94');
  if AState.FeedSet and not AState.InverseTime then
    Result.Add('F' + GCodeNum(AState.Feed / scale));
  if AState.Mist then Result.Add('M7');
  if AState.Flood then Result.Add('M8');

  // Laser re-armed only now, after the M5 repositioning move.
  if AState.Spindle in [3, 4] then
  begin
    if AState.PowerSet then
      Result.Add('M' + IntToStr(AState.Spindle) + ' S' + GCodeNum(AState.Power))
    else
      Result.Add('M' + IntToStr(AState.Spindle));
  end
  else if AState.PowerSet then
    Result.Add('S' + GCodeNum(AState.Power));
end;

procedure ApplyMotionMode(ALines: TStrings; AStart, AMotion: Integer);
var
  i, j, gInt: Integer;
  tokens: TStringArray;
  letter: Char;
  v: Double;
  trimmed: string;
  hasAxis, hasMotion, nonMotionAxisUser: Boolean;
begin
  if AMotion < 0 then Exit;
  for i := AStart to ALines.Count - 1 do
  begin
    trimmed := Trim(ALines[i]);
    if (trimmed = '') or (trimmed[1] = '$') then Continue;
    tokens := TokenizeGCodeLine(trimmed);
    hasAxis := False; hasMotion := False; nonMotionAxisUser := False;
    for j := 0 to High(tokens) do
    begin
      if not ParseWord(tokens[j], letter, v) then Continue;
      case letter of
        'X', 'Y', 'Z', 'I', 'J', 'K', 'R': hasAxis := True;
        'G':
          begin
            gInt := Trunc(v);
            if gInt in [0, 1, 2, 3, 38, 80] then hasMotion := True
            else if gInt in [10, 28, 30, 92] then nonMotionAxisUser := True;
          end;
      end;
    end;
    if hasMotion then Exit; // program restates its own motion mode here
    if nonMotionAxisUser then Continue;
    if hasAxis then
    begin
      ALines[i] := 'G' + IntToStr(AMotion) + ' ' + ALines[i];
      Exit;
    end;
  end;
end;

function BuildResumeProgram(ALines: TStrings; ALineIndex: Integer;
  const AOpts: TResumeOptions; out APreambleCount: Integer): TStringList;
var
  st: TReplayState;
  i: Integer;
begin
  if ALineIndex < 0 then ALineIndex := 0;
  if ALineIndex > ALines.Count then ALineIndex := ALines.Count;
  st := StateAtLine(ALines, ALineIndex);
  Result := BuildResumePreamble(st, AOpts);
  APreambleCount := Result.Count;
  for i := ALineIndex to ALines.Count - 1 do
    if Trim(ALines[i]) <> '' then
      Result.Add(ALines[i]);
  ApplyMotionMode(Result, APreambleCount, st.Motion);
end;

initialization
  InvFS := DefaultFormatSettings;
  InvFS.DecimalSeparator := '.';
  InvFS.ThousandSeparator := #0;

end.
