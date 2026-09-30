unit uheaderfooterpresetstore;

{ THeaderFooterPresetStore: flat ini-backed persistence for the user's OWN
  custom Header/Footer presets (plan Phase 37) - structurally identical to
  ucustombuttonstore.pas/umaterialpresetstore.pas. The built-in set
  (uheaderfooterpreset.pas) is never written here - this store only ever
  holds presets the user adds on top, satisfying "da se mogu učitat i
  neki custom ako bude potrebno" (custom ones loadable too, if needed). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, uheaderfooterpreset;

type
  THeaderFooterPresetStore = class
  private
    FFileName: string;
  public
    constructor Create(const AFileName: string);
    function LoadAll: THeaderFooterPresetArray;
    procedure SaveAll(const APresets: THeaderFooterPresetArray);
  end;

implementation

const
  LINE_SEP = '|';

constructor THeaderFooterPresetStore.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
end;

function THeaderFooterPresetStore.LoadAll: THeaderFooterPresetArray;
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
      Result[i].Header := StringReplace(ini.ReadString(sections[i], 'header', ''),
        LINE_SEP, LineEnding, [rfReplaceAll]);
      Result[i].Footer := StringReplace(ini.ReadString(sections[i], 'footer', ''),
        LINE_SEP, LineEnding, [rfReplaceAll]);
      Result[i].Kind := THFKind(ini.ReadInteger(sections[i], 'kind', Ord(hfkUniversal)));
    end;
  finally
    sections.Free;
    ini.Free;
  end;
end;

procedure THeaderFooterPresetStore.SaveAll(const APresets: THeaderFooterPresetArray);
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
      ini.WriteString(section, 'header', StringReplace(APresets[i].Header, LineEnding, LINE_SEP, [rfReplaceAll]));
      ini.WriteString(section, 'footer', StringReplace(APresets[i].Footer, LineEnding, LINE_SEP, [rfReplaceAll]));
      ini.WriteInteger(section, 'kind', Ord(APresets[i].Kind));
    end;
  finally
    ini.Free;
  end;
end;

end.
