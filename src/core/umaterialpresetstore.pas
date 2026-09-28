unit umaterialpresetstore;

{ TMaterialPresetStore: flat ini-backed persistence for the material preset
  library (plan Phase 13) - one section per preset, mirrors
  utoolsframe.pas's inline tools.ini pattern but factored into its own
  LCL-free unit (per the plan's explicit separate-unit call), so it's
  standalone-testable like every other src/core store unit. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, umaterialpreset;

type
  TMaterialPresetStore = class
  private
    FFileName: string;
  public
    constructor Create(const AFileName: string);
    function LoadAll: TMaterialPresetArray;
    procedure SaveAll(const APresets: TMaterialPresetArray);
  end;

implementation

constructor TMaterialPresetStore.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
end;

function TMaterialPresetStore.LoadAll: TMaterialPresetArray;
var
  ini: TIniFile;
  sections: TStringList;
  i: Integer;
begin
  SetLength(Result, 0);
  if not FileExists(FFileName) then Exit;

  ini := TIniFile.Create(FFileName);
  sections := TStringList.Create;
  try
    ini.ReadSections(sections);
    SetLength(Result, sections.Count);
    for i := 0 to sections.Count - 1 do
    begin
      Result[i].Name := ini.ReadString(sections[i], 'name', sections[i]);
      Result[i].Material := ini.ReadString(sections[i], 'material', '');
      Result[i].Power := ini.ReadFloat(sections[i], 'power', 100);
      Result[i].Speed := ini.ReadFloat(sections[i], 'speed', 1000);
      Result[i].Passes := ini.ReadInteger(sections[i], 'passes', 1);
      Result[i].Notes := ini.ReadString(sections[i], 'notes', '');
    end;
  finally
    sections.Free;
    ini.Free;
  end;
end;

procedure TMaterialPresetStore.SaveAll(const APresets: TMaterialPresetArray);
var
  ini: TIniFile;
  i: Integer;
  section: string;
begin
  if FileExists(FFileName) then DeleteFile(FFileName);
  ForceDirectories(ExtractFileDir(FFileName));

  ini := TIniFile.Create(FFileName);
  try
    for i := 0 to High(APresets) do
    begin
      if Trim(APresets[i].Name) = '' then Continue;
      section := 'preset' + IntToStr(i);
      ini.WriteString(section, 'name', APresets[i].Name);
      ini.WriteString(section, 'material', APresets[i].Material);
      ini.WriteFloat(section, 'power', APresets[i].Power);
      ini.WriteFloat(section, 'speed', APresets[i].Speed);
      ini.WriteInteger(section, 'passes', APresets[i].Passes);
      ini.WriteString(section, 'notes', APresets[i].Notes);
    end;
  finally
    ini.Free;
  end;
end;

end.
