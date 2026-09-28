unit uspoilboardstore;

{ TSpoilboardStore: named spoilboard-profile persistence, so a new blank
  spoilboard's parameters (work size, facing, peg-hole grid, T-tracks) can
  be saved once and reloaded next time an identical or similar blank is
  installed - same ini-per-section pattern already used by
  ufirmwaresetupstore.pas/uappconfig.pas/utoolsframe.pas elsewhere in this
  app. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, uspoilboard;

type
  TSpoilboardStore = class
  private
    FFileName: string;
  public
    constructor Create;
    procedure ListProfileNames(AResult: TStrings);
    procedure Save(const AProfileName: string; const ACfg: TSpoilboardConfig);
    function Load(const AProfileName: string; out ACfg: TSpoilboardConfig): Boolean;
    procedure Delete(const AProfileName: string);
  end;

implementation

var
  GInvFS: TFormatSettings;

constructor TSpoilboardStore.Create;
begin
  inherited Create;
  FFileName := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'spoilboardprofiles.ini';
end;

procedure TSpoilboardStore.ListProfileNames(AResult: TStrings);
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

procedure TSpoilboardStore.Save(const AProfileName: string; const ACfg: TSpoilboardConfig);
var
  ini: TIniFile;
  i: Integer;
  tracksStr, orientStr: string;
  t: TTTrackDef;
begin
  ForceDirectories(ExtractFileDir(FFileName));
  ini := TIniFile.Create(FFileName);
  try
    ini.EraseSection(AProfileName); // start clean in case a prior save had more tracks

    ini.WriteFloat(AProfileName, 'workwidthx', ACfg.WorkWidthX);
    ini.WriteFloat(AProfileName, 'workheighty', ACfg.WorkHeightY);
    ini.WriteFloat(AProfileName, 'safez', ACfg.SafeZ);

    ini.WriteBool(AProfileName, 'facingenabled', ACfg.FacingEnabled);
    ini.WriteFloat(AProfileName, 'facingtooldiameter', ACfg.FacingToolDiameter);
    ini.WriteFloat(AProfileName, 'facingstepoverpercent', ACfg.FacingStepoverPercent);
    ini.WriteFloat(AProfileName, 'facingdepthperpass', ACfg.FacingDepthPerPass);
    ini.WriteFloat(AProfileName, 'facingtotaldepth', ACfg.FacingTotalDepth);
    ini.WriteFloat(AProfileName, 'facingfeedrate', ACfg.FacingFeedRate);
    ini.WriteFloat(AProfileName, 'facingplungerate', ACfg.FacingPlungeRate);
    ini.WriteInteger(AProfileName, 'facingspindlerpm', ACfg.FacingSpindleRPM);
    ini.WriteBool(AProfileName, 'facingrowsalongx', ACfg.FacingRowsAlongX);

    ini.WriteBool(AProfileName, 'holesenabled', ACfg.HolesEnabled);
    ini.WriteFloat(AProfileName, 'holediameter', ACfg.HoleDiameter);
    ini.WriteFloat(AProfileName, 'holemarginx', ACfg.HoleMarginX);
    ini.WriteFloat(AProfileName, 'holemarginy', ACfg.HoleMarginY);
    ini.WriteFloat(AProfileName, 'holespacingx', ACfg.HoleSpacingX);
    ini.WriteFloat(AProfileName, 'holespacingy', ACfg.HoleSpacingY);
    ini.WriteBool(AProfileName, 'holestaggered', ACfg.HoleStaggered);
    ini.WriteFloat(AProfileName, 'holedrilldepth', ACfg.HoleDrillDepth);
    ini.WriteFloat(AProfileName, 'holepeckdepth', ACfg.HolePeckDepth);
    ini.WriteFloat(AProfileName, 'holeplungerate', ACfg.HolePlungeRate);

    ini.WriteFloat(AProfileName, 'tracktooldiameter', ACfg.TrackToolDiameter);
    ini.WriteFloat(AProfileName, 'trackstepoverpercent', ACfg.TrackStepoverPercent);
    ini.WriteFloat(AProfileName, 'trackfeedrate', ACfg.TrackFeedRate);
    ini.WriteFloat(AProfileName, 'trackplungerate', ACfg.TrackPlungeRate);

    tracksStr := '';
    for i := 0 to High(ACfg.Tracks) do
    begin
      t := ACfg.Tracks[i];
      if t.Orientation = toHorizontal then orientStr := 'h' else orientStr := 'v';
      if tracksStr <> '' then tracksStr := tracksStr + ';';
      tracksStr := tracksStr + Format('%s:%g:%g:%g:%g:%g',
        [orientStr, t.Position, t.Width, t.Depth, t.StartMargin, t.EndMargin], GInvFS);
    end;
    ini.WriteString(AProfileName, 'tracks', tracksStr);
  finally
    ini.Free;
  end;
end;

function TSpoilboardStore.Load(const AProfileName: string; out ACfg: TSpoilboardConfig): Boolean;
var
  ini: TIniFile;
  tracksStr: string;
  entries, fields: TStringArray;
  i, n: Integer;
begin
  Result := False;
  ACfg := DefaultSpoilboardConfig;
  if not FileExists(FFileName) then Exit;

  ini := TIniFile.Create(FFileName);
  try
    if not ini.SectionExists(AProfileName) then Exit;

    ACfg.WorkWidthX := ini.ReadFloat(AProfileName, 'workwidthx', ACfg.WorkWidthX);
    ACfg.WorkHeightY := ini.ReadFloat(AProfileName, 'workheighty', ACfg.WorkHeightY);
    ACfg.SafeZ := ini.ReadFloat(AProfileName, 'safez', ACfg.SafeZ);

    ACfg.FacingEnabled := ini.ReadBool(AProfileName, 'facingenabled', ACfg.FacingEnabled);
    ACfg.FacingToolDiameter := ini.ReadFloat(AProfileName, 'facingtooldiameter', ACfg.FacingToolDiameter);
    ACfg.FacingStepoverPercent := ini.ReadFloat(AProfileName, 'facingstepoverpercent', ACfg.FacingStepoverPercent);
    ACfg.FacingDepthPerPass := ini.ReadFloat(AProfileName, 'facingdepthperpass', ACfg.FacingDepthPerPass);
    ACfg.FacingTotalDepth := ini.ReadFloat(AProfileName, 'facingtotaldepth', ACfg.FacingTotalDepth);
    ACfg.FacingFeedRate := ini.ReadFloat(AProfileName, 'facingfeedrate', ACfg.FacingFeedRate);
    ACfg.FacingPlungeRate := ini.ReadFloat(AProfileName, 'facingplungerate', ACfg.FacingPlungeRate);
    ACfg.FacingSpindleRPM := ini.ReadInteger(AProfileName, 'facingspindlerpm', ACfg.FacingSpindleRPM);
    ACfg.FacingRowsAlongX := ini.ReadBool(AProfileName, 'facingrowsalongx', ACfg.FacingRowsAlongX);

    ACfg.HolesEnabled := ini.ReadBool(AProfileName, 'holesenabled', ACfg.HolesEnabled);
    ACfg.HoleDiameter := ini.ReadFloat(AProfileName, 'holediameter', ACfg.HoleDiameter);
    ACfg.HoleMarginX := ini.ReadFloat(AProfileName, 'holemarginx', ACfg.HoleMarginX);
    ACfg.HoleMarginY := ini.ReadFloat(AProfileName, 'holemarginy', ACfg.HoleMarginY);
    ACfg.HoleSpacingX := ini.ReadFloat(AProfileName, 'holespacingx', ACfg.HoleSpacingX);
    ACfg.HoleSpacingY := ini.ReadFloat(AProfileName, 'holespacingy', ACfg.HoleSpacingY);
    ACfg.HoleStaggered := ini.ReadBool(AProfileName, 'holestaggered', ACfg.HoleStaggered);
    ACfg.HoleDrillDepth := ini.ReadFloat(AProfileName, 'holedrilldepth', ACfg.HoleDrillDepth);
    ACfg.HolePeckDepth := ini.ReadFloat(AProfileName, 'holepeckdepth', ACfg.HolePeckDepth);
    ACfg.HolePlungeRate := ini.ReadFloat(AProfileName, 'holeplungerate', ACfg.HolePlungeRate);

    ACfg.TrackToolDiameter := ini.ReadFloat(AProfileName, 'tracktooldiameter', ACfg.TrackToolDiameter);
    ACfg.TrackStepoverPercent := ini.ReadFloat(AProfileName, 'trackstepoverpercent', ACfg.TrackStepoverPercent);
    ACfg.TrackFeedRate := ini.ReadFloat(AProfileName, 'trackfeedrate', ACfg.TrackFeedRate);
    ACfg.TrackPlungeRate := ini.ReadFloat(AProfileName, 'trackplungerate', ACfg.TrackPlungeRate);

    tracksStr := ini.ReadString(AProfileName, 'tracks', '');
    SetLength(ACfg.Tracks, 0);
    if tracksStr <> '' then
    begin
      entries := tracksStr.Split(';');
      n := 0;
      for i := 0 to High(entries) do
      begin
        if entries[i] = '' then Continue;
        fields := entries[i].Split(':');
        if Length(fields) < 6 then Continue;
        SetLength(ACfg.Tracks, n + 1);
        if fields[0] = 'h' then
          ACfg.Tracks[n].Orientation := toHorizontal
        else
          ACfg.Tracks[n].Orientation := toVertical;
        ACfg.Tracks[n].Position := StrToFloatDef(fields[1], 0, GInvFS);
        ACfg.Tracks[n].Width := StrToFloatDef(fields[2], 0, GInvFS);
        ACfg.Tracks[n].Depth := StrToFloatDef(fields[3], 0, GInvFS);
        ACfg.Tracks[n].StartMargin := StrToFloatDef(fields[4], 0, GInvFS);
        ACfg.Tracks[n].EndMargin := StrToFloatDef(fields[5], 0, GInvFS);
        Inc(n);
      end;
    end;

    Result := True;
  finally
    ini.Free;
  end;
end;

procedure TSpoilboardStore.Delete(const AProfileName: string);
var
  ini: TIniFile;
begin
  if not FileExists(FFileName) then Exit;
  ini := TIniFile.Create(FFileName);
  try
    ini.EraseSection(AProfileName);
  finally
    ini.Free;
  end;
end;

initialization
  GInvFS := DefaultFormatSettings;
  GInvFS.DecimalSeparator := '.';

end.
