unit ui18ncontrols;

{ ui18ncontrols: the LCL-dependent half of ui18n.pas - recursively walks a
  form/frame's controls (like UTheme.ApplyTheme does for colors) and
  re-sets each one's Caption via ui18n.T(), plus the same pass for menus
  (TMenuItem/TMainMenu aren't part of the Controls[] tree, so they need
  their own walk).

  Usage: call once, e.g. at the end of TForm1.FormCreate after every frame
  exists, and again after SetLanguage() on a language-menu click:
    TranslateControls(Self);
    TranslateMenu(MainMenu1.Items); }

{$mode objfpc}{$H+}

interface

uses
  Controls, Menus, ui18n;

procedure TranslateControls(AControl: TWinControl);
procedure TranslateMenu(AItems: TMenuItem);

implementation

procedure TranslateOneControl(AControl: TControl);
var
  row: Integer;
begin
  // TControl.Caption exists on the base class (used or not depending on
  // the concrete control - e.g. a TEdit's is normally empty and simply
  // won't match anything), so this is safe to call generically for every
  // child, same reasoning UTheme.ApplyTheme already relies on.
  row := FindRow(AControl.Caption);
  if row >= 0 then
    AControl.Caption := RowText(row, ColumnOf(CurrentLanguage));
end;

procedure TranslateControls(AControl: TWinControl);
var
  i: Integer;
  child: TControl;
begin
  TranslateOneControl(AControl);
  for i := 0 to AControl.ControlCount - 1 do
  begin
    child := AControl.Controls[i];
    TranslateOneControl(child);
    if child is TWinControl then
      TranslateControls(TWinControl(child));
  end;
end;

procedure TranslateMenu(AItems: TMenuItem);
var
  i, row: Integer;
  item: TMenuItem;
begin
  if AItems = nil then Exit;
  for i := 0 to AItems.Count - 1 do
  begin
    item := AItems[i];
    row := FindRow(item.Caption);
    if row >= 0 then
      item.Caption := RowText(row, ColumnOf(CurrentLanguage));
    if item.Count > 0 then
      TranslateMenu(item);
  end;
end;

end.
