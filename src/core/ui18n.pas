unit ui18n;

{ ui18n: multilingual UI (English / Croatian / German) without a gettext/.po
  toolchain - a translation table keyed by the ENGLISH text (as already
  authored in every .frm and in every `.Caption := '...'`/status-message/
  error-message call site), looked up against whichever of the three
  columns the text currently is (so repeated language switches never get
  "stuck").

  This unit is deliberately LCL-free (only Classes/SysUtils/IniFiles) so
  core, non-GUI units (uspoilboard.pas and friends) can call T() on their
  own error/status strings without dragging in a widgetset dependency and
  losing their plain-fpc standalone-testability. The recursive
  form/frame-walking part (TranslateControls/TranslateMenu) lives in the
  separate ui18ncontrols.pas, which does need Controls/Menus.

  Usage in a core unit:
    uses ui18n;
    raise EGenerateError.Create(T('Work area width/height must be positive.'));

  Usage in a UI unit (see ui18ncontrols.pas for the bulk .frm-caption pass):
    uses ui18n, ui18ncontrols;
    LblStatus.Caption := T('Not connected'); }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles;

type
  TAppLanguage = (langEN, langHR, langDE);

{ T: translates AText (an English key, exactly as it appears as the first
  column of ui18n_data.inc) to the current language. Returns AText itself,
  unchanged, if it isn't in the table - so calling T() on something that
  was never translated is always safe, never blank. }
function T(const AText: string): string;

{ Exposed so ui18ncontrols.pas's recursive walk can look a control's
  current Caption up against any of the three columns without duplicating
  the table. }
function FindRow(const AText: string): Integer;
function ColumnOf(ALang: TAppLanguage): Integer;
function RowText(ARow, AColumn: Integer): string;
function RowCount: Integer;

function CurrentLanguage: TAppLanguage;
procedure SetLanguage(ALang: TAppLanguage);
function LanguageDisplayName(ALang: TAppLanguage): string;

{ Persisted like UTheme's theme.ini - one setting, ~/.config/<AppName>/language.ini }
function LoadLanguageSetting(const AppName: string = ''): TAppLanguage;
procedure SaveLanguageSetting(ALang: TAppLanguage; const AppName: string = '');

implementation

{$I ui18n_data.inc}

var
  GCurrentLanguage: TAppLanguage = langEN;

function ColumnOf(ALang: TAppLanguage): Integer;
begin
  case ALang of
    langEN: Result := 0;
    langHR: Result := 1;
    langDE: Result := 2;
  else
    Result := 0;
  end;
end;

function FindRow(const AText: string): Integer;
var
  i, c: Integer;
begin
  for i := 0 to High(Catalog) do
    for c := 0 to 2 do
      if Catalog[i][c] = AText then
        Exit(i);
  Result := -1;
end;

function RowText(ARow, AColumn: Integer): string;
begin
  Result := Catalog[ARow][AColumn];
end;

function RowCount: Integer;
begin
  Result := Length(Catalog);
end;

function T(const AText: string): string;
var
  row: Integer;
begin
  row := FindRow(AText);
  if row >= 0 then
    Result := Catalog[row][ColumnOf(GCurrentLanguage)]
  else
    Result := AText;
end;

function CurrentLanguage: TAppLanguage;
begin
  Result := GCurrentLanguage;
end;

procedure SetLanguage(ALang: TAppLanguage);
begin
  GCurrentLanguage := ALang;
end;

function LanguageDisplayName(ALang: TAppLanguage): string;
begin
  case ALang of
    langEN: Result := 'English';
    langHR: Result := 'Hrvatski';
    langDE: Result := 'Deutsch';
  else
    Result := '?';
  end;
end;

function ConfigFile(const AppName: string): string;
var
  Name, Dir: string;
begin
  Name := AppName;
  if Name = '' then
    Name := ApplicationName;
  Dir := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) + '.config/' + Name;
  ForceDirectories(Dir);
  Result := IncludeTrailingPathDelimiter(Dir) + 'language.ini';
end;

function LoadLanguageSetting(const AppName: string): TAppLanguage;
var
  Ini: TIniFile;
  V: string;
begin
  Result := langEN;
  try
    Ini := TIniFile.Create(ConfigFile(AppName));
    try
      V := Ini.ReadString('Language', 'Code', 'en');
      if SameText(V, 'hr') then Result := langHR
      else if SameText(V, 'de') then Result := langDE;
    finally
      Ini.Free;
    end;
  except
    // config not readable -> stays langEN
  end;
end;

procedure SaveLanguageSetting(ALang: TAppLanguage; const AppName: string);
var
  Ini: TIniFile;
  Code: string;
begin
  case ALang of
    langHR: Code := 'hr';
    langDE: Code := 'de';
  else
    Code := 'en';
  end;
  try
    Ini := TIniFile.Create(ConfigFile(AppName));
    try
      Ini.WriteString('Language', 'Code', Code);
    finally
      Ini.Free;
    end;
  except
    // ignore save failures, matches UTheme's SaveThemeSetting
  end;
end;

end.
