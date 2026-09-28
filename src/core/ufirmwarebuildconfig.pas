unit ufirmwarebuildconfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ufirmwareboards, ufirmwaremodules;

const
  OVERRIDE_MARKER_START = '// === GRBL-Controller-Sender Firmware Builder overrides - regenerated on every Generate, do not hand-edit ===';
  OVERRIDE_MARKER_END = '// === end Firmware Builder overrides ===';

type
  TDualDriveAxis = record
    AxisLetter: Char;   // 'X', 'Y' or 'Z'
    MotorSlot: string;  // uCNC: 'STEP5'/'STEP6'/'STEP7'; grblHAL: 'M3'..'M7'
    LimitSlot: string;  // uCNC only ('LIMIT_Y2' etc) - '' for grblHAL, whose
                         // motor slot already bundles the limit pin
  end;

  { TFirmwareSetup: one named board + dual-drive-axis configuration (Phase:
    Firmware Builder). Two ecosystems, two override shapes, verified
    directly against real source:
      - uCNC (cnc_hal_config.h): ENABLE_AXIS_AUTOLEVEL once, then per axis
        LINACT<n>_IO_MASK (OR in the second STEP<m>_IO_MASK) and
        LIMIT_<axis>2_IO_MASK STEP<m>_IO_MASK - independently definable per
        axis, so multiple simultaneous dual-drive axes are fully supported.
      - grblHAL (my_machine.h): ASYMMETRIC_AUTO_SQUARE <axis>_AXIS is a
        single-valued macro (config.h's own doc comment: "Enable asymmetric
        ganging + auto squaring for X, Y OR Z axis" - one choice, not a
        list) - deliberately capped at ONE dual-drive axis per grblHAL
        setup to match what's actually verified, rather than guessing at
        unconfirmed multi-axis support that could silently build a firmware
        that doesn't do what was configured. }
  TFirmwareSetup = class
  private
    FEnv: TBoardEnv;
    FHasEnv: Boolean;
    FAxes: array of TDualDriveAxis;
    FModules: array of TFirmwareModuleId;
    FEncPulsePin: Integer;
    FEncDirPin: Integer;
    FResolvedLcdSclPin: Integer; // set by WriteProjectCopy's pin resolution, consumed by GenerateConfigOverride
    FResolvedLcdSdaPin: Integer;
    FResolvedSrSdoPin: Integer;  // shift-register output-expander's 3 control pins, same pattern
    FResolvedSrClkPin: Integer;
    FResolvedSrLatchPin: Integer;
    FResolvedEepromClkPin: Integer; // i2c_eeprom's 2 forced-SW_I2C control pins, same pattern
    FResolvedEepromDataPin: Integer;
    FResolvedTmcTxPin: Integer; // uCNC Trinamic X-axis UART TX/RX pins, same pattern
    FResolvedTmcRxPin: Integer;
    FResolvedSdClkPin: Integer; // uCNC SD card's 4 software-SPI pins, same pattern
    FResolvedSdSdoPin: Integer;
    FResolvedSdSdiPin: Integer;
    FResolvedSdCsPin: Integer;
    FResolvedVfdTxPin: Integer; // uCNC Huanyang VFD's 2 softuart pins, same pattern
    FResolvedVfdRxPin: Integer;
    function AxisNumberUCNC(ALetter: Char): Integer; // X=0,Y=1,Z=2 (LINACT/STEP index)
    // uCNC only - validates/activates the encoder's user-chosen DIN pins
    // and auto-picks+activates 2 free DIN pins for i2c_lcd (its own
    // documented default pins are NOT safely board-independent - see
    // ufirmwareboards.pas's FindFreeGenericInputSlot doc comment). Updates
    // AMapText and FResolvedLcdSclPin/SdaPin. Returns '' on success, or a
    // human-readable reason naming the specific unavailable/absent pin.
    function ResolveAndActivateModulePins(ABm: TBoardMap; var AMapText: string): string;
  public
    constructor Create;
    procedure Clear;
    procedure SetBoardEnv(const AEnv: TBoardEnv);
    function HasBoardEnv: Boolean;
    function BoardEnv: TBoardEnv;

    function AxisCount: Integer;
    function AxisAt(AIndex: Integer): TDualDriveAxis;
    // Adds/replaces (by AxisLetter) a dual-drive axis. For fwGrblHAL,
    // enforces the single-axis cap described above by replacing whatever
    // axis was previously configured, not appending a second.
    procedure SetAxis(const AAxis: TDualDriveAxis);
    procedure RemoveAxis(AIndex: Integer);

    // Selected accessory modules (displays/encoders/keypads - see
    // ufirmwaremodules.pas). Independent of the dual-drive axis list above.
    function ModuleCount: Integer;
    function ModuleAt(AIndex: Integer): TFirmwareModuleId;
    function HasModule(AId: TFirmwareModuleId): Boolean;
    procedure SetModuleEnabled(AId: TFirmwareModuleId; AEnabled: Boolean);
    // uCNC built-in encoder's DIN pin numbers - the module has no usable
    // default (see ufirmwaremodules.pas's ModuleConfigLines), so these are
    // plain user-editable settings, not auto-picked.
    property EncoderPulsePin: Integer read FEncPulsePin write FEncPulsePin;
    property EncoderDirPin: Integer read FEncDirPin write FEncDirPin;

    // The ecosystem-specific #define block, wrapped in the marker comments
    // above so a regenerated file can find and replace its own prior block.
    // Includes both the dual-drive axis defines and every selected
    // module's own config lines.
    function GenerateConfigOverride: string;

    // Copies FEnv's source repo into ADestDir (wiped and recreated fresh -
    // generated projects are disposable, not meant to be hand-edited and
    // preserved), patches the board/map file (uncomments each configured
    // axis's motor/limit slot lines), splices GenerateConfigOverride into
    // the config file (replacing any prior override block found by its
    // marker comments, or appending one if this is the first Generate),
    // and - for any selected uCNC addon module - copies its source into
    // uCNC/src/modules/ and splices its LOAD_MODULE call into module.c
    // (AModulesRepoRoot: References/uCNC-modules, only consulted for
    // fwUCNC setups with at least one file-copy module selected).
    // Returns '' on success, or a human-readable reason on failure.
    function WriteProjectCopy(const ADestDir: string; const AModulesRepoRoot: string = ''): string;
  end;

implementation

uses
  FileUtil, LazFileUtils;

function TFirmwareSetup.AxisNumberUCNC(ALetter: Char): Integer;
begin
  case UpCase(ALetter) of
    'X': Result := 0;
    'Y': Result := 1;
    'Z': Result := 2;
  else
    Result := -1;
  end;
end;

constructor TFirmwareSetup.Create;
begin
  inherited Create;
  FEncPulsePin := 6; // arbitrary but real DIN numbers - just a starting point, user-editable
  FEncDirPin := 7;
  FResolvedLcdSclPin := 0;
  FResolvedLcdSdaPin := 0;
  FResolvedSrSdoPin := 0;
  FResolvedSrClkPin := 0;
  FResolvedSrLatchPin := 0;
  FResolvedEepromClkPin := 0;
  FResolvedEepromDataPin := 0;
  FResolvedTmcTxPin := 0;
  FResolvedTmcRxPin := 0;
  FResolvedSdClkPin := 0;
  FResolvedSdSdoPin := 0;
  FResolvedSdSdiPin := 0;
  FResolvedSdCsPin := 0;
  FResolvedVfdTxPin := 0;
  FResolvedVfdRxPin := 0;
end;

procedure TFirmwareSetup.Clear;
begin
  FHasEnv := False;
  SetLength(FAxes, 0);
  SetLength(FModules, 0);
end;

procedure TFirmwareSetup.SetBoardEnv(const AEnv: TBoardEnv);
begin
  FEnv := AEnv;
  FHasEnv := True;
  SetLength(FAxes, 0);    // a different board invalidates any prior slot choices
  SetLength(FModules, 0); // ...and any prior module selection (ecosystem may differ, board-gating may differ)
end;

function TFirmwareSetup.HasBoardEnv: Boolean;
begin
  Result := FHasEnv;
end;

function TFirmwareSetup.BoardEnv: TBoardEnv;
begin
  Result := FEnv;
end;

function TFirmwareSetup.AxisCount: Integer;
begin
  Result := Length(FAxes);
end;

function TFirmwareSetup.AxisAt(AIndex: Integer): TDualDriveAxis;
begin
  Result := FAxes[AIndex];
end;

procedure TFirmwareSetup.SetAxis(const AAxis: TDualDriveAxis);
var
  i: Integer;
begin
  if FHasEnv and (FEnv.Ecosystem = fwGrblHAL) then
  begin
    // Single-axis cap (see class comment) - replace whatever was there.
    SetLength(FAxes, 1);
    FAxes[0] := AAxis;
    Exit;
  end;

  for i := 0 to High(FAxes) do
    if UpCase(FAxes[i].AxisLetter) = UpCase(AAxis.AxisLetter) then
    begin
      FAxes[i] := AAxis;
      Exit;
    end;
  SetLength(FAxes, Length(FAxes) + 1);
  FAxes[High(FAxes)] := AAxis;
end;

procedure TFirmwareSetup.RemoveAxis(AIndex: Integer);
var
  i: Integer;
begin
  if (AIndex < 0) or (AIndex > High(FAxes)) then Exit;
  for i := AIndex to High(FAxes) - 1 do
    FAxes[i] := FAxes[i + 1];
  SetLength(FAxes, Length(FAxes) - 1);
end;

function TFirmwareSetup.ModuleCount: Integer;
begin
  Result := Length(FModules);
end;

function TFirmwareSetup.ModuleAt(AIndex: Integer): TFirmwareModuleId;
begin
  Result := FModules[AIndex];
end;

function TFirmwareSetup.HasModule(AId: TFirmwareModuleId): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(FModules) do
    if FModules[i] = AId then
    begin
      Result := True;
      Exit;
    end;
end;

procedure TFirmwareSetup.SetModuleEnabled(AId: TFirmwareModuleId; AEnabled: Boolean);
var
  i, foundAt, j: Integer;
begin
  if AEnabled then
  begin
    if HasModule(AId) then Exit;
    SetLength(FModules, Length(FModules) + 1);
    FModules[High(FModules)] := AId;
  end
  else
  begin
    foundAt := -1;
    for i := 0 to High(FModules) do
      if FModules[i] = AId then
      begin
        foundAt := i;
        Break;
      end;
    if foundAt < 0 then Exit;
    for j := foundAt to High(FModules) - 1 do
      FModules[j] := FModules[j + 1];
    SetLength(FModules, Length(FModules) - 1);
  end;
end;

function TFirmwareSetup.ResolveAndActivateModulePins(ABm: TBoardMap; var AMapText: string): string;
var
  excluded: array of Integer;   // DIN-family exclusions (i2c_lcd, encoder)
  excludedOut: array of Integer; // DOUT-family exclusions (shift-register control pins) - a
                                  // separate numbering space from DIN, tracked separately

  procedure AddToDinExcluded(APin: Integer);
  begin
    SetLength(excluded, Length(excluded) + 1);
    excluded[High(excluded)] := APin;
  end;

  procedure AddToDoutExcluded(APin: Integer);
  begin
    SetLength(excludedOut, Length(excludedOut) + 1);
    excludedOut[High(excludedOut)] := APin;
  end;

  function ActivatePin(APin: Integer; const APrefix: string = 'DIN'): Boolean;
  begin
    Result := ABm.GenericInputSlotState(APin, APrefix) = psAvailable;
    if not Result then Exit;
    AMapText := ABm.ActivateSlot(APrefix + IntToStr(APin));
    ABm.ParseFile(AMapText); // re-parse so a subsequent activation sees updated state
  end;

var
  pin: Integer;
begin
  Result := '';
  SetLength(excluded, 0);
  SetLength(excludedOut, 0);

  if HasModule(fmUCNCEncoder) then
  begin
    case ABm.GenericInputSlotState(FEncPulsePin) of
      psAbsent: begin Result := Format('This board has no DIN%d pin to use as the encoder pulse input.', [FEncPulsePin]); Exit; end;
      psActive: begin Result := Format('DIN%d is already used by something else on this board - pick a different encoder pulse pin.', [FEncPulsePin]); Exit; end;
    end;
    case ABm.GenericInputSlotState(FEncDirPin) of
      psAbsent: begin Result := Format('This board has no DIN%d pin to use as the encoder dir input.', [FEncDirPin]); Exit; end;
      psActive: begin Result := Format('DIN%d is already used by something else on this board - pick a different encoder dir pin.', [FEncDirPin]); Exit; end;
    end;
    if FEncPulsePin = FEncDirPin then
    begin
      Result := 'Encoder pulse and dir pins must be different DIN pins.';
      Exit;
    end;
    ActivatePin(FEncPulsePin);
    ActivatePin(FEncDirPin);
    AddToDinExcluded(FEncPulsePin);
    AddToDinExcluded(FEncDirPin);
  end;

  if HasModule(fmUCNCi2cLcd) then
  begin
    pin := ABm.FindFreeGenericInputSlot(excluded);
    if pin < 0 then
    begin
      Result := 'This board has no free generic DIN pins left for the I2C LCD (needs 2).';
      Exit;
    end;
    FResolvedLcdSclPin := pin;
    ActivatePin(pin);
    AddToDinExcluded(pin);

    pin := ABm.FindFreeGenericInputSlot(excluded);
    if pin < 0 then
    begin
      Result := 'This board only has 1 free generic DIN pin left - the I2C LCD needs 2 (SCL + SDA).';
      Exit;
    end;
    FResolvedLcdSdaPin := pin;
    ActivatePin(pin);
    AddToDinExcluded(pin);
  end;

  if HasModule(fmUCNCShiftRegisterOut) then
  begin
    pin := ABm.FindFreeGenericInputSlot(excludedOut, 'DOUT');
    if pin < 0 then
    begin
      Result := 'This board has no free generic DOUT pins left for the output expander (needs 3: SDO/CLK/LATCH).';
      Exit;
    end;
    FResolvedSrSdoPin := pin;
    ActivatePin(pin, 'DOUT');
    AddToDoutExcluded(pin);

    pin := ABm.FindFreeGenericInputSlot(excludedOut, 'DOUT');
    if pin < 0 then
    begin
      Result := 'This board only has 1 free generic DOUT pin left - the output expander needs 3 (SDO/CLK/LATCH).';
      Exit;
    end;
    FResolvedSrClkPin := pin;
    ActivatePin(pin, 'DOUT');
    AddToDoutExcluded(pin);

    pin := ABm.FindFreeGenericInputSlot(excludedOut, 'DOUT');
    if pin < 0 then
    begin
      Result := 'This board only has 2 free generic DOUT pins left - the output expander needs 3 (SDO/CLK/LATCH).';
      Exit;
    end;
    FResolvedSrLatchPin := pin;
    ActivatePin(pin, 'DOUT');
    AddToDoutExcluded(pin);
  end;

  if HasModule(fmUCNCEeprom) then
  begin
    pin := ABm.FindFreeGenericInputSlot(excluded);
    if pin < 0 then
    begin
      Result := 'This board has no free generic DIN pins left for the EEPROM (needs 2: clock/data).';
      Exit;
    end;
    FResolvedEepromClkPin := pin;
    ActivatePin(pin);
    AddToDinExcluded(pin);

    pin := ABm.FindFreeGenericInputSlot(excluded);
    if pin < 0 then
    begin
      Result := 'This board only has 1 free generic DIN pin left - the EEPROM needs 2 (clock/data).';
      Exit;
    end;
    FResolvedEepromDataPin := pin;
    ActivatePin(pin);
    AddToDinExcluded(pin);
  end;

  if HasModule(fmUCNCTrinamicX) then
  begin
    // TX is a DOUT-family pin, RX is DIN-family - a genuinely mixed pair,
    // each resolved against its own exclusion list.
    pin := ABm.FindFreeGenericInputSlot(excludedOut, 'DOUT');
    if pin < 0 then
    begin
      Result := 'This board has no free generic DOUT pins left for the Trinamic UART TX pin.';
      Exit;
    end;
    FResolvedTmcTxPin := pin;
    ActivatePin(pin, 'DOUT');
    AddToDoutExcluded(pin);

    pin := ABm.FindFreeGenericInputSlot(excluded);
    if pin < 0 then
    begin
      Result := 'This board has no free generic DIN pins left for the Trinamic UART RX pin.';
      Exit;
    end;
    FResolvedTmcRxPin := pin;
    ActivatePin(pin);
    AddToDinExcluded(pin);
  end;

  if HasModule(fmUCNCSdCard) then
  begin
    // 3 DOUT pins (CLK/SDO/CS) + 1 DIN pin (SDI) - forces software SPI
    // rather than trusting the module's own hardware-SPI default.
    pin := ABm.FindFreeGenericInputSlot(excludedOut, 'DOUT');
    if pin < 0 then
    begin
      Result := 'This board has no free generic DOUT pins left for the SD card SPI clock pin.';
      Exit;
    end;
    FResolvedSdClkPin := pin;
    ActivatePin(pin, 'DOUT');
    AddToDoutExcluded(pin);

    pin := ABm.FindFreeGenericInputSlot(excludedOut, 'DOUT');
    if pin < 0 then
    begin
      Result := 'This board only has 1 free generic DOUT pin left - the SD card needs 3 (CLK/SDO/CS).';
      Exit;
    end;
    FResolvedSdSdoPin := pin;
    ActivatePin(pin, 'DOUT');
    AddToDoutExcluded(pin);

    pin := ABm.FindFreeGenericInputSlot(excludedOut, 'DOUT');
    if pin < 0 then
    begin
      Result := 'This board only has 2 free generic DOUT pins left - the SD card needs 3 (CLK/SDO/CS).';
      Exit;
    end;
    FResolvedSdCsPin := pin;
    ActivatePin(pin, 'DOUT');
    AddToDoutExcluded(pin);

    pin := ABm.FindFreeGenericInputSlot(excluded);
    if pin < 0 then
    begin
      Result := 'This board has no free generic DIN pins left for the SD card SPI data-in pin.';
      Exit;
    end;
    FResolvedSdSdiPin := pin;
    ActivatePin(pin);
    AddToDinExcluded(pin);
  end;

  if HasModule(fmUCNCModbusVfd) then
  begin
    pin := ABm.FindFreeGenericInputSlot(excludedOut, 'DOUT');
    if pin < 0 then
    begin
      Result := 'This board has no free generic DOUT pins left for the VFD Modbus TX pin.';
      Exit;
    end;
    FResolvedVfdTxPin := pin;
    ActivatePin(pin, 'DOUT');
    AddToDoutExcluded(pin);

    pin := ABm.FindFreeGenericInputSlot(excluded);
    if pin < 0 then
    begin
      Result := 'This board has no free generic DIN pins left for the VFD Modbus RX pin.';
      Exit;
    end;
    FResolvedVfdRxPin := pin;
    ActivatePin(pin);
    AddToDinExcluded(pin);
  end;
end;

function TFirmwareSetup.GenerateConfigOverride: string;
var
  sb: TStringList;
  i, j, linact: Integer;
  a: TDualDriveAxis;
  modLines: TStringArray;
begin
  sb := TStringList.Create;
  try
    sb.Add(OVERRIDE_MARKER_START);
    if not FHasEnv then
    begin
      sb.Add(OVERRIDE_MARKER_END);
      Result := sb.Text;
      Exit;
    end;

    if FEnv.Ecosystem = fwUCNC then
    begin
      if Length(FAxes) > 0 then
        sb.Add('#define ENABLE_AXIS_AUTOLEVEL');
      for i := 0 to High(FAxes) do
      begin
        a := FAxes[i];
        linact := AxisNumberUCNC(a.AxisLetter);
        if linact < 0 then Continue;
        sb.Add(Format('#define LINACT%d_IO_MASK (STEP%d_IO_MASK | %s_IO_MASK)',
          [linact, linact, a.MotorSlot]));
        if a.LimitSlot <> '' then
          sb.Add(Format('#define %s_IO_MASK %s_IO_MASK', [a.LimitSlot, a.MotorSlot]));
      end;
    end
    else // fwGrblHAL
    begin
      if Length(FAxes) > 0 then
        sb.Add(Format('#define ASYMMETRIC_AUTO_SQUARE %s_AXIS', [UpCase(FAxes[0].AxisLetter)]));
    end;

    for i := 0 to High(FModules) do
    begin
      modLines := ModuleConfigLines(FModules[i], FEncPulsePin, FEncDirPin,
        FResolvedLcdSclPin, FResolvedLcdSdaPin,
        FResolvedSrSdoPin, FResolvedSrClkPin, FResolvedSrLatchPin,
        FResolvedTmcTxPin, FResolvedTmcRxPin,
        FResolvedEepromClkPin, FResolvedEepromDataPin,
        FResolvedSdClkPin, FResolvedSdSdoPin, FResolvedSdSdiPin, FResolvedSdCsPin,
        FResolvedVfdTxPin, FResolvedVfdRxPin);
      for j := 0 to High(modLines) do
        sb.Add(modLines[j]);
    end;

    sb.Add(OVERRIDE_MARKER_END);
    Result := sb.Text;
  finally
    sb.Free;
  end;
end;

// Splices ANewBlock into AFullText, replacing a prior block delimited by
// OVERRIDE_MARKER_START/_END if one exists, or appending ANewBlock at the
// end of the file otherwise.
function SpliceOverrideBlock(const AFullText, ANewBlock: string): string;
var
  lines: TStringList;
  startLine, endLine, i: Integer;
  resultLines: TStringList;
begin
  lines := TStringList.Create;
  resultLines := TStringList.Create;
  try
    lines.Text := AFullText;
    startLine := -1;
    endLine := -1;
    for i := 0 to lines.Count - 1 do
    begin
      if Trim(lines[i]) = OVERRIDE_MARKER_START then startLine := i
      else if (startLine >= 0) and (Trim(lines[i]) = OVERRIDE_MARKER_END) then
      begin
        endLine := i;
        Break;
      end;
    end;

    if (startLine >= 0) and (endLine >= startLine) then
    begin
      for i := 0 to startLine - 1 do resultLines.Add(lines[i]);
      resultLines.Add(TrimRight(ANewBlock));
      for i := endLine + 1 to lines.Count - 1 do resultLines.Add(lines[i]);
    end
    else
    begin
      for i := 0 to lines.Count - 1 do resultLines.Add(lines[i]);
      resultLines.Add('');
      resultLines.Add(TrimRight(ANewBlock));
    end;

    Result := resultLines.Text;
  finally
    resultLines.Free;
    lines.Free;
  end;
end;

// Removes every `-D OVERRIDE_MY_MACHINE` / `-DOVERRIDE_MY_MACHINE` line from
// <ADestDir>/platformio.ini (there may be several - ESP32's own file repeats
// it once per env rather than sharing one [common] section) - see
// WriteProjectCopy's call site for the full real-world finding this fixes.
// Returns '' on success, including if platformio.ini doesn't exist (a
// no-op, not an error - a hypothetical future grblHAL family scanned
// without one would just build with whatever pio itself reports).
function StripOverrideMyMachineFlag(const ADestDir: string): string;
var
  iniPath, s: string;
  f: TStringList;
  i: Integer;
begin
  Result := '';
  iniPath := IncludeTrailingPathDelimiter(ADestDir) + 'platformio.ini';
  if not FileExists(iniPath) then Exit;

  f := TStringList.Create;
  try
    f.LoadFromFile(iniPath);
    for i := f.Count - 1 downto 0 do
    begin
      s := Trim(f[i]);
      if (s = '-D OVERRIDE_MY_MACHINE') or (s = '-DOVERRIDE_MY_MACHINE') then
        f.Delete(i);
    end;
    f.SaveToFile(iniPath);
  finally
    f.Free;
  end;
end;

// SECOND real, verified fix for the same class of problem: unlike keypad/
// laser/motors/plugins/etc, the `encoder` submodule directory is present
// in the real source tree (confirmed: References/grblHAL-driver-stm32f4xx/
// encoder/encoder.c is real, populated Plugin_encoder source) but is simply
// missing from platformio.ini's own `lib_deps` list - upstream's own
// omission, not something conditional. Without it, PlatformIO's Library
// Dependency Finder never compiles/links encoder.c at all, so
// `ENCODER_ENABLE 1` (now that StripOverrideMyMachineFlag lets it reach the
// compiler) makes driver.c call `encoder_init()` - but that symbol is
// undefined, a real linker error ("undefined reference to `encoder_init'"),
// confirmed via a real `pio run` before this fix and a real successful,
// byte-different-from-stock build after it. Only touches lib_deps entries
// that are a bare `lib_deps =` line (the shared [common] section's
// multi-line list format - per-env sections just reference
// `${common.lib_deps}` and don't need their own edit) and only if the
// `encoder` directory actually exists in ADestDir (a real safety check -
// ModuleAvailableForBoard already restricts fmGrblHALEncoder to the 2 real
// QEI-capable stm32f4xx boards, so this should only ever fire there, but
// checking again here means a future family without this directory can
// never end up with a broken, nonexistent lib_deps entry).
function AddEncoderLibDep(const ADestDir: string): string;
var
  iniPath: string;
  f: TStringList;
  i, insertAt: Integer;
  alreadyPresent: Boolean;
begin
  Result := '';
  if not DirectoryExists(IncludeTrailingPathDelimiter(ADestDir) + 'encoder') then Exit;

  iniPath := IncludeTrailingPathDelimiter(ADestDir) + 'platformio.ini';
  if not FileExists(iniPath) then Exit;

  f := TStringList.Create;
  try
    f.LoadFromFile(iniPath);

    alreadyPresent := False;
    for i := 0 to f.Count - 1 do
      if Trim(f[i]) = 'encoder' then
      begin
        alreadyPresent := True;
        Break;
      end;
    if alreadyPresent then Exit;

    insertAt := -1;
    for i := 0 to f.Count - 1 do
      if Trim(f[i]) = 'lib_deps =' then
      begin
        insertAt := i;
        Break;
      end;
    if insertAt < 0 then Exit; // no bare multi-line lib_deps section found - leave untouched

    f.Insert(insertAt + 1, '  encoder');
    f.SaveToFile(iniPath);
  finally
    f.Free;
  end;
end;

// Inserts ALines (in order) right after the first bare "<AMarker> ="
// line found in AIniPath's own [common] section - shared helper behind
// AddEncoderLibDep's single-line pattern and AddNetworkingSupport's
// multi-line one. The "already present" dedup check is deliberately
// scoped to just the CONTIGUOUS indented block immediately following the
// marker (i.e. the marker's own value, up to the next blank/unindented
// line) - not the whole file. A real bug was caught here: platformio.ini
// has other env-groups ([eth_networking]/[wiznet_networking]) that
// happen to list these exact same lines (`networking`,
// `Middlewares/Third_Party/LwIP`, etc.) under their OWN, different,
// unused markers - a whole-file search treated those as "already
// present" and silently skipped the real insertion into [common]. No-op
// if AMarker isn't found. Returns False only on a genuine I/O failure.
function InsertLinesAfterFirstBareMarker(const AIniPath, AMarker: string;
  const ALines: array of string): Boolean;
var
  f: TStringList;
  i, j, insertAt, blockEnd: Integer;
  alreadyPresent: Boolean;
begin
  Result := True;
  f := TStringList.Create;
  try
    f.LoadFromFile(AIniPath);

    insertAt := -1;
    for i := 0 to f.Count - 1 do
      if Trim(f[i]) = AMarker + ' =' then
      begin
        insertAt := i;
        Break;
      end;
    if insertAt < 0 then Exit; // marker not found - leave untouched

    // The marker's own value block: contiguous lines right after it that
    // are indented (start with a space/tab) and non-blank.
    blockEnd := insertAt;
    while (blockEnd + 1 < f.Count) and (Length(f[blockEnd + 1]) > 0) and
          (f[blockEnd + 1][1] in [' ', #9]) do
      Inc(blockEnd);

    for j := High(ALines) downto 0 do
    begin
      alreadyPresent := False;
      for i := insertAt + 1 to blockEnd do
        if Trim(f[i]) = Trim(ALines[j]) then
        begin
          alreadyPresent := True;
          Break;
        end;
      if not alreadyPresent then
        f.Insert(insertAt + 1, ALines[j]);
    end;

    f.SaveToFile(AIniPath);
  finally
    f.Free;
  end;
end;

// Adds the real, confirmed build_flags/lib_deps needed for grblHAL's
// WIZnet Ethernet support (fmGrblHALEthernet) - found by tracing two real
// `pio` compile failures to source, not guessed:
//   1. "wizchip_conf.h: No such file or directory" - the WIZnet driver
//      headers live under `networking/wiznet/`, but that include path is
//      ONLY added by platformio.ini's own [eth_networking]/
//      [wiznet_networking] env-groups, neither of which any of our real
//      buildable envs actually extends.
//   2. "lwip/ip_addr.h: No such file or directory" - grblHAL/Plugin_networking
//      needs a real lwIP TCP/IP stack; platformio.ini's own
//      [eth_networking] group points at a bare `lwip` lib_dep/include path
//      that doesn't exist anywhere in this clone, but [wiznet_networking]
//      points at `Middlewares/Third_Party/LwIP` - which IS real and
//      already present (a full STM32Cube-vendored lwIP). That's the
//      recipe used here (`webui`, also listed in [wiznet_networking], was
//      tested and confirmed NOT required for plain Ethernet - a real
//      `pio run` succeeds without it).
function AddNetworkingSupport(const ADestDir: string): string;
const
  BUILD_FLAGS_LINES: array[0..4] of string = (
    '  -I networking/wiznet',
    '  -I Middlewares/Third_Party/LwIP/src/include',
    '  -I Middlewares/Third_Party/LwIP/system',
    '  -I Middlewares/Third_Party/LwIP/src/include/netif',
    '  -I Middlewares/Third_Party/LwIP/src/include/lwip');
  LIB_DEPS_LINES: array[0..1] of string = (
    '  networking',
    '  Middlewares/Third_Party/LwIP');
var
  iniPath: string;
begin
  Result := '';
  if not DirectoryExists(IncludeTrailingPathDelimiter(ADestDir) + 'networking') then Exit;
  if not DirectoryExists(IncludeTrailingPathDelimiter(ADestDir) + 'Middlewares' + PathDelim +
       'Third_Party' + PathDelim + 'LwIP') then Exit;

  iniPath := IncludeTrailingPathDelimiter(ADestDir) + 'platformio.ini';
  if not FileExists(iniPath) then Exit;

  if not InsertLinesAfterFirstBareMarker(iniPath, 'build_flags', BUILD_FLAGS_LINES) or
     not InsertLinesAfterFirstBareMarker(iniPath, 'lib_deps', LIB_DEPS_LINES) then
    Result := 'Could not patch platformio.ini to add Ethernet networking support.';
end;

function TFirmwareSetup.WriteProjectCopy(const ADestDir: string; const AModulesRepoRoot: string = ''): string;
var
  bm: TBoardMap;
  mapFullPath, cfgFullPath, mapText, cfgText: string;
  i: Integer;
  f: TStringList;
begin
  Result := '';
  if not FHasEnv then
  begin
    Result := 'No board selected';
    Exit;
  end;

  if DirectoryExists(ADestDir) then
  begin
    if not DeleteDirectory(ADestDir, False) then
    begin
      Result := 'Could not clear the previous generated project at ' + ADestDir;
      Exit;
    end;
  end;
  if not ForceDirectories(ADestDir) then
  begin
    Result := 'Could not create ' + ADestDir;
    Exit;
  end;

  if not CopyDirTree(ExcludeTrailingPathDelimiter(FEnv.RepoDir),
       ExcludeTrailingPathDelimiter(ADestDir), [cffOverwriteFile, cffCreateDestDirectory]) then
  begin
    Result := 'Could not copy the source project to ' + ADestDir;
    Exit;
  end;

  mapFullPath := IncludeTrailingPathDelimiter(ADestDir) + FEnv.MapFilePath;
  cfgFullPath := IncludeTrailingPathDelimiter(ADestDir) + FEnv.ConfigFilePath;

  if not FileExists(mapFullPath) then
  begin
    Result := 'Copied project is missing its board/map file: ' + FEnv.MapFilePath;
    Exit;
  end;
  if not FileExists(cfgFullPath) then
  begin
    Result := 'Copied project is missing its config file: ' + FEnv.ConfigFilePath;
    Exit;
  end;

  f := TStringList.Create;
  try
    f.LoadFromFile(mapFullPath);
    mapText := f.Text;
  finally
    f.Free;
  end;

  bm := TBoardMap.Create(FEnv.Ecosystem);
  try
    bm.ParseFile(mapText);
    for i := 0 to High(FAxes) do
    begin
      mapText := bm.ActivateSlot(FAxes[i].MotorSlot);
      bm.ParseFile(mapText); // re-parse so the next ActivateSlot sees updated state
      if (FAxes[i].LimitSlot <> '') then
      begin
        mapText := bm.ActivateSlot(FAxes[i].LimitSlot);
        bm.ParseFile(mapText);
      end;
    end;

    if FEnv.Ecosystem = fwUCNC then
    begin
      Result := ResolveAndActivateModulePins(bm, mapText);
      if Result <> '' then Exit;
    end;
  finally
    bm.Free;
  end;

  f := TStringList.Create;
  try
    f.Text := mapText;
    f.SaveToFile(mapFullPath);
  finally
    f.Free;
  end;

  f := TStringList.Create;
  try
    f.LoadFromFile(cfgFullPath);
    cfgText := SpliceOverrideBlock(f.Text, GenerateConfigOverride);
    f.Text := cfgText;
    f.SaveToFile(cfgFullPath);
  finally
    f.Free;
  end;

  // CRITICAL, REAL FIX (found by comparing two real compiled ELF files
  // byte-for-byte - not a guess): every one of our 3 buildable grblHAL
  // driver repos' own platformio.ini ships `-D OVERRIDE_MY_MACHINE` (or
  // `-DOVERRIDE_MY_MACHINE`, no space, on ESP32) in EVERY env's build_flags
  // by community convention (its own comment: "ignore all settings in
  // Inc/my_machine.h" - config is meant to go into platformio.ini's own
  // build_flags instead for this PlatformIO packaging). Left in place, our
  // my_machine.h edits (ASYMMETRIC_AUTO_SQUARE, ENCODER_ENABLE,
  // KEYPAD_ENABLE, ...) are silently ignored - confirmed by a real `pio
  // run` producing a byte-for-byte IDENTICAL firmware.elf to a completely
  // untouched stock build. Stripping this one flag from the generated
  // project's platformio.ini (never from the original References/ clone)
  // is what actually makes my_machine.h edits take effect - re-confirmed
  // with the same byte-for-byte ELF comparison, now DIFFERENT from stock.
  if FEnv.Ecosystem = fwGrblHAL then
  begin
    Result := StripOverrideMyMachineFlag(ADestDir);
    if Result <> '' then Exit;

    if HasModule(fmGrblHALEncoder) then
    begin
      Result := AddEncoderLibDep(ADestDir);
      if Result <> '' then Exit;
    end;

    if HasModule(fmGrblHALEthernet) then
    begin
      Result := AddNetworkingSupport(ADestDir);
      if Result <> '' then Exit;
    end;
  end;

  if (FEnv.Ecosystem = fwUCNC) and (Length(FModules) > 0) and (AModulesRepoRoot <> '') then
  begin
    Result := ApplyUCNCModuleFiles(FModules, AModulesRepoRoot, ADestDir);
    if Result <> '' then Exit;
  end;
end;

end.
