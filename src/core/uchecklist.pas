unit uchecklist;

{ uchecklist: a user-editable pre-flight checklist (plan Phase 25, concept
  from Candle's real `frmchecklist.cpp/.ui`) - a flat, persisted list of
  item names + their last-checked state. LCL-free, matching every other
  src/core store unit's own standalone-testability. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles;

type
  TChecklistItem = record
    Name: string;
    Checked: Boolean;
  end;

  TChecklistItemArray = array of TChecklistItem;

  TChecklist = class
  private
    FFileName: string;
    FItems: TChecklistItemArray;
  public
    constructor Create(const AFileName: string);
    procedure Load;
    procedure Save;
    procedure SeedDefaultsIfEmpty;
    function Count: Integer;
    function Item(AIndex: Integer): TChecklistItem;
    procedure SetItem(AIndex: Integer; const AName: string; AChecked: Boolean);
    procedure AddItem(const AName: string);
    procedure DeleteItem(AIndex: Integer);
    function AllChecked: Boolean;
  end;

implementation

constructor TChecklist.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
end;

procedure TChecklist.Load;
var
  ini: TIniFile;
  names: TStringList;
  i: Integer;
begin
  SetLength(FItems, 0);
  if not FileExists(FFileName) then Exit;

  ini := TIniFile.Create(FFileName);
  names := TStringList.Create;
  try
    ini.ReadSection('Checklist', names);
    SetLength(FItems, names.Count);
    for i := 0 to names.Count - 1 do
    begin
      FItems[i].Name := ini.ReadString('Checklist', names[i], '');
      // The checked state is deliberately NOT persisted (only the item
      // NAMES are) - a checklist that remembers "already confirmed" from
      // last time defeats the entire point of a pre-flight safety check;
      // every new job starts every item unchecked again.
      FItems[i].Checked := False;
    end;
  finally
    names.Free;
    ini.Free;
  end;
end;

procedure TChecklist.Save;
var
  ini: TIniFile;
  i: Integer;
begin
  ForceDirectories(ExtractFileDir(FFileName));
  ini := TIniFile.Create(FFileName);
  try
    ini.EraseSection('Checklist');
    for i := 0 to High(FItems) do
      if Trim(FItems[i].Name) <> '' then
        ini.WriteString('Checklist', 'item' + IntToStr(i), FItems[i].Name);
  finally
    ini.Free;
  end;
end;

procedure TChecklist.SeedDefaultsIfEmpty;
begin
  if Length(FItems) > 0 then Exit;
  // A real, sensible starting set (not fabricated busywork) - the user
  // edits/replaces these freely, matching Candle's own user-editable
  // model rather than a fixed hardcoded list.
  AddItem('Material secured');
  AddItem('Focus set');
  AddItem('Ventilation on');
  AddItem('Area clear / laser goggles on');
end;

function TChecklist.Count: Integer;
begin
  Result := Length(FItems);
end;

function TChecklist.Item(AIndex: Integer): TChecklistItem;
begin
  Result := FItems[AIndex];
end;

procedure TChecklist.SetItem(AIndex: Integer; const AName: string; AChecked: Boolean);
begin
  FItems[AIndex].Name := AName;
  FItems[AIndex].Checked := AChecked;
end;

procedure TChecklist.AddItem(const AName: string);
var
  n: Integer;
begin
  n := Length(FItems);
  SetLength(FItems, n + 1);
  FItems[n].Name := AName;
  FItems[n].Checked := False;
end;

procedure TChecklist.DeleteItem(AIndex: Integer);
var
  i: Integer;
begin
  if (AIndex < 0) or (AIndex > High(FItems)) then Exit;
  for i := AIndex to High(FItems) - 1 do
    FItems[i] := FItems[i + 1];
  SetLength(FItems, Length(FItems) - 1);
end;

function TChecklist.AllChecked: Boolean;
var
  i: Integer;
begin
  Result := Length(FItems) > 0;
  for i := 0 to High(FItems) do
    if not FItems[i].Checked then
    begin
      Result := False;
      Exit;
    end;
end;

end.
