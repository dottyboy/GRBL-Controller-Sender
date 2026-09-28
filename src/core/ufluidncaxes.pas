unit ufluidncaxes;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  // Only the two driver types seen in practice so far: the generic
  // standard_stepper (step/dir/disable pins straight off the axis driver)
  // and stepstick (same three pins, plus an ms3_pin microstep-select line -
  // this is what the user's own real 6-axis board config uses, see
  // References/CNC-Software/6 Axis Upgrade/config.yaml). Other driver types
  // (tmc_2130/2208/2209/5160, rc_servo, ...) are out of scope for this MVP -
  // a config that already uses one loads with DriverType left at whatever
  // FLoadedDriverKey says and its pin fields blank, and is left completely
  // untouched by ApplyToFullYAML (see TAxisMotorConfig.RawUnknownBlock).
  TAxisMotorDriverType = (mdtStandardStepper, mdtStepStick);

  TAxisMotorConfig = record
    Present: Boolean;          // False = this motor slot (0 or 1) doesn't exist
    LimitNegPin: string;
    LimitPosPin: string;
    LimitAllPin: string;
    HardLimits: Boolean;
    PulloffMM: Double;
    DriverType: TAxisMotorDriverType;
    StepPin: string;
    DirectionPin: string;
    DisablePin: string;
    MS3Pin: string;            // stepstick only
    // If the source config used a driver type this editor doesn't model
    // (tmc_2209, rc_servo, ...), its raw indented text is kept here
    // verbatim and DriverType/StepPin/etc above are meaningless - written
    // back unchanged instead of being regenerated. Keeps this MVP from
    // ever silently destroying a driver block it doesn't understand.
    UnknownDriverBlock: string;
  end;

  TAxisHomingConfig = record
    Cycle: Integer;
    PositiveDirection: Boolean;
    MposMM: Double;
    FeedMMPerMin: Double;
    SeekMMPerMin: Double;
    SettleMs: Integer;
    SeekScaler: Double;
    FeedScaler: Double;
  end;

  TAxisConfig = record
    Letter: Char;
    StepsPerMM: Double;
    MaxRateMMPerMin: Double;
    AccelerationMMPerSec2: Double;
    MaxTravelMM: Double;
    SoftLimits: Boolean;
    Homing: TAxisHomingConfig;
    Motors: array[0..1] of TAxisMotorConfig;
  end;

  { TFluidNCAxesConfig: a focused reader/writer for just the top-level
    "axes:" block of a FluidNC config.yaml (Phase H MVP - see the plan's
    note that a full generic config.yaml schema editor is a much larger,
    separate project; this instead parses/regenerates exactly the one
    section, splicing it back into the rest of the file which is otherwise
    kept byte-for-byte untouched - no general YAML engine needed).
    Field set and indentation grammar verified directly against the user's
    own real board config (References/CNC-Software/6 Axis Upgrade/
    config.yaml), not just the abstract schema. }
  TFluidNCAxesConfig = class
  private
    FAxes: array of TAxisConfig;
    FSharedStepperDisablePin: string;
    FHomingRuns: Integer;
    function IndexOfLetter(ALetter: Char): Integer;
  public
    constructor Create;
    procedure Clear;
    function Count: Integer;
    function AxisAt(AIndex: Integer): TAxisConfig;
    procedure SetAxis(AIndex: Integer; const AAxis: TAxisConfig);
    function AddAxis(ALetter: Char): Integer; // returns index, or existing index if already present

    // Parses just the "axes:" top-level block out of a full config.yaml
    // text. Returns False (and leaves this object empty) if no axes:
    // block is found - callers should fall back to the raw text editor.
    function ParseFromYAML(const AFullText: string): Boolean;

    // Regenerates the "axes:" block (this object's current in-memory
    // state) as YAML text, 2-space indented to match FluidNC's own
    // convention (and the user's real file).
    function GenerateYAMLBlock: string;

    // Splices GenerateYAMLBlock's output into AOriginalFullText, replacing
    // whatever the original "axes:" block spanned - every other line
    // (spindle, control, probe, macros, ...) passes through unchanged.
    function ApplyToFullYAML(const AOriginalFullText: string): string;
  end;

implementation

var
  GInvFS: TFormatSettings;

function TFluidNCAxesConfig.IndexOfLetter(ALetter: Char): Integer;
var
  i: Integer;
begin
  for i := 0 to High(FAxes) do
    if FAxes[i].Letter = ALetter then Exit(i);
  Result := -1;
end;

constructor TFluidNCAxesConfig.Create;
begin
  inherited Create;
  Clear;
end;

procedure TFluidNCAxesConfig.Clear;
begin
  SetLength(FAxes, 0);
  FSharedStepperDisablePin := '';
  FHomingRuns := 0;
end;

function TFluidNCAxesConfig.Count: Integer;
begin
  Result := Length(FAxes);
end;

function TFluidNCAxesConfig.AxisAt(AIndex: Integer): TAxisConfig;
begin
  Result := FAxes[AIndex];
end;

procedure TFluidNCAxesConfig.SetAxis(AIndex: Integer; const AAxis: TAxisConfig);
begin
  FAxes[AIndex] := AAxis;
end;

function TFluidNCAxesConfig.AddAxis(ALetter: Char): Integer;
begin
  Result := IndexOfLetter(ALetter);
  if Result >= 0 then Exit;
  SetLength(FAxes, Length(FAxes) + 1);
  Result := High(FAxes);
  FillChar(FAxes[Result], SizeOf(TAxisConfig), 0);
  FAxes[Result].Letter := ALetter;
end;

// ---------------------------------------------------------------------
// Parsing helpers: FluidNC's own config format is 2-space-indented
// "key: value" lines (Tokenizer.cpp/Parser.cpp implement a small custom
// grammar, not full YAML) - this reader works purely on indentation depth
// and "key: value" splitting, tolerant of the real-world quirks seen in
// the user's own file (trailing whitespace after values, "cycle:-1" with
// no space after the colon, blank lines between axes).
// ---------------------------------------------------------------------

function IndentOf(const ALine: string): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 1 to Length(ALine) do
    if ALine[i] = ' ' then Inc(Result)
    else Break;
end;

function IsBlankOrComment(const ALine: string): Boolean;
var
  t: string;
begin
  t := Trim(ALine);
  Result := (t = '') or (t[1] = '#');
end;

// Splits "key: value" (or "key:value", or "key:" with nothing after) at
// the FIRST colon, trimming both sides and stripping trailing whitespace
// from the value - real files have trailing spaces after the value.
procedure SplitKeyValue(const ALine: string; out AKey, AValue: string);
var
  t: string;
  colonPos: Integer;
begin
  t := Trim(ALine);
  colonPos := Pos(':', t);
  if colonPos = 0 then
  begin
    AKey := t;
    AValue := '';
    Exit;
  end;
  AKey := Trim(Copy(t, 1, colonPos - 1));
  AValue := Trim(Copy(t, colonPos + 1, Length(t) - colonPos));
end;

function ParseBoolValue(const AValue: string; ADefault: Boolean): Boolean;
var
  v: string;
begin
  v := LowerCase(Trim(AValue));
  if v = 'true' then Result := True
  else if v = 'false' then Result := False
  else Result := ADefault;
end;

function TFluidNCAxesConfig.ParseFromYAML(const AFullText: string): Boolean;
var
  lines: TStringList;
  i, n: Integer;
  indent: Integer;
  key, value: string;

  // Parses one "letter:" axis sub-block starting at line index AStart
  // (the axis's own field lines, indent level 2), returns the index of
  // the first line NOT belonging to this block.
  function ParseAxisBlock(AStart: Integer; ALetter: Char): Integer;
  var
    j: Integer;
    axisIdx: Integer;
    axis: TAxisConfig;
    subIndent: Integer;

    function ParseHomingBlock(AHStart: Integer): Integer;
    var
      k: Integer;
      hk, hv: string;
    begin
      k := AHStart;
      while (k < n) do
      begin
        if IsBlankOrComment(lines[k]) then begin Inc(k); Continue; end;
        if IndentOf(lines[k]) < 6 then Break; // back out to axis level (4) or higher
        SplitKeyValue(lines[k], hk, hv);
        hk := LowerCase(hk);
        if hk = 'cycle' then axis.Homing.Cycle := StrToIntDef(hv, 0)
        else if hk = 'positive_direction' then axis.Homing.PositiveDirection := ParseBoolValue(hv, True)
        else if hk = 'mpos_mm' then axis.Homing.MposMM := StrToFloatDef(hv, 0, GInvFS)
        else if hk = 'feed_mm_per_min' then axis.Homing.FeedMMPerMin := StrToFloatDef(hv, 50, GInvFS)
        else if hk = 'seek_mm_per_min' then axis.Homing.SeekMMPerMin := StrToFloatDef(hv, 200, GInvFS)
        else if hk = 'settle_ms' then axis.Homing.SettleMs := StrToIntDef(hv, 250)
        else if hk = 'seek_scaler' then axis.Homing.SeekScaler := StrToFloatDef(hv, 1.1, GInvFS)
        else if hk = 'feed_scaler' then axis.Homing.FeedScaler := StrToFloatDef(hv, 1.1, GInvFS);
        Inc(k);
      end;
      Result := k;
    end;

    function ParseMotorBlock(AMStart: Integer; ASlot: Integer): Integer;
    var
      k, driverStart: Integer;
      mk, mv, driverKey: string;
    begin
      k := AMStart;
      axis.Motors[ASlot].Present := True;
      while (k < n) do
      begin
        if IsBlankOrComment(lines[k]) then begin Inc(k); Continue; end;
        if IndentOf(lines[k]) < 6 then Break; // back to axis level
        SplitKeyValue(lines[k], mk, mv);
        driverKey := LowerCase(mk);
        // A driver-type sub-block header: no inline value, and the next
        // line is indented deeper - every real motor-level field
        // (limit_*_pin, hard_limits, pulloff_mm) always has an inline
        // value, so this shape only ever means "driver type block".
        if (mv = '') and (driverKey <> '') and (IndentOf(lines[k]) = 6) and
           (k + 1 < n) and (IndentOf(lines[k + 1]) > 6) then
        begin
          // A driver-type sub-block header (its own fields are indented
          // one level deeper than motor-level fields like hard_limits).
          driverStart := k + 1;
          if driverKey = 'standard_stepper' then
          begin
            axis.Motors[ASlot].DriverType := mdtStandardStepper;
            k := driverStart;
            while (k < n) and (not IsBlankOrComment(lines[k])) and (IndentOf(lines[k]) > 6) do
            begin
              SplitKeyValue(lines[k], mk, mv);
              mk := LowerCase(mk);
              if mk = 'step_pin' then axis.Motors[ASlot].StepPin := mv
              else if mk = 'direction_pin' then axis.Motors[ASlot].DirectionPin := mv
              else if mk = 'disable_pin' then axis.Motors[ASlot].DisablePin := mv;
              Inc(k);
            end;
          end
          else if driverKey = 'stepstick' then
          begin
            axis.Motors[ASlot].DriverType := mdtStepStick;
            k := driverStart;
            while (k < n) and (not IsBlankOrComment(lines[k])) and (IndentOf(lines[k]) > 6) do
            begin
              SplitKeyValue(lines[k], mk, mv);
              mk := LowerCase(mk);
              if mk = 'step_pin' then axis.Motors[ASlot].StepPin := mv
              else if mk = 'direction_pin' then axis.Motors[ASlot].DirectionPin := mv
              else if mk = 'disable_pin' then axis.Motors[ASlot].DisablePin := mv
              else if mk = 'ms3_pin' then axis.Motors[ASlot].MS3Pin := mv;
              Inc(k);
            end;
          end
          else
          begin
            // Unrecognized driver type - preserve its block verbatim.
            k := driverStart;
            while (k < n) and (not IsBlankOrComment(lines[k])) and (IndentOf(lines[k]) > 6) do
            begin
              axis.Motors[ASlot].UnknownDriverBlock :=
                axis.Motors[ASlot].UnknownDriverBlock + lines[k] + LineEnding;
              Inc(k);
            end;
          end;
        end
        else
        begin
          case driverKey of
            'limit_neg_pin': axis.Motors[ASlot].LimitNegPin := mv;
            'limit_pos_pin': axis.Motors[ASlot].LimitPosPin := mv;
            'limit_all_pin': axis.Motors[ASlot].LimitAllPin := mv;
            'hard_limits': axis.Motors[ASlot].HardLimits := ParseBoolValue(mv, False);
            'pulloff_mm': axis.Motors[ASlot].PulloffMM := StrToFloatDef(mv, 1.0, GInvFS);
          end;
          Inc(k);
        end;
      end;
      Result := k;
    end;

  begin
    axisIdx := AddAxis(ALetter);
    axis := FAxes[axisIdx];
    j := AStart;
    while (j < n) do
    begin
      if IsBlankOrComment(lines[j]) then begin Inc(j); Continue; end;
      subIndent := IndentOf(lines[j]);
      if subIndent < 4 then Break; // back out to "axes:" level (0) or next axis (2)
      SplitKeyValue(lines[j], key, value);
      key := LowerCase(key);
      if key = 'homing' then
        j := ParseHomingBlock(j + 1)
      else if key = 'motor0' then
        j := ParseMotorBlock(j + 1, 0)
      else if key = 'motor1' then
        j := ParseMotorBlock(j + 1, 1)
      else
      begin
        if key = 'steps_per_mm' then axis.StepsPerMM := StrToFloatDef(value, 800, GInvFS)
        else if key = 'max_rate_mm_per_min' then axis.MaxRateMMPerMin := StrToFloatDef(value, 1000, GInvFS)
        else if key = 'acceleration_mm_per_sec2' then axis.AccelerationMMPerSec2 := StrToFloatDef(value, 25, GInvFS)
        else if key = 'max_travel_mm' then axis.MaxTravelMM := StrToFloatDef(value, 1000, GInvFS)
        else if key = 'soft_limits' then axis.SoftLimits := ParseBoolValue(value, False);
        Inc(j);
      end;
    end;
    FAxes[axisIdx] := axis;
    Result := j;
  end;

begin
  Result := False;
  Clear;
  lines := TStringList.Create;
  try
    lines.Text := AFullText;
    n := lines.Count;
    i := 0;
    // Find the top-level "axes:" line (indent 0).
    while (i < n) and not ((IndentOf(lines[i]) = 0) and (LowerCase(Trim(lines[i])) = 'axes:')) do
      Inc(i);
    if i >= n then Exit; // no axes: block in this file

    Result := True;
    Inc(i);
    while (i < n) do
    begin
      if IsBlankOrComment(lines[i]) then begin Inc(i); Continue; end;
      indent := IndentOf(lines[i]);
      if indent = 0 then Break; // next top-level section - axes: block is done

      if indent = 2 then
      begin
        SplitKeyValue(lines[i], key, value);
        key := LowerCase(key);
        if key = 'shared_stepper_disable_pin' then
        begin
          FSharedStepperDisablePin := value;
          Inc(i);
        end
        else if key = 'homing_runs' then
        begin
          FHomingRuns := StrToIntDef(value, 0);
          Inc(i);
        end
        else if (Length(key) = 1) and (key[1] in ['x', 'y', 'z', 'a', 'b', 'c', 'u', 'v', 'w']) then
          i := ParseAxisBlock(i + 1, UpCase(key[1]))
        else
          Inc(i); // unrecognized axis-level key - skip, don't crash
      end
      else
        Inc(i); // stray deeper indent with no owning key at this point - skip
    end;
  finally
    lines.Free;
  end;
end;

function TFluidNCAxesConfig.GenerateYAMLBlock: string;
var
  sb: TStringList;
  i, m: Integer;
  a: TAxisConfig;
  mc: TAxisMotorConfig;

  function Fl(AValue: Double): string;
  begin
    Result := FormatFloat('0.000', AValue, GInvFS);
  end;
  function Bl(AValue: Boolean): string;
  begin
    if AValue then Result := 'true' else Result := 'false';
  end;

begin
  sb := TStringList.Create;
  try
    sb.Add('axes:');
    if FSharedStepperDisablePin <> '' then
      sb.Add('  shared_stepper_disable_pin: ' + FSharedStepperDisablePin);
    if FHomingRuns > 0 then
      sb.Add('  homing_runs: ' + IntToStr(FHomingRuns));

    for i := 0 to High(FAxes) do
    begin
      a := FAxes[i];
      sb.Add('  ' + LowerCase(a.Letter) + ':');
      sb.Add('    steps_per_mm: ' + Fl(a.StepsPerMM));
      sb.Add('    max_rate_mm_per_min: ' + Fl(a.MaxRateMMPerMin));
      sb.Add('    acceleration_mm_per_sec2: ' + Fl(a.AccelerationMMPerSec2));
      sb.Add('    max_travel_mm: ' + Fl(a.MaxTravelMM));
      sb.Add('    soft_limits: ' + Bl(a.SoftLimits));
      sb.Add('    homing:');
      sb.Add('      cycle: ' + IntToStr(a.Homing.Cycle));
      sb.Add('      positive_direction: ' + Bl(a.Homing.PositiveDirection));
      sb.Add('      mpos_mm: ' + Fl(a.Homing.MposMM));
      sb.Add('      feed_mm_per_min: ' + Fl(a.Homing.FeedMMPerMin));
      sb.Add('      seek_mm_per_min: ' + Fl(a.Homing.SeekMMPerMin));
      sb.Add('      settle_ms: ' + IntToStr(a.Homing.SettleMs));
      sb.Add('      seek_scaler: ' + Fl(a.Homing.SeekScaler));
      sb.Add('      feed_scaler: ' + Fl(a.Homing.FeedScaler));
      sb.Add('');

      for m := 0 to 1 do
      begin
        mc := a.Motors[m];
        if not mc.Present then Continue;
        sb.Add('    motor' + IntToStr(m) + ':');
        sb.Add('      limit_neg_pin: ' + mc.LimitNegPin);
        sb.Add('      limit_pos_pin: ' + mc.LimitPosPin);
        sb.Add('      limit_all_pin: ' + mc.LimitAllPin);
        sb.Add('      hard_limits: ' + Bl(mc.HardLimits));
        sb.Add('      pulloff_mm: ' + Fl(mc.PulloffMM));
        if mc.UnknownDriverBlock <> '' then
          sb.Add(TrimRight(mc.UnknownDriverBlock))
        else if mc.DriverType = mdtStepStick then
        begin
          sb.Add('      stepstick:');
          sb.Add('        ms3_pin: ' + mc.MS3Pin);
          sb.Add('        step_pin: ' + mc.StepPin);
          sb.Add('        direction_pin: ' + mc.DirectionPin);
          sb.Add('        disable_pin: ' + mc.DisablePin);
        end
        else
        begin
          sb.Add('      standard_stepper:');
          sb.Add('        step_pin: ' + mc.StepPin);
          sb.Add('        direction_pin: ' + mc.DirectionPin);
          sb.Add('        disable_pin: ' + mc.DisablePin);
        end;
        sb.Add('');
      end;
    end;

    Result := sb.Text;
  finally
    sb.Free;
  end;
end;

function TFluidNCAxesConfig.ApplyToFullYAML(const AOriginalFullText: string): string;
var
  lines: TStringList;
  i, startLine, endLine, n: Integer;
  newBlock: TStringList;
  resultLines: TStringList;
begin
  lines := TStringList.Create;
  newBlock := TStringList.Create;
  resultLines := TStringList.Create;
  try
    lines.Text := AOriginalFullText;
    n := lines.Count;
    startLine := -1;
    i := 0;
    while (i < n) and not ((IndentOf(lines[i]) = 0) and (LowerCase(Trim(lines[i])) = 'axes:')) do
      Inc(i);
    if i >= n then
    begin
      // No existing axes: block - append this one at the end.
      Result := TrimRight(AOriginalFullText) + LineEnding + LineEnding + TrimRight(GenerateYAMLBlock) + LineEnding;
      Exit;
    end;
    startLine := i;
    endLine := i + 1;
    while (endLine < n) and
          (IsBlankOrComment(lines[endLine]) or (IndentOf(lines[endLine]) > 0)) do
      Inc(endLine);
    // [startLine..endLine-1] is the span to replace.
    for i := 0 to startLine - 1 do
      resultLines.Add(lines[i]);
    newBlock.Text := TrimRight(GenerateYAMLBlock);
    for i := 0 to newBlock.Count - 1 do
      resultLines.Add(newBlock[i]);
    for i := endLine to n - 1 do
      resultLines.Add(lines[i]);
    Result := resultLines.Text;
  finally
    resultLines.Free;
    newBlock.Free;
    lines.Free;
  end;
end;

initialization
  GInvFS := DefaultFormatSettings;
  GInvFS.DecimalSeparator := '.';

end.
