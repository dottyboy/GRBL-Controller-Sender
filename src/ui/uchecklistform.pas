unit uchecklistform;

{ TChecklistForm: pre-flight checklist dialog (plan Phase 25, concept from
  Candle's real `frmchecklist.cpp/.ui`) - shown right before a job starts,
  alongside (not replacing) the existing Phase 6 safety countdown. Fixed-
  position modal + a TCheckListBox (a simple standard control, not a
  TStringGrid - deliberately, this codebase already found a real
  TStringGrid-in-a-fresh-modal crash in Phase 14, so grid-based editors
  live in permanent tabs now; this stays a modal since a checklist
  interrupting the Start flow is genuinely a "block until confirmed"
  dialog, not a browse-anytime data table). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, CheckLst,
  uchecklist, ui18n, ui18ncontrols;

type

  { TChecklistForm }

  TChecklistForm = class(TForm)
    BtnAddItem: TButton;
    BtnDeleteItem: TButton;
    BtnProceed: TButton;
    BtnCancel: TButton;
    CheckListBox1: TCheckListBox;
    procedure BtnAddItemClick(Sender: TObject);
    procedure BtnDeleteItemClick(Sender: TObject);
    procedure CheckListBox1ClickCheck(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    FChecklist: TChecklist;
    procedure RefreshList;
    procedure UpdateProceedEnabled;
  public
    // Shows the checklist modally. Returns True if the user proceeded
    // (every item checked, "Proceed" clicked) or if the checklist is
    // simply empty (nothing to confirm - never blocks Start with zero
    // items), False if cancelled.
    class function Execute(AChecklist: TChecklist): Boolean;
  end;

implementation

{$R *.frm}

{ TChecklistForm }

procedure TChecklistForm.FormCreate(Sender: TObject);
begin
  TranslateControls(Self);
end;

procedure TChecklistForm.RefreshList;
var
  i: Integer;
  it: TChecklistItem;
begin
  CheckListBox1.Items.BeginUpdate;
  try
    CheckListBox1.Items.Clear;
    for i := 0 to FChecklist.Count - 1 do
    begin
      it := FChecklist.Item(i);
      CheckListBox1.Items.Add(it.Name);
      CheckListBox1.Checked[i] := it.Checked;
    end;
  finally
    CheckListBox1.Items.EndUpdate;
  end;
  UpdateProceedEnabled;
end;

procedure TChecklistForm.UpdateProceedEnabled;
begin
  BtnProceed.Enabled := (FChecklist.Count = 0) or FChecklist.AllChecked;
end;

procedure TChecklistForm.CheckListBox1ClickCheck(Sender: TObject);
var
  i: Integer;
begin
  for i := 0 to CheckListBox1.Items.Count - 1 do
    FChecklist.SetItem(i, FChecklist.Item(i).Name, CheckListBox1.Checked[i]);
  UpdateProceedEnabled;
end;

procedure TChecklistForm.BtnAddItemClick(Sender: TObject);
begin
  FChecklist.AddItem(T('New item') + ' ' + IntToStr(FChecklist.Count + 1));
  RefreshList;
end;

procedure TChecklistForm.BtnDeleteItemClick(Sender: TObject);
begin
  if CheckListBox1.ItemIndex < 0 then Exit;
  FChecklist.DeleteItem(CheckListBox1.ItemIndex);
  RefreshList;
end;

class function TChecklistForm.Execute(AChecklist: TChecklist): Boolean;
var
  frm: TChecklistForm;
begin
  if AChecklist.Count = 0 then
  begin
    Result := True; // nothing to confirm - never blocks Start with an empty list
    Exit;
  end;

  frm := TChecklistForm.Create(Application);
  try
    frm.FChecklist := AChecklist;
    frm.RefreshList;
    Result := frm.ShowModal = mrOK;
  finally
    frm.Free;
  end;
  AChecklist.Save; // item NAMES only (any add/delete done in the dialog) - see uchecklist.pas's own note on why Checked itself isn't persisted
end;

end.
