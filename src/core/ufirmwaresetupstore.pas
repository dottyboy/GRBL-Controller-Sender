unit ufirmwaresetupstore;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, ufirmwareboards, ufirmwaremodules, ufirmwarebuildconfig;

type
  // What actually gets persisted for one named setup - deliberately NOT a
  // live TBoardEnv (whose MapFilePath/ConfigFilePath are derived data that
  // should be recomputed by re-scanning, not trusted stale from a previous
  // session where References/ may have changed). The caller (UI layer,
  // which already owns board-scanning) re-resolves Ecosystem/Family/EnvName
  // back to a fresh TBoardEnv after Load.
  TSavedSetup = record
    Ecosystem: TFirmwareEcosystem;
    Family: string;
    EnvName: string;
    Axes: array of TDualDriveAxis;
    Modules: array of TFirmwareModuleId;
    EncPulsePin: Integer;
    EncDirPin: Integer;
  end;

  { TFirmwareSetupStore: named Firmware Builder setup persistence (Phase:
    Firmware Builder) - "something like settings.ini to save settings of
    software", one ini section per setup, same pattern already used by
    uappconfig.pas/utoolsframe.pas elsewhere in this app. }
  TFirmwareSetupStore = class
  private
    FFileName: string;
  public
    constructor Create;
    procedure ListSetupNames(AResult: TStrings);
    procedure Save(const AName: string; ASetup: TFirmwareSetup);
    function Load(const AName: string; out ASaved: TSavedSetup): Boolean;
    procedure Delete(const AName: string);
  end;

implementation

constructor TFirmwareSetupStore.Create;
begin
  inherited Create;
  FFileName := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'firmwaresetups.ini';
end;

procedure TFirmwareSetupStore.ListSetupNames(AResult: TStrings);
var
  ini: TIniFile;
begin
  AResult.Clear;
  if not FileExists(FFileName) then Exit;
  ini := TIniFile.Create(FFileName);
  try
    ini.ReadSections(AResult);
  finally
    ini.Free;
  end;
end;

procedure TFirmwareSetupStore.Save(const AName: string; ASetup: TFirmwareSetup);
var
  ini: TIniFile;
  i: Integer;
  axesStr, modulesStr: string;
  a: TDualDriveAxis;
begin
  if not ASetup.HasBoardEnv then Exit;
  ForceDirectories(ExtractFileDir(FFileName));
  ini := TIniFile.Create(FFileName);
  try
    ini.EraseSection(AName); // start clean in case a prior save had more axes
    if ASetup.BoardEnv.Ecosystem = fwUCNC then
      ini.WriteString(AName, 'ecosystem', 'ucnc')
    else
      ini.WriteString(AName, 'ecosystem', 'grblhal');
    ini.WriteString(AName, 'family', ASetup.BoardEnv.Family);
    ini.WriteString(AName, 'env', ASetup.BoardEnv.EnvName);

    axesStr := '';
    for i := 0 to ASetup.AxisCount - 1 do
    begin
      a := ASetup.AxisAt(i);
      if axesStr <> '' then axesStr := axesStr + ';';
      axesStr := axesStr + a.AxisLetter + ':' + a.MotorSlot + ':' + a.LimitSlot;
    end;
    ini.WriteString(AName, 'axes', axesStr);

    modulesStr := '';
    for i := 0 to ASetup.ModuleCount - 1 do
    begin
      if modulesStr <> '' then modulesStr := modulesStr + ',';
      modulesStr := modulesStr + IntToStr(Ord(ASetup.ModuleAt(i)));
    end;
    ini.WriteString(AName, 'modules', modulesStr);
    ini.WriteInteger(AName, 'encpulsepin', ASetup.EncoderPulsePin);
    ini.WriteInteger(AName, 'encdirpin', ASetup.EncoderDirPin);
  finally
    ini.Free;
  end;
end;

function TFirmwareSetupStore.Load(const AName: string; out ASaved: TSavedSetup): Boolean;
var
  ini: TIniFile;
  ecoStr, axesStr, modulesStr: string;
  entries: TStringArray;
  fields: TStringArray;
  i, n: Integer;
  modOrd: Integer;
begin
  Result := False;
  FillChar(ASaved, SizeOf(ASaved), 0);
  if not FileExists(FFileName) then Exit;

  ini := TIniFile.Create(FFileName);
  try
    if not ini.SectionExists(AName) then Exit;
    ecoStr := ini.ReadString(AName, 'ecosystem', 'ucnc');
    if ecoStr = 'grblhal' then
      ASaved.Ecosystem := fwGrblHAL
    else
      ASaved.Ecosystem := fwUCNC;
    ASaved.Family := ini.ReadString(AName, 'family', '');
    ASaved.EnvName := ini.ReadString(AName, 'env', '');

    axesStr := ini.ReadString(AName, 'axes', '');
    SetLength(ASaved.Axes, 0);
    if axesStr <> '' then
    begin
      entries := axesStr.Split(';');
      n := 0;
      for i := 0 to High(entries) do
      begin
        if entries[i] = '' then Continue;
        fields := entries[i].Split(':');
        if Length(fields) < 2 then Continue;
        SetLength(ASaved.Axes, n + 1);
        ASaved.Axes[n].AxisLetter := fields[0][1];
        ASaved.Axes[n].MotorSlot := fields[1];
        if Length(fields) > 2 then
          ASaved.Axes[n].LimitSlot := fields[2]
        else
          ASaved.Axes[n].LimitSlot := '';
        Inc(n);
      end;
    end;

    modulesStr := ini.ReadString(AName, 'modules', '');
    SetLength(ASaved.Modules, 0);
    if modulesStr <> '' then
    begin
      entries := modulesStr.Split(',');
      n := 0;
      for i := 0 to High(entries) do
      begin
        if entries[i] = '' then Continue;
        modOrd := StrToIntDef(entries[i], -1);
        if (modOrd < Ord(Low(TFirmwareModuleId))) or (modOrd > Ord(High(TFirmwareModuleId))) then Continue;
        SetLength(ASaved.Modules, n + 1);
        ASaved.Modules[n] := TFirmwareModuleId(modOrd);
        Inc(n);
      end;
    end;
    ASaved.EncPulsePin := ini.ReadInteger(AName, 'encpulsepin', 6);
    ASaved.EncDirPin := ini.ReadInteger(AName, 'encdirpin', 7);

    Result := True;
  finally
    ini.Free;
  end;
end;

procedure TFirmwareSetupStore.Delete(const AName: string);
var
  ini: TIniFile;
begin
  if not FileExists(FFileName) then Exit;
  ini := TIniFile.Create(FFileName);
  try
    ini.EraseSection(AName);
  finally
    ini.Free;
  end;
end;

end.
