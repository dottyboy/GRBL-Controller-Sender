unit uappconfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, ucncstate;

type
  { TAppConfig persists app-level + machine settings between sessions,
    mirroring the relevant parts of bCNC.ini's [Connection] and [CNC]
    sections (Utils.py loadConfig/saveConfig equivalent). Stored under the
    user's standard Lazarus/FPC config dir, not inside the project tree. }
  TAppConfig = class
  private
    FFileName: string;
  public
    // Persisted connection defaults (bCNC.ini [Connection])
    LastPort: string;
    LastBaud: Integer;
    LastControllerIndex: Integer; // matches TConnectFrame's CboController

    // Recently opened g-code files (most recent first)
    RecentFiles: TStringList;

    // Laser module (plan Phase 6): safety countdown shown before a laser
    // job starts. SkipSafetyCountdown persists the "don't show again"
    // choice - the countdown dialog itself doesn't know about ini files,
    // the caller (future Phase 9 Start button) reads/writes these via
    // this class, same as every other persisted setting here.
    SafetyCountdownSeconds: Integer;
    SkipSafetyCountdown: Boolean;

    constructor Create;
    destructor Destroy; override;

    procedure Load(AState: TCNCState);
    procedure Save(AState: TCNCState);
    procedure AddRecentFile(const AFileName: string);
  end;

implementation

const
  MAX_RECENT_FILES = 10;

constructor TAppConfig.Create;
begin
  inherited Create;
  RecentFiles := TStringList.Create;
  FFileName := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'grblsender.ini';
  LastBaud := 115200;
  LastControllerIndex := 0;
  SafetyCountdownSeconds := 5;
  SkipSafetyCountdown := False;
end;

destructor TAppConfig.Destroy;
begin
  RecentFiles.Free;
  inherited Destroy;
end;

procedure TAppConfig.Load(AState: TCNCState);
var
  ini: TIniFile;
  i: Integer;
  fn: string;
begin
  AState.ResetConfigDefaults;
  if not FileExists(FFileName) then Exit;

  ini := TIniFile.Create(FFileName);
  try
    LastPort := ini.ReadString('Connection', 'port', '');
    LastBaud := ini.ReadInteger('Connection', 'baud', 115200);
    LastControllerIndex := ini.ReadInteger('Connection', 'controllerindex', 0);

    SafetyCountdownSeconds := ini.ReadInteger('Laser', 'safetycountdownseconds', SafetyCountdownSeconds);
    SkipSafetyCountdown := ini.ReadBool('Laser', 'skipsafetycountdown', SkipSafetyCountdown);

    with AState do
    begin
      Safe := ini.ReadFloat('CNC', 'safe', Safe);
      Diameter := ini.ReadFloat('CNC', 'diameter', Diameter);
      CutFeed := ini.ReadFloat('CNC', 'cutfeed', CutFeed);
      CutFeedZ := ini.ReadFloat('CNC', 'cutfeedz', CutFeedZ);
      TravelX := ini.ReadFloat('CNC', 'travel_x', TravelX);
      TravelY := ini.ReadFloat('CNC', 'travel_y', TravelY);
      TravelZ := ini.ReadFloat('CNC', 'travel_z', TravelZ);
      FeedMaxX := ini.ReadFloat('CNC', 'feedmax_x', FeedMaxX);
      FeedMaxY := ini.ReadFloat('CNC', 'feedmax_y', FeedMaxY);
      FeedMaxZ := ini.ReadFloat('CNC', 'feedmax_z', FeedMaxZ);
      AccelX := ini.ReadFloat('CNC', 'acceleration_x', AccelX);
      AccelY := ini.ReadFloat('CNC', 'acceleration_y', AccelY);
      AccelZ := ini.ReadFloat('CNC', 'acceleration_z', AccelZ);
      StartupGCode := ini.ReadString('CNC', 'startup', StartupGCode);
      GangedAxes := ini.ReadString('CNC', 'gangedaxes', GangedAxes);
    end;

    RecentFiles.Clear;
    for i := 0 to MAX_RECENT_FILES - 1 do
    begin
      fn := ini.ReadString('RecentFiles', 'file' + IntToStr(i), '');
      if fn <> '' then RecentFiles.Add(fn);
    end;
  finally
    ini.Free;
  end;
end;

procedure TAppConfig.Save(AState: TCNCState);
var
  ini: TIniFile;
  i: Integer;
begin
  ForceDirectories(ExtractFileDir(FFileName));
  ini := TIniFile.Create(FFileName);
  try
    ini.WriteString('Connection', 'port', LastPort);
    ini.WriteInteger('Connection', 'baud', LastBaud);
    ini.WriteInteger('Connection', 'controllerindex', LastControllerIndex);

    ini.WriteInteger('Laser', 'safetycountdownseconds', SafetyCountdownSeconds);
    ini.WriteBool('Laser', 'skipsafetycountdown', SkipSafetyCountdown);

    with AState do
    begin
      ini.WriteFloat('CNC', 'safe', Safe);
      ini.WriteFloat('CNC', 'diameter', Diameter);
      ini.WriteFloat('CNC', 'cutfeed', CutFeed);
      ini.WriteFloat('CNC', 'cutfeedz', CutFeedZ);
      ini.WriteFloat('CNC', 'travel_x', TravelX);
      ini.WriteFloat('CNC', 'travel_y', TravelY);
      ini.WriteFloat('CNC', 'travel_z', TravelZ);
      ini.WriteFloat('CNC', 'feedmax_x', FeedMaxX);
      ini.WriteFloat('CNC', 'feedmax_y', FeedMaxY);
      ini.WriteFloat('CNC', 'feedmax_z', FeedMaxZ);
      ini.WriteFloat('CNC', 'acceleration_x', AccelX);
      ini.WriteFloat('CNC', 'acceleration_y', AccelY);
      ini.WriteFloat('CNC', 'acceleration_z', AccelZ);
      ini.WriteString('CNC', 'startup', StartupGCode);
      ini.WriteString('CNC', 'gangedaxes', GangedAxes);
    end;

    ini.EraseSection('RecentFiles');
    for i := 0 to RecentFiles.Count - 1 do
      ini.WriteString('RecentFiles', 'file' + IntToStr(i), RecentFiles[i]);
  finally
    ini.Free;
  end;
end;

procedure TAppConfig.AddRecentFile(const AFileName: string);
var
  idx: Integer;
begin
  idx := RecentFiles.IndexOf(AFileName);
  if idx = 0 then Exit; // already most-recent
  if idx > 0 then RecentFiles.Delete(idx);
  RecentFiles.Insert(0, AFileName);
  while RecentFiles.Count > MAX_RECENT_FILES do
    RecentFiles.Delete(RecentFiles.Count - 1);
end;

end.
