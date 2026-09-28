unit uboardinfo;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uvendorsniff;

type
  { TBoardInfo captures whatever a connected board's `$I` (build info)
    response actually told us. Populated by ParseBuildInfoTag as bracket-
    tag lines arrive; nothing here is guessed or defaulted to a specific
    board - an empty field just means the firmware didn't report it. }
  TBoardInfo = class
  public
    FirmwareName: string;    // 'Grbl', 'grblHAL', 'FluidNC', 'uCNC', ...
    FirmwareVersion: string; // e.g. '1.1f.20190825' or the uCNC/FluidNC version token
    DriverName: string;      // grblHAL [DRIVER:...], e.g. 'STM32F407@168MHz'
    DriverVersion: string;
    DriverOptions: string;
    BoardName: string;       // grblHAL [BOARD:...], or uCNC's/FluidNC's embedded name
    AxisCount: Integer;      // from [AXS:n:letters]; 0 = not reported
    AxisLetters: string;     // e.g. 'XYZ' or 'XYZA'
    KinematicsCode: string;  // uCNC's leading OPT token, e.g. 'C' (cartesian), 'XY' (corexy)
    SupportsGanging: Boolean; // grblHAL OPT trailing '2' flag (capability only)
    OptRaw: string;
    NewOptRaw: string;

    // Laser-module capability flags (plan Phase 4). LaserVendor is set by
    // SniffVendor (uvendorsniff.pas) as soon as a recognizable welcome/
    // model-message line arrives - see ugenericcontroller.pas's ParseLine.
    // SupportOverride/SupportPWM/SupportAutoCooling are inferred from the
    // connected controller kind (set in usender.pas's Connect - this
    // app's own GRBL1 controller specifically targets the grbl 1.1
    // protocol, the same version line LaserGRBL itself gates these
    // features on; GRBL0/Smoothie/G2Core don't get them). SupportLaserMode
    // reflects the real $32 setting once the $$ grid has been fetched -
    // False (unknown) until then, never assumed True.
    LaserVendor: TLaserVendorKind;
    SupportLaserMode: Boolean;
    SupportAutoCooling: Boolean;
    SupportOverride: Boolean;
    SupportPWM: Boolean;
    RawTags: TStringList;    // catch-all: tag -> value, for anything not modeled above
    ManuallySelected: Boolean; // True when BoardName/AxisCount came from the user
                               // picking a uboardcatalog profile, not real $I detection -
                               // DisplaySummary marks this so it's never mistaken for
                               // something the firmware actually reported.

    constructor Create;
    destructor Destroy; override;
    procedure Reset;
    function IsKnown: Boolean; // True once any tag has actually been parsed
    function DisplaySummary: string; // e.g. "grblHAL 1.1f.20190825 - BTT SKR 1.4 (STM32F407)"
  end;

// Dispatch one $I bracket-tag (already split into tag/value by the caller,
// e.g. from "[BOARD:BTT SKR 1.4]" -> ATag='BOARD', AValue='BTT SKR 1.4")
// into AInfo's fields. Mirrors bCNC's own generic
// `CNC.vars[word[0]] = word[1:]` fallback (controllers/GRBL1.py) for
// anything not explicitly modeled - see RawTags.
procedure ParseBuildInfoTag(AInfo: TBoardInfo; const ATag, AValue: string);

implementation

constructor TBoardInfo.Create;
begin
  inherited Create;
  RawTags := TStringList.Create;
  Reset;
end;

destructor TBoardInfo.Destroy;
begin
  RawTags.Free;
  inherited Destroy;
end;

procedure TBoardInfo.Reset;
begin
  FirmwareName := '';
  FirmwareVersion := '';
  DriverName := '';
  DriverVersion := '';
  DriverOptions := '';
  BoardName := '';
  AxisCount := 0;
  AxisLetters := '';
  KinematicsCode := '';
  SupportsGanging := False;
  OptRaw := '';
  NewOptRaw := '';
  RawTags.Clear;
  ManuallySelected := False;
  LaserVendor := lvGeneric;
  SupportLaserMode := False;
  SupportAutoCooling := False;
  SupportOverride := False;
  SupportPWM := False;
end;

function TBoardInfo.IsKnown: Boolean;
begin
  Result := (FirmwareName <> '') or (FirmwareVersion <> '') or
            (RawTags.Count > 0) or (BoardName <> '') or ManuallySelected;
end;

function TBoardInfo.DisplaySummary: string;
begin
  if not IsKnown then
  begin
    Result := 'Board info not yet detected';
    Exit;
  end;

  if FirmwareName <> '' then
    Result := FirmwareName
  else
    Result := 'Unknown firmware';

  if FirmwareVersion <> '' then
    Result := Result + ' ' + FirmwareVersion;

  if BoardName <> '' then
    Result := Result + ' - ' + BoardName
  else if DriverName <> '' then
    Result := Result + ' (' + DriverName + ')';

  if AxisLetters <> '' then
    Result := Result + ' [' + AxisLetters + ']';

  if ManuallySelected then
    Result := Result + ' (manually selected, not firmware-reported)';
end;

procedure ParseBuildInfoTag(AInfo: TBoardInfo; const ATag, AValue: string);
var
  sepPos, dashPos, parenPos: Integer;
  axisStr, letters, restStr: string;
  colonPos: Integer;
begin
  if ATag = 'VER' then
  begin
    AInfo.FirmwareVersion := Trim(AValue);

    // uCNC embeds its own version + board name after the base Grbl-compat
    // token: "1.1f.20220720 uCNC 1.10.0 - Generic board". Extract the
    // REAL uCNC version (not the Grbl-compat shim token) and board name.
    sepPos := Pos('uCNC', AValue);
    if sepPos > 0 then
    begin
      AInfo.FirmwareName := 'uCNC';
      restStr := Trim(Copy(AValue, sepPos + Length('uCNC'), Length(AValue)));
      dashPos := Pos(' - ', restStr);
      if dashPos > 0 then
      begin
        AInfo.FirmwareVersion := Trim(Copy(restStr, 1, dashPos - 1));
        AInfo.BoardName := Trim(Copy(restStr, dashPos + 3, Length(restStr)));
      end
      else
        AInfo.FirmwareVersion := restStr;
    end;

    // FluidNC embeds "FluidNC <version> (<MCU>-<VARIANT>)" after the base
    // Grbl-compatible version token, no " - " separator.
    sepPos := Pos('FluidNC', AValue);
    if sepPos > 0 then
    begin
      AInfo.FirmwareName := 'FluidNC';
      restStr := Trim(Copy(AValue, sepPos + Length('FluidNC'), Length(AValue)));
      parenPos := Pos('(', restStr);
      if (parenPos > 0) and (Pos(')', restStr) > parenPos) then
      begin
        AInfo.FirmwareVersion := Trim(Copy(restStr, 1, parenPos - 1));
        AInfo.DriverName := Copy(restStr, parenPos + 1, Pos(')', restStr) - parenPos - 1);
      end
      else
        AInfo.FirmwareVersion := restStr;
    end;

    // GRBL's own VER convention trails with a bare ":" (an optional, usually
    // empty, startup-line-restore field) - strip it for a clean display.
    while (Length(AInfo.FirmwareVersion) > 0) and
          (AInfo.FirmwareVersion[Length(AInfo.FirmwareVersion)] = ':') do
      SetLength(AInfo.FirmwareVersion, Length(AInfo.FirmwareVersion) - 1);
  end
  else if ATag = 'FIRMWARE' then
    AInfo.FirmwareName := Trim(AValue)
  else if ATag = 'OPT' then
  begin
    AInfo.OptRaw := AValue;
    AInfo.SupportsGanging := Pos('2', AValue) > 0;
    // uCNC's first OPT token is a kinematics code + axis count, e.g. "C3" or
    // "XY4" (KINEMATIC_TYPE_STR + AXIS_COUNT) - only meaningful for uCNC,
    // harmless to attempt otherwise (just won't match anything sensible).
    if AInfo.FirmwareName = 'uCNC' then
    begin
      axisStr := AValue;
      colonPos := Pos(',', axisStr);
      if colonPos > 0 then axisStr := Copy(axisStr, 1, colonPos - 1);
      AInfo.KinematicsCode := axisStr;
    end;
  end
  else if ATag = 'NEWOPT' then
    AInfo.NewOptRaw := AValue
  else if ATag = 'AXS' then
  begin
    // "n:letters", e.g. "3:XYZ" or "4:XYZA"
    colonPos := Pos(':', AValue);
    if colonPos > 0 then
    begin
      AInfo.AxisCount := StrToIntDef(Copy(AValue, 1, colonPos - 1), 0);
      letters := Copy(AValue, colonPos + 1, Length(AValue) - colonPos);
      AInfo.AxisLetters := Trim(letters);
    end;
  end
  else if ATag = 'DRIVER' then
    AInfo.DriverName := Trim(AValue)
  else if ATag = 'DRIVER VERSION' then
    AInfo.DriverVersion := Trim(AValue)
  else if ATag = 'DRIVER OPTIONS' then
    AInfo.DriverOptions := Trim(AValue)
  else if ATag = 'BOARD' then
    AInfo.BoardName := Trim(AValue)
  else
    AInfo.RawTags.Values[ATag] := AValue;
end;

end.
