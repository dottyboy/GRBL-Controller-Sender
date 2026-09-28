unit ucustombuttonstore;

{ TCustomButtonStore: flat ini-backed persistence for saved macro buttons
  (plan Phase 14), one section per button - structurally identical to
  umaterialpresetstore.pas. A GCode snippet's embedded line breaks can't be
  written directly as an ini value (would break the file's own line
  structure), so they're encoded as '|' on save and decoded back on load -
  a deliberate, disclosed simplification: real g-code never contains a
  literal '|', so there's no realistic collision. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, ucustombutton;

type
  TCustomButtonStore = class
  private
    FFileName: string;
  public
    constructor Create(const AFileName: string);
    function LoadAll: TCustomButtonArray;
    procedure SaveAll(const AButtons: TCustomButtonArray);
  end;

implementation

const
  GCODE_LINE_SEP = '|';

constructor TCustomButtonStore.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
end;

function TCustomButtonStore.LoadAll: TCustomButtonArray;
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
      Result[i].GCode := StringReplace(ini.ReadString(sections[i], 'gcode', ''),
        GCODE_LINE_SEP, LineEnding, [rfReplaceAll]);
    end;
  finally
    sections.Free;
    ini.Free;
  end;
end;

procedure TCustomButtonStore.SaveAll(const AButtons: TCustomButtonArray);
var
  ini: TIniFile;
  i: Integer;
  section: string;
begin
  if FileExists(FFileName) then DeleteFile(FFileName);
  ForceDirectories(ExtractFileDir(FFileName));

  ini := TIniFile.Create(FFileName);
  try
    for i := 0 to High(AButtons) do
    begin
      if Trim(AButtons[i].Name) = '' then Continue;
      section := 'button' + IntToStr(i);
      ini.WriteString(section, 'name', AButtons[i].Name);
      ini.WriteString(section, 'gcode',
        StringReplace(AButtons[i].GCode, LineEnding, GCODE_LINE_SEP, [rfReplaceAll]));
    end;
  finally
    ini.Free;
  end;
end;

end.
