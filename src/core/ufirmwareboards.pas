unit ufirmwareboards;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TFirmwareEcosystem = (fwUCNC, fwGrblHAL);

  // A pin "slot" is an extra motor/limit position a board may or may not
  // break out. Three real states exist across actual board files (verified
  // against multiple real boardmap_*.h/​*_map.h): psActive (already wired to
  // something - not reusable), psAvailable (present, commented out, with a
  // real pin value ready to enable), psAbsent (this board doesn't break out
  // that slot at all).
  TPinSlotState = (psAbsent, psAvailable, psActive);

  TPinSlot = record
    Name: string;
    State: TPinSlotState;
  end;

  { TBoardMap: parses one board/map header file into named pin slots and can
    re-emit the file with one slot's lines uncommented (Phase: Firmware
    Builder). Two ecosystems, two #define shapes, one shared model:
      - uCNC boardmap_*.h: "STEP6" is #define STEP6_BIT/_PORT (or just _BIT
        on GPIO-numbered MCUs - no _PORT line); "LIMIT_Y2" is #define
        LIMIT_Y2_BIT/_PORT - independent slots, picked separately.
      - grblHAL *_map.h: "M3" is #define M3_AVAILABLE plus M3_STEP_PORT/PIN,
        M3_DIRECTION_PORT/PIN, M3_LIMIT_PORT/PIN, M3_ENABLE_PORT/PIN, all
        bundled as one slot (step+dir+enable+limit together - no separate
        limit slot to pick).
    A slot's state is psActive if ANY of its associated lines are
    uncommented, psAvailable if lines exist but are ALL commented, psAbsent
    if no matching lines were found in the file at all. }
  TBoardMap = class
  private
    FEcosystem: TFirmwareEcosystem;
    FLines: TStringList; // raw file, one element per line, original text
    FSlotNames: array of string;
    FSlotLineIdx: array of array of Integer; // per slot, indexes into FLines
    function IndexOfSlotName(const AName: string): Integer;
    function EnsureSlot(const AName: string): Integer;
    procedure AddLineToSlot(ASlotIdx, ALineIdx: Integer);
    function LineIsCommentedDefine(const ALine: string; out AName: string): Boolean;
    function LineMatchesSuffix(const ADefineName, ASlotName: string;
      const ASuffixes: array of string): Boolean;
  public
    constructor Create(AEcosystem: TFirmwareEcosystem);
    destructor Destroy; override;
    procedure ParseFile(const AFileText: string);
    function Count: Integer;
    function SlotAt(AIndex: Integer): TPinSlot;
    function TryGetSlot(const AName: string; out ASlot: TPinSlot): Boolean;

    // Returns the first psAvailable slot name from the ecosystem's motor
    // ladder (uCNC: STEP5,STEP6,STEP7; grblHAL: M3,M4,M5,M6,M7), or '' if
    // none are free on this board.
    function FindFreeMotorSlot: string;
    // uCNC only - grblHAL bundles the limit pin into the motor slot itself,
    // so this always returns '' for fwGrblHAL (callers should not call it).
    function FindFreeLimitSlot(AAxisLetter: Char): string;

    // uCNC only - returns the pin number of a free (psAvailable) generic
    // "DIN<n>" input slot, not in AExclude (already-claimed pin numbers -
    // pass the same array back in on a second call to get a second,
    // different pin). Returns -1 if none are free. Used by accessory
    // modules that need generic digital input pins (e.g. i2c_lcd's
    // software-I2C SCL/SDA, the built-in ENCODERS pulse/dir pins).
    //
    // RESOLVED FINDING (a real, non-obvious µCNC requirement found by
    // tracing a real `pio` compile failure all the way to source, then
    // confirmed fixed by a real successful compile - not a guess, and not
    // an unfixable upstream bug as first suspected): activating a DIN slot
    // for OUTPUT use (e.g. i2c_lcd's software-I2C SCL/SDA, which needs
    // both directions) additionally requires
    // `#define DISABLE_HAL_CONFIG_PROTECTION` in the config. Without it,
    // `src/hal/io_hal.h` only ever generates a generic DIN pin's
    // `io<N>_config_input`/`_get_input` macros (gated on `ASSERT_PIN_IO`,
    // which - confirmed via a `#pragma message` probe compiled through the
    // real toolchain - DOES correctly resolve true for a freshly-activated
    // DIN slot, contrary to an earlier, wrong header-include-order theory);
    // the OUTPUT-side macros (`io<N>_config_output`/`_set_output`/etc) are
    // additionally wrapped in `#ifdef DISABLE_HAL_CONFIG_PROTECTION` - a
    // deliberate µCNC safety gate restricting generic DIN pins to
    // input-only by default, undocumented in i2c_lcd's own README. Once
    // this define is added (see `ufirmwaremodules.pas`'s
    // `ModuleConfigLines` for `fmUCNCi2cLcd`), a real `pio run` for i2c_lcd
    // succeeds end-to-end (verified on ESP32-MKS-TINYBEE with 2 real DIN
    // pins). The built-in ENCODERS feature never needed this flag at all -
    // it only ever calls `io_get_input`, which was never gated by it, so
    // it was correctly working via the genuine GPIO path all along (the
    // `ASSERT_PIN_EXTENDED`/`ic74hc165` "silent shift-register fallback"
    // branch only ever triggers for a pin with no real boardmap
    // declaration at all, opted into explicitly via ic74hc165.h's own
    // `<PIN>_IO_OFFSET` config - never for a genuinely board-declared,
    // correctly-activated DIN pin like the ones this function returns).
    // APrefix defaults to 'DIN' for the original callers (i2c_lcd, the
    // built-in encoder); also called with 'DOUT' for the shift-register
    // output-expander's 3 control pins (SDO/CLK/LATCH - see
    // fmUCNCShiftRegisterOut) - DOUT is a separate, equally real numbered
    // ladder (verified: `uCNC/src/hal/mcus/README.md`'s own pin table),
    // recognized by TryUCNCSlotName the same way DIN is.
    function FindFreeGenericInputSlot(const AExclude: array of Integer; const APrefix: string = 'DIN'): Integer;
    // uCNC only - true if "<APrefix><APin>" exists on this board and is
    // psAvailable (safe to ActivateSlot) or already psActive (already
    // wired to something else - NOT safe to silently claim, so callers
    // should treat only psAvailable as usable; this distinguishes that
    // from psAbsent, which means the board doesn't break out that pin at
    // all).
    function GenericInputSlotState(APin: Integer; const APrefix: string = 'DIN'): TPinSlotState;

    // Returns the parsed file's full text with ASlotName's lines
    // uncommented (every other line byte-for-byte unchanged). No-op
    // (returns the original text) if the slot is psAbsent or already
    // psActive.
    function ActivateSlot(const ASlotName: string): string;

    // The fixed control-switch (hold/resume/stop) pin names for this
    // ecosystem - uCNC: ESTOP, SAFETY_DOOR, FHOLD, CS_RES; grblHAL: RESET,
    // FEED_HOLD, CYCLE_START, SAFETY_DOOR. Recognized by ParseFile like any
    // other slot (see UCNC_CONTROL_NAMES/GRBLHAL_CONTROL_NAMES).
    function ControlSwitchNames: TStringArray;

    // One-line, read-only, human-readable summary of every control
    // switch's real state on this board, e.g. "ESTOP=active,
    // SAFETY_DOOR=absent, FHOLD=active, CS_RES=available (not wired)".
    // Many boards already wire all of these by default - this exists so a
    // user can see that at a glance rather than needing to open the raw
    // board map file. Deliberately does NOT activate anything itself
    // (unlike ActivateSlot/FindFreeGenericInputSlot elsewhere in this
    // unit) - these are safety-critical pins, so wiring one up is left as
    // a manual, deliberate action outside this tool.
    function DescribeControlSwitches: string;
  end;

  // One real, buildable board environment - either a uCNC PlatformIO env
  // (env name resolves directly to a BOARDMAP="..." build flag) or a
  // grblHAL driver-repo env (env name sets a -D BOARD_XXX flag, resolved to
  // a boards/*_map.h path via that repo's driver.h #elif dispatch chain).
  TBoardEnv = record
    Ecosystem: TFirmwareEcosystem;
    EnvName: string;
    Family: string;     // e.g. 'avr', 'stm32', 'esp32' (uCNC) or the driver
                         // repo's own family name (grblHAL)
    RepoDir: string;     // absolute path to the repo root
    MapFilePath: string; // relative to RepoDir - the board/pin file
    ConfigFilePath: string; // relative to RepoDir - cnc_hal_config.h (uCNC)
                             // or my_machine.h (grblHAL, always a sibling of
                             // the driver.h that resolved this env - verified
                             // across STM32F1xx/F4xx/ESP32)
  end;

  TBoardEnvArray = array of TBoardEnv;

// Scans References/uCNC's per-family *.ini files (under
// <AUCNCRoot>/uCNC/src/hal/boards/*/*.ini) for real "[env:NAME]" sections
// with a resolvable -D BOARDMAP="..." build flag. AUCNCRoot is the uCNC
// repo's own root (containing platformio.ini and the uCNC/ subfolder).
function ScanUCNCEnvironments(const AUCNCRoot: string): TBoardEnvArray;

// Scans one grblHAL driver repo's platformio.ini for real "[env:NAME]"
// sections with a -D BOARD_XXX flag, resolved against that repo's
// driver.h #elif dispatch chain to a real boards/*_map.h path. ARepoDir is
// the driver repo's own root; AFamily is a caller-supplied label (e.g.
// 'stm32f4xx') since grblHAL repos don't self-report one the way uCNC's
// per-family .ini filenames do.
function ScanGrblHALEnvironments(const ARepoDir, AFamily: string): TBoardEnvArray;

implementation

function StripLeadingWhitespace(const ALine: string): string;
begin
  Result := TrimLeft(ALine);
end;

function TBoardMap.IndexOfSlotName(const AName: string): Integer;
var
  i: Integer;
begin
  for i := 0 to High(FSlotNames) do
    if FSlotNames[i] = AName then Exit(i);
  Result := -1;
end;

function TBoardMap.EnsureSlot(const AName: string): Integer;
begin
  Result := IndexOfSlotName(AName);
  if Result >= 0 then Exit;
  SetLength(FSlotNames, Length(FSlotNames) + 1);
  SetLength(FSlotLineIdx, Length(FSlotLineIdx) + 1);
  Result := High(FSlotNames);
  FSlotNames[Result] := AName;
  SetLength(FSlotLineIdx[Result], 0);
end;

procedure TBoardMap.AddLineToSlot(ASlotIdx, ALineIdx: Integer);
begin
  SetLength(FSlotLineIdx[ASlotIdx], Length(FSlotLineIdx[ASlotIdx]) + 1);
  FSlotLineIdx[ASlotIdx][High(FSlotLineIdx[ASlotIdx])] := ALineIdx;
end;

constructor TBoardMap.Create(AEcosystem: TFirmwareEcosystem);
begin
  inherited Create;
  FEcosystem := AEcosystem;
  FLines := TStringList.Create;
end;

destructor TBoardMap.Destroy;
begin
  FLines.Free;
  inherited Destroy;
end;

// Recognizes "#define <NAME> ..." or "// #define <NAME> ..." (any amount of
// leading whitespace before '#' or before '//'). Returns the <NAME> token.
function TBoardMap.LineIsCommentedDefine(const ALine: string; out AName: string): Boolean;
var
  s, rest: string;
  spacePos: Integer;
begin
  Result := False;
  s := StripLeadingWhitespace(ALine);
  if Copy(s, 1, 2) = '//' then
    s := StripLeadingWhitespace(Copy(s, 3, Length(s) - 2));
  if Copy(s, 1, 7) <> '#define' then Exit;
  rest := StripLeadingWhitespace(Copy(s, 8, Length(s) - 7));
  spacePos := 1;
  while (spacePos <= Length(rest)) and (rest[spacePos] > ' ') do Inc(spacePos);
  AName := Copy(rest, 1, spacePos - 1);
  Result := AName <> '';
end;

function TBoardMap.LineMatchesSuffix(const ADefineName, ASlotName: string;
  const ASuffixes: array of string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(ASuffixes) do
    if ADefineName = ASlotName + ASuffixes[i] then Exit(True);
end;

procedure TBoardMap.ParseFile(const AFileText: string);
const
  UCNC_SUFFIXES: array[0..3] of string = ('_BIT', '_PORT', '_ISR', '_PULLUP');
  GRBLHAL_SUFFIXES: array[0..9] of string = (
    '_AVAILABLE', '_STEP_PORT', '_STEP_PIN', '_DIRECTION_PORT', '_DIRECTION_PIN',
    '_LIMIT_PORT', '_LIMIT_PIN', '_ENABLE_PORT', '_ENABLE_PIN', '_LIMIT_ISR');
  // Control-switch (hold/resume/stop) pin names - fixed, named pins, not a
  // numbered ladder like STEP/DIN. uCNC: src/hal/mcus/README.md's own pin
  // table ("ESTOP, SAFETY_DOOR, FHOLD and CS_RES pin defines the input
  // pins that controls user actions and safety features"), _BIT/_PORT
  // suffixes like any other uCNC pin. grblHAL: RESET/FEED_HOLD/
  // CYCLE_START/SAFETY_DOOR, confirmed real and already active on
  // btt_skr_pro_v1_1_map.h, _PORT/_PIN suffixes (not the M3-M7 motor
  // slot's bundled suffix set).
  UCNC_CONTROL_NAMES: array[0..3] of string = ('ESTOP', 'SAFETY_DOOR', 'FHOLD', 'CS_RES');
  GRBLHAL_CONTROL_NAMES: array[0..3] of string = ('RESET', 'FEED_HOLD', 'CYCLE_START', 'SAFETY_DOOR');
  GRBLHAL_CONTROL_SUFFIXES: array[0..1] of string = ('_PORT', '_PIN');
var
  i, slotIdx: Integer;
  defineName, slotName: string;
  matched: Boolean;

  function TryUCNCSlotName(const ADefineName: string; out ASlotName: string): Boolean;
  var
    k, m, suffixLen, prefixLen: Integer;
  begin
    Result := False;
    ASlotName := '';
    for k := 0 to High(UCNC_SUFFIXES) do
    begin
      suffixLen := Length(UCNC_SUFFIXES[k]);
      prefixLen := Length(ADefineName) - suffixLen;
      if prefixLen < 1 then Continue;
      // Suffix must be at the END of the define name, not just present
      // somewhere inside it.
      if Copy(ADefineName, prefixLen + 1, suffixLen) <> UCNC_SUFFIXES[k] then Continue;
      // Only accept if the candidate prefix is itself a plausible motor/
      // limit slot name: STEPn, DIRn, or LIMIT_<axis>2 (axis + '2').
      ASlotName := Copy(ADefineName, 1, prefixLen);
      if (Pos('STEP', ASlotName) = 1) or (Pos('DIR', ASlotName) = 1) or
         ((Pos('LIMIT_', ASlotName) = 1) and (Length(ASlotName) >= 8) and
          (ASlotName[Length(ASlotName)] = '2')) or
         ((Pos('DIN', ASlotName) = 1) and (Length(ASlotName) >= 4) and
          (StrToIntDef(Copy(ASlotName, 4, Length(ASlotName) - 3), -1) >= 0)) or
         ((Pos('DOUT', ASlotName) = 1) and (Length(ASlotName) >= 5) and
          (StrToIntDef(Copy(ASlotName, 5, Length(ASlotName) - 4), -1) >= 0)) then
        Exit(True);
      for m := 0 to High(UCNC_CONTROL_NAMES) do
        if ASlotName = UCNC_CONTROL_NAMES[m] then Exit(True);
    end;
    ASlotName := '';
  end;

  function TryGrblHALSlotName(const ADefineName: string; out ASlotName: string): Boolean;
  var
    k: Integer;
  begin
    Result := False;
    // Motor slots are named M3..M7 (see motor_pins.h) - a fixed, small set,
    // so just probe them directly rather than generic suffix-stripping.
    for k := 3 to 7 do
    begin
      ASlotName := 'M' + IntToStr(k);
      if LineMatchesSuffix(ADefineName, ASlotName, GRBLHAL_SUFFIXES) then
        Exit(True);
    end;
    for k := 0 to High(GRBLHAL_CONTROL_NAMES) do
    begin
      ASlotName := GRBLHAL_CONTROL_NAMES[k];
      if LineMatchesSuffix(ADefineName, ASlotName, GRBLHAL_CONTROL_SUFFIXES) then
        Exit(True);
    end;
    ASlotName := '';
  end;

begin
  FLines.Text := AFileText;
  SetLength(FSlotNames, 0);
  SetLength(FSlotLineIdx, 0);

  for i := 0 to FLines.Count - 1 do
  begin
    if not LineIsCommentedDefine(FLines[i], defineName) then Continue;

    if FEcosystem = fwUCNC then
      matched := TryUCNCSlotName(defineName, slotName)
    else
      matched := TryGrblHALSlotName(defineName, slotName);

    if not matched then Continue;

    slotIdx := EnsureSlot(slotName);
    AddLineToSlot(slotIdx, i);
  end;
end;

function TBoardMap.Count: Integer;
begin
  Result := Length(FSlotNames);
end;

function TBoardMap.SlotAt(AIndex: Integer): TPinSlot;
var
  i: Integer;
  anyActive, anyLine: Boolean;
  txt: string;
begin
  Result.Name := FSlotNames[AIndex];
  anyActive := False;
  anyLine := False;
  for i := 0 to High(FSlotLineIdx[AIndex]) do
  begin
    anyLine := True;
    txt := TrimLeft(FLines[FSlotLineIdx[AIndex][i]]);
    if Copy(txt, 1, 2) <> '//' then anyActive := True;
  end;
  if not anyLine then Result.State := psAbsent
  else if anyActive then Result.State := psActive
  else Result.State := psAvailable;
end;

function TBoardMap.TryGetSlot(const AName: string; out ASlot: TPinSlot): Boolean;
var
  idx: Integer;
begin
  idx := IndexOfSlotName(AName);
  Result := idx >= 0;
  if Result then ASlot := SlotAt(idx);
end;

function TBoardMap.FindFreeMotorSlot: string;
var
  i: Integer;
  slot: TPinSlot;
  candidates: array of string;
begin
  Result := '';
  if FEcosystem = fwUCNC then
  begin
    SetLength(candidates, 3);
    candidates[0] := 'STEP5'; candidates[1] := 'STEP6'; candidates[2] := 'STEP7';
  end
  else
  begin
    SetLength(candidates, 5);
    candidates[0] := 'M3'; candidates[1] := 'M4'; candidates[2] := 'M5';
    candidates[3] := 'M6'; candidates[4] := 'M7';
  end;

  for i := 0 to High(candidates) do
    if TryGetSlot(candidates[i], slot) and (slot.State = psAvailable) then
      Exit(candidates[i]);
end;

function TBoardMap.FindFreeLimitSlot(AAxisLetter: Char): string;
var
  slot: TPinSlot;
  name: string;
begin
  Result := '';
  if FEcosystem <> fwUCNC then Exit; // grblHAL bundles limit into the motor slot
  name := 'LIMIT_' + UpCase(AAxisLetter) + '2';
  if TryGetSlot(name, slot) and (slot.State = psAvailable) then
    Result := name;
end;

function TBoardMap.FindFreeGenericInputSlot(const AExclude: array of Integer; const APrefix: string): Integer;
var
  i, j, pinNum, prefixLen: Integer;
  slot: TPinSlot;
  s: string;
  excluded: Boolean;
begin
  Result := -1;
  if FEcosystem <> fwUCNC then Exit; // grblHAL has no equivalent generic-DIN/DOUT family recognized here
  prefixLen := Length(APrefix);
  for i := 0 to High(FSlotNames) do
  begin
    s := FSlotNames[i];
    if Copy(s, 1, prefixLen) <> APrefix then Continue;
    pinNum := StrToIntDef(Copy(s, prefixLen + 1, Length(s) - prefixLen), -1);
    if pinNum < 0 then Continue;

    excluded := False;
    for j := 0 to High(AExclude) do
      if AExclude[j] = pinNum then
      begin
        excluded := True;
        Break;
      end;
    if excluded then Continue;

    slot := SlotAt(i);
    if slot.State = psAvailable then Exit(pinNum);
  end;
end;

function TBoardMap.GenericInputSlotState(APin: Integer; const APrefix: string): TPinSlotState;
var
  slot: TPinSlot;
begin
  if TryGetSlot(APrefix + IntToStr(APin), slot) then
    Result := slot.State
  else
    Result := psAbsent;
end;

function TBoardMap.ActivateSlot(const ASlotName: string): string;
var
  idx, i, lineIdx, commentPos: Integer;
  slot: TPinSlot;
  line: string;
begin
  idx := IndexOfSlotName(ASlotName);
  if idx < 0 then
  begin
    Result := FLines.Text;
    Exit;
  end;
  slot := SlotAt(idx);
  if slot.State <> psAvailable then
  begin
    Result := FLines.Text;
    Exit;
  end;

  for i := 0 to High(FSlotLineIdx[idx]) do
  begin
    lineIdx := FSlotLineIdx[idx][i];
    line := FLines[lineIdx];
    // Strip a leading "// " (or "//" with no following space) - preserve
    // the rest of the line (including its own indentation) unchanged.
    if Copy(TrimLeft(line), 1, 2) = '//' then
    begin
      commentPos := Pos('//', line);
      Delete(line, commentPos, 2);
      if (commentPos <= Length(line)) and (line[commentPos] = ' ') then
        Delete(line, commentPos, 1);
      FLines[lineIdx] := line;
    end;
  end;

  Result := FLines.Text;
end;

const
  UCNC_CONTROL_NAMES_C: array[0..3] of string = ('ESTOP', 'SAFETY_DOOR', 'FHOLD', 'CS_RES');
  GRBLHAL_CONTROL_NAMES_C: array[0..3] of string = ('RESET', 'FEED_HOLD', 'CYCLE_START', 'SAFETY_DOOR');

function TBoardMap.ControlSwitchNames: TStringArray;
var
  i: Integer;
begin
  if FEcosystem = fwUCNC then
  begin
    SetLength(Result, Length(UCNC_CONTROL_NAMES_C));
    for i := 0 to High(UCNC_CONTROL_NAMES_C) do Result[i] := UCNC_CONTROL_NAMES_C[i];
  end
  else
  begin
    SetLength(Result, Length(GRBLHAL_CONTROL_NAMES_C));
    for i := 0 to High(GRBLHAL_CONTROL_NAMES_C) do Result[i] := GRBLHAL_CONTROL_NAMES_C[i];
  end;
end;

function TBoardMap.DescribeControlSwitches: string;
var
  names: TStringArray;
  i: Integer;
  slot: TPinSlot;
  stateStr: string;
begin
  names := ControlSwitchNames;
  Result := '';
  for i := 0 to High(names) do
  begin
    if not TryGetSlot(names[i], slot) then
      stateStr := 'absent'
    else case slot.State of
      psActive: stateStr := 'active';
      psAvailable: stateStr := 'available (not wired)';
    else
      stateStr := 'absent';
    end;
    if Result <> '' then Result := Result + ', ';
    Result := Result + names[i] + '=' + stateStr;
  end;
end;

function ScanUCNCEnvironments(const AUCNCRoot: string): TBoardEnvArray;
var
  boardsDir: string;
  familyInfo, iniInfo: TSearchRec;
  lines: TStringList;
  i, n, markerPos, q1, q2: Integer;
  family, line, trimmed, mapPath: string;
  inEnv: Boolean;
  curEnv: string;
const
  MARKER = 'BOARDMAP=\"';
begin
  SetLength(Result, 0);
  n := 0;
  boardsDir := IncludeTrailingPathDelimiter(AUCNCRoot) + 'uCNC/src/hal/boards/';
  if FindFirst(boardsDir + '*', faDirectory, familyInfo) <> 0 then Exit;
  try
    repeat
      if (familyInfo.Name = '.') or (familyInfo.Name = '..') then Continue;
      if (familyInfo.Attr and faDirectory) = 0 then Continue;
      family := familyInfo.Name;

      if FindFirst(boardsDir + family + '/*.ini', faAnyFile, iniInfo) = 0 then
      try
        repeat
          lines := TStringList.Create;
          try
            lines.LoadFromFile(boardsDir + family + '/' + iniInfo.Name);
            inEnv := False;
            curEnv := '';
            for i := 0 to lines.Count - 1 do
            begin
              line := lines[i];
              trimmed := Trim(line);
              if (Length(trimmed) > 6) and (Copy(trimmed, 1, 5) = '[env:') and
                 (trimmed[Length(trimmed)] = ']') then
              begin
                inEnv := True;
                curEnv := Copy(trimmed, 6, Length(trimmed) - 6);
              end
              else if (Length(trimmed) > 0) and (trimmed[1] = '[') then
                inEnv := False
              else if inEnv then
              begin
                markerPos := Pos(MARKER, line);
                if markerPos > 0 then
                begin
                  q1 := markerPos + Length(MARKER);
                  q2 := Pos('\"', line, q1);
                  if q2 > q1 then
                  begin
                    mapPath := Copy(line, q1, q2 - q1);
                    SetLength(Result, n + 1);
                    Result[n].Ecosystem := fwUCNC;
                    Result[n].EnvName := curEnv;
                    Result[n].Family := family;
                    Result[n].RepoDir := AUCNCRoot;
                    // mapPath came from the BOARDMAP="..." build flag, which
                    // is relative to the uCNC/ subfolder (platformio.ini's
                    // own include_dir=uCNC/src_dir=uCNC), not to AUCNCRoot
                    // itself - normalize to RepoDir-relative here so
                    // MapFilePath/ConfigFilePath share one convention across
                    // both ecosystems (grblHAL's are already RepoDir-direct).
                    Result[n].MapFilePath := 'uCNC/' + mapPath;
                    Result[n].ConfigFilePath := 'uCNC/cnc_hal_config.h';
                    Inc(n);
                  end;
                end;
              end;
            end;
          finally
            lines.Free;
          end;
        until FindNext(iniInfo) <> 0;
      finally
        FindClose(iniInfo);
      end;
    until FindNext(familyInfo) <> 0;
  finally
    FindClose(familyInfo);
  end;
end;

// Locates every driver.h in a grblHAL driver repo that defines a BOARD_XXX
// -> boards/yyy.h dispatch chain - most repos have exactly one (at or near
// the repo root), but some (e.g. iMXRT1062, which ships its actual driver
// as a nested Arduino-library folder with its own platformio.ini one level
// up from its own driver.h) have more than one real, independently
// buildable driver.h/platformio.ini pair. Skips known submodule/vendor
// subtrees (grbl core, HAL vendor libs, .git) since those can carry their
// own unrelated driver.h-named files. Caller owns/frees the result.
function FindAllGrblHALDriverHeaders(const ARepoDir: string): TStringList;
var
  candidates: TStringList;

  procedure Walk(const ADir: string; ADepth: Integer);
  var
    sr: TSearchRec;
    path, lname: string;
  begin
    if ADepth > 6 then Exit;
    if FindFirst(IncludeTrailingPathDelimiter(ADir) + '*', faAnyFile, sr) <> 0 then Exit;
    try
      repeat
        if (sr.Name = '.') or (sr.Name = '..') then Continue;
        path := IncludeTrailingPathDelimiter(ADir) + sr.Name;
        lname := LowerCase(sr.Name);
        if (sr.Attr and faDirectory) <> 0 then
        begin
          if (lname = 'grbl') or (lname = '.git') or (lname = 'drivers') or
             (lname = 'middlewares') or (lname = 'fatfs') or (lname = 'eeprom') or
             (lname = 'spindle') or (lname = 'trinamic') or (lname = 'webui') or
             (lname = 'sdcard') or (lname = 'keypad') or (lname = 'motors') or
             (lname = 'laser') or (lname = 'plugins') or (lname = 'plasma') then
            Continue;
          Walk(path, ADepth + 1);
        end
        else if lname = 'driver.h' then
          candidates.Add(path);
      until FindNext(sr) <> 0;
    finally
      FindClose(sr);
    end;
  end;

begin
  candidates := TStringList.Create;
  Walk(ARepoDir, 0);
  Result := candidates;
end;

// Walks upward from AStartDir (a driver.h's own directory) looking for the
// nearest platformio.ini, stopping once it would go above ARepoDir. This is
// how a real PlatformIO project's root is actually related to its driver.h
// in practice - sometimes the same directory (or an ancestor near the repo
// root), sometimes a directory *above* a nested library-style driver.h
// (confirmed: iMXRT1062's driver.h sits at grblHAL_Teensy4/src/driver.h,
// one level below its own platformio.ini at grblHAL_Teensy4/platformio.ini).
function FindNearestPlatformIOIni(const AStartDir, ARepoDir: string): string;
var
  dir, repoNorm, candidate: string;
begin
  Result := '';
  dir := ExcludeTrailingPathDelimiter(AStartDir);
  repoNorm := ExcludeTrailingPathDelimiter(ARepoDir);
  while (dir <> '') and (Length(dir) >= Length(repoNorm)) do
  begin
    candidate := IncludeTrailingPathDelimiter(dir) + 'platformio.ini';
    if FileExists(candidate) then Exit(candidate);
    if dir = repoNorm then Break;
    dir := ExtractFilePath(ExcludeTrailingPathDelimiter(dir));
    dir := ExcludeTrailingPathDelimiter(dir);
  end;
end;

// Parses a grblHAL driver.h's "#elif defined(BOARD_XXX) / #include
// "boards/yyy.h"" dispatch chain (also handles the chain's opening #ifdef
// branch) into ADispatch as Name=BOARD_XXX, Value=boards/yyy.h pairs.
procedure ParseGrblHALDispatch(const AFileText: string; ADispatch: TStringList);
var
  lines: TStringList;
  i, p1, p2: Integer;
  trimmed, pendingDefine: string;
begin
  lines := TStringList.Create;
  try
    lines.Text := AFileText;
    pendingDefine := '';
    for i := 0 to lines.Count - 1 do
    begin
      trimmed := Trim(lines[i]);
      if Copy(trimmed, 1, 7) = '#ifdef ' then
        pendingDefine := Trim(Copy(trimmed, 8, Length(trimmed) - 7))
      else if Copy(trimmed, 1, 13) = '#elif defined' then
      begin
        p1 := Pos('(', trimmed) + 1;
        p2 := Pos(')', trimmed);
        if (p1 > 1) and (p2 > p1) then
          pendingDefine := Copy(trimmed, p1, p2 - p1)
        else
          pendingDefine := '';
      end
      else if (pendingDefine <> '') and (Copy(trimmed, 1, 17) = '#include "boards/') then
      begin
        p1 := Pos('"', trimmed) + 1;
        p2 := Pos('"', trimmed, p1);
        if p2 > p1 then
          ADispatch.Values[pendingDefine] := Copy(trimmed, p1, p2 - p1);
        pendingDefine := '';
      end;
    end;
  finally
    lines.Free;
  end;
end;

function ScanGrblHALEnvironments(const ARepoDir, AFamily: string): TBoardEnvArray;
var
  n: Integer;
  processedInis: TStringList;
  driverHeaders: TStringList;
  h: Integer;

  // Processes one real (driver.h, platformio.ini) pair - most repos have
  // exactly one such pair, but see FindAllGrblHALDriverHeaders's comment
  // for why some have more than one.
  procedure ProcessPair(const ADriverPath, APlatformioPath: string);
  var
    driverRelDir, resolvedPath: string;
    dispatch, lines: TStringList;
    i, bPos, tokEnd: Integer;
    line, trimmed, curEnv, boardDefine, rawMapPath: string;
    inEnv: Boolean;

    // #include "boards/x.h" in driver.h resolves relative to driver.h's
    // own directory per standard C quoted-include rules - but at least one
    // real repo (STM32F4xx) also happens to duplicate its boards/ folder
    // at the repo root, so try driver.h-relative first (the standards-
    // correct reading) and fall back to repo-root-relative, using
    // whichever path actually exists on disk. Never fabricated.
    function ResolveMapPath(const ARaw: string): string;
    var
      candidate: string;
    begin
      candidate := driverRelDir + ARaw;
      if FileExists(IncludeTrailingPathDelimiter(ARepoDir) + candidate) then
        Exit(candidate);
      candidate := ARaw;
      if FileExists(IncludeTrailingPathDelimiter(ARepoDir) + candidate) then
        Exit(candidate);
      Result := '';
    end;

    procedure FlushPending;
    begin
      if (not inEnv) or (boardDefine = '') then Exit;
      rawMapPath := dispatch.Values[boardDefine];
      if rawMapPath = '' then Exit;
      resolvedPath := ResolveMapPath(rawMapPath);
      if resolvedPath = '' then Exit;
      SetLength(Result, n + 1);
      Result[n].Ecosystem := fwGrblHAL;
      Result[n].EnvName := curEnv;
      Result[n].Family := AFamily;
      Result[n].RepoDir := ARepoDir;
      Result[n].MapFilePath := resolvedPath;
      Result[n].ConfigFilePath := driverRelDir + 'my_machine.h';
      Inc(n);
    end;

  begin
    driverRelDir := ExtractFilePath(ADriverPath);
    Delete(driverRelDir, 1, Length(IncludeTrailingPathDelimiter(ARepoDir)));

    dispatch := TStringList.Create;
    lines := TStringList.Create;
    try
      lines.LoadFromFile(ADriverPath);
      ParseGrblHALDispatch(lines.Text, dispatch);

      lines.LoadFromFile(APlatformioPath);
      inEnv := False;
      curEnv := '';
      boardDefine := '';
      for i := 0 to lines.Count - 1 do
      begin
        line := lines[i];
        trimmed := Trim(line);
        if (Length(trimmed) > 6) and (Copy(trimmed, 1, 5) = '[env:') and
           (trimmed[Length(trimmed)] = ']') then
        begin
          FlushPending;
          inEnv := True;
          curEnv := Copy(trimmed, 6, Length(trimmed) - 6);
          boardDefine := '';
        end
        else if (Length(trimmed) > 0) and (trimmed[1] = '[') then
        begin
          FlushPending;
          inEnv := False;
          boardDefine := '';
        end
        else if inEnv and (boardDefine = '') then
        begin
          bPos := Pos('-D BOARD_', line);
          if bPos = 0 then bPos := Pos('-DBOARD_', line);
          if bPos > 0 then
          begin
            bPos := Pos('BOARD_', line, bPos);
            tokEnd := bPos;
            while (tokEnd <= Length(line)) and
                  (line[tokEnd] in ['A'..'Z', '0'..'9', '_']) do
              Inc(tokEnd);
            boardDefine := Copy(line, bPos, tokEnd - bPos);
          end;
        end;
      end;
      FlushPending;
    finally
      lines.Free;
      dispatch.Free;
    end;
  end;

var
  iniPath: string;
begin
  SetLength(Result, 0);
  n := 0;

  driverHeaders := FindAllGrblHALDriverHeaders(ARepoDir);
  processedInis := TStringList.Create;
  processedInis.Sorted := True;
  processedInis.Duplicates := dupIgnore;
  try
    for h := 0 to driverHeaders.Count - 1 do
    begin
      iniPath := FindNearestPlatformIOIni(ExtractFilePath(driverHeaders[h]), ARepoDir);
      if iniPath = '' then Continue;
      if processedInis.IndexOf(iniPath) >= 0 then Continue; // already processed this ini
      processedInis.Add(iniPath);
      ProcessPair(driverHeaders[h], iniPath);
    end;
  finally
    processedInis.Free;
    driverHeaders.Free;
  end;
end;

end.
