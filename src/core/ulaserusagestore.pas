unit ulaserusagestore;

{ TLaserUsageStore: flat ini-backed persistence for the laser usage/
  lifetime counters (plan Phase 20) - one section per counter, mirrors
  umaterialpresetstore.pas's own pattern exactly (LoadAll/SaveAll,
  index-numbered sections, blank-name rows skipped on save). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, ulaserusage;

const
  META_SECTION = '__meta__'; // reserved section name, excluded from LoadAll's counter enumeration

type
  TLaserUsageStore = class
  private
    FFileName: string;
  public
    constructor Create(const AFileName: string);
    function LoadAll: TLaserUsageCounterArray;
    procedure SaveAll(const ACounters: TLaserUsageCounterArray);
    // The GUID of whichever counter is currently "active" (live-tracked
    // via TSender.LaserUsage) - kept in the same ini file as a small
    // reserved section, so this store stays the one self-contained place
    // Phase 20's persistence lives, with no changes needed to the
    // unrelated uappconfig.pas.
    function LoadActiveGuid: string;
    procedure SaveActiveGuid(const AGuid: string);
  end;

implementation

constructor TLaserUsageStore.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
end;

function TLaserUsageStore.LoadAll: TLaserUsageCounterArray;
var
  ini: TIniFile;
  sections: TStringList;
  i, c, k: Integer;
  sect: string;
begin
  SetLength(Result, 0);
  if not FileExists(FFileName) then Exit;

  ini := TIniFile.Create(FFileName);
  sections := TStringList.Create;
  try
    ini.ReadSections(sections);
    SetLength(Result, sections.Count);
    c := 0;
    for i := 0 to sections.Count - 1 do
    begin
      sect := sections[i];
      if sect = META_SECTION then Continue;
      FillChar(Result[c], SizeOf(Result[c]), 0);
      Result[c].Guid := ini.ReadString(sect, 'guid', sect);
      Result[c].Name := ini.ReadString(sect, 'name', sect);
      Result[c].Brand := ini.ReadString(sect, 'brand', '');
      Result[c].Model := ini.ReadString(sect, 'model', '');
      Result[c].HasOpticalPower := ini.ReadBool(sect, 'hasopticalpower', False);
      Result[c].OpticalPower := ini.ReadFloat(sect, 'opticalpower', 0);
      Result[c].HasPurchaseDate := ini.ReadBool(sect, 'haspurchasedate', False);
      Result[c].PurchaseDate := ini.ReadFloat(sect, 'purchasedate', 0);
      Result[c].HasMonitoringDate := ini.ReadBool(sect, 'hasmonitoringdate', False);
      Result[c].MonitoringDate := ini.ReadFloat(sect, 'monitoringdate', 0);
      Result[c].HasDeathDate := ini.ReadBool(sect, 'hasdeathdate', False);
      Result[c].DeathDate := ini.ReadFloat(sect, 'deathdate', 0);
      Result[c].HasLastUsage := ini.ReadBool(sect, 'haslastusage', False);
      Result[c].LastUsage := ini.ReadFloat(sect, 'lastusage', 0);
      Result[c].TimeInRunSeconds := ini.ReadFloat(sect, 'timeinrun', 0);
      Result[c].TimeUsageNormalizedPowerSeconds := ini.ReadFloat(sect, 'timeusagenormalizedpower', 0);
      Result[c].TimeUsageNonZeroSeconds := ini.ReadFloat(sect, 'timeusagenonzero', 0);
      for k := 0 to 9 do
        Result[c].TimeClasses[k] := ini.ReadFloat(sect, 'timeclass' + IntToStr(k), 0);
      Inc(c);
    end;
    SetLength(Result, c);
  finally
    sections.Free;
    ini.Free;
  end;
end;

procedure TLaserUsageStore.SaveAll(const ACounters: TLaserUsageCounterArray);
var
  ini: TIniFile;
  i, c: Integer;
  section: string;
begin
  if FileExists(FFileName) then DeleteFile(FFileName);
  ForceDirectories(ExtractFileDir(FFileName));

  ini := TIniFile.Create(FFileName);
  try
    for i := 0 to High(ACounters) do
    begin
      if Trim(ACounters[i].Name) = '' then Continue;
      section := 'laser' + IntToStr(i);
      ini.WriteString(section, 'guid', ACounters[i].Guid);
      ini.WriteString(section, 'name', ACounters[i].Name);
      ini.WriteString(section, 'brand', ACounters[i].Brand);
      ini.WriteString(section, 'model', ACounters[i].Model);
      ini.WriteBool(section, 'hasopticalpower', ACounters[i].HasOpticalPower);
      ini.WriteFloat(section, 'opticalpower', ACounters[i].OpticalPower);
      ini.WriteBool(section, 'haspurchasedate', ACounters[i].HasPurchaseDate);
      ini.WriteFloat(section, 'purchasedate', ACounters[i].PurchaseDate);
      ini.WriteBool(section, 'hasmonitoringdate', ACounters[i].HasMonitoringDate);
      ini.WriteFloat(section, 'monitoringdate', ACounters[i].MonitoringDate);
      ini.WriteBool(section, 'hasdeathdate', ACounters[i].HasDeathDate);
      ini.WriteFloat(section, 'deathdate', ACounters[i].DeathDate);
      ini.WriteBool(section, 'haslastusage', ACounters[i].HasLastUsage);
      ini.WriteFloat(section, 'lastusage', ACounters[i].LastUsage);
      ini.WriteFloat(section, 'timeinrun', ACounters[i].TimeInRunSeconds);
      ini.WriteFloat(section, 'timeusagenormalizedpower', ACounters[i].TimeUsageNormalizedPowerSeconds);
      ini.WriteFloat(section, 'timeusagenonzero', ACounters[i].TimeUsageNonZeroSeconds);
      for c := 0 to 9 do
        ini.WriteFloat(section, 'timeclass' + IntToStr(c), ACounters[i].TimeClasses[c]);
    end;
  finally
    ini.Free;
  end;
end;

function TLaserUsageStore.LoadActiveGuid: string;
var
  ini: TIniFile;
begin
  Result := '';
  if not FileExists(FFileName) then Exit;
  ini := TIniFile.Create(FFileName);
  try
    Result := ini.ReadString(META_SECTION, 'activeguid', '');
  finally
    ini.Free;
  end;
end;

// NOTE: SaveAll deletes and fully rewrites FFileName (matches this
// project's own established store-unit convention, e.g.
// umaterialpresetstore.pas) - so SaveActiveGuid must always be called
// AFTER SaveAll, never before, or the active-guid marker would be wiped
// out by the next SaveAll. umain.pas's own shutdown sequence does this.
procedure TLaserUsageStore.SaveActiveGuid(const AGuid: string);
var
  ini: TIniFile;
begin
  ForceDirectories(ExtractFileDir(FFileName));
  ini := TIniFile.Create(FFileName);
  try
    ini.WriteString(META_SECTION, 'activeguid', AGuid);
  finally
    ini.Free;
  end;
end;

end.
