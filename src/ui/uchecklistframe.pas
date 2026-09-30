unit uchecklistframe;

{ TChecklistFrame: pre-flight checklist (plan Phase 25, concept from
  Candle's real frmchecklist.cpp/.ui), converted from a modal dialog to
  a plain Laser-group tab in the same session that converted the Phase 6
  safety countdown - discovered to be entangled with it: ulasercontrolframe.pas's
  BtnStartClick shows this FIRST, and since the checklist is seeded with
  real default items on first run (SeedDefaultsIfEmpty), it is NOT an
  empty-list no-op for a normal install - every real "Start" click hit
  this modal's ShowModal, which crashes in this X11/Qt5 environment
  exactly like the other 5 dialogs (confirmed via a real gdb backtrace
  landing in TChecklistForm.Execute -> ShowModal, not the countdown).
  A tab sidesteps it entirely, same as the rest. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, CheckLst,
  uchecklist, ui18n, ui18ncontrols;

type
  TOnChecklistDone = procedure(Sender: TObject) of object;

  { TChecklistFrame }

  TChecklistFrame = class(TFrame)
    BtnAddItem: TButton;
    BtnCancel: TButton;
    BtnDeleteItem: TButton;
    BtnProceed: TButton;
    CheckListBox1: TCheckListBox;
    procedure BtnAddItemClick(Sender: TObject);
    procedure BtnCancelClick(Sender: TObject);
    procedure BtnDeleteItemClick(Sender: TObject);
    procedure BtnProceedClick(Sender: TObject);
    procedure CheckListBox1ClickCheck(Sender: TObject);
  private
    FChecklist: TChecklist;
    FOnProceed: TOnChecklistDone;
    FOnCancelled: TOnChecklistDone;
    procedure RefreshList;
    procedure UpdateProceedEnabled;
  public
    constructor Create(AOwner: TComponent); override;
    // Called from umain.pas's own OnChecklistRequested handler, right
    // before switching to this tab - refreshes the list from whatever
    // real TChecklist instance ulasercontrolframe.pas owns.
    procedure ShowChecklist(AChecklist: TChecklist);
    property OnProceed: TOnChecklistDone read FOnProceed write FOnProceed;
    property OnCancelled: TOnChecklistDone read FOnCancelled write FOnCancelled;
  end;

implementation

{$R *.frm}

{ TChecklistFrame }

constructor TChecklistFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  TranslateControls(Self);
end;

procedure TChecklistFrame.ShowChecklist(AChecklist: TChecklist);
begin
  FChecklist := AChecklist;
  RefreshList;
end;

procedure TChecklistFrame.RefreshList;
var
  i: Integer;
  it: TChecklistItem;
begin
  if FChecklist = nil then Exit;
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

procedure TChecklistFrame.UpdateProceedEnabled;
begin
  BtnProceed.Enabled := (FChecklist = nil) or (FChecklist.Count = 0) or FChecklist.AllChecked;
end;

procedure TChecklistFrame.CheckListBox1ClickCheck(Sender: TObject);
var
  i: Integer;
begin
  if FChecklist = nil then Exit;
  for i := 0 to CheckListBox1.Items.Count - 1 do
    FChecklist.SetItem(i, FChecklist.Item(i).Name, CheckListBox1.Checked[i]);
  UpdateProceedEnabled;
end;

procedure TChecklistFrame.BtnAddItemClick(Sender: TObject);
begin
  if FChecklist = nil then Exit;
  FChecklist.AddItem(T('New item') + ' ' + IntToStr(FChecklist.Count + 1));
  RefreshList;
end;

procedure TChecklistFrame.BtnDeleteItemClick(Sender: TObject);
begin
  if (FChecklist = nil) or (CheckListBox1.ItemIndex < 0) then Exit;
  FChecklist.DeleteItem(CheckListBox1.ItemIndex);
  RefreshList;
end;

procedure TChecklistFrame.BtnProceedClick(Sender: TObject);
begin
  if FChecklist <> nil then
    FChecklist.Save; // item NAMES only, see uchecklist.pas's own note on Checked
  if Assigned(FOnProceed) then
    FOnProceed(Self);
end;

procedure TChecklistFrame.BtnCancelClick(Sender: TObject);
begin
  if FChecklist <> nil then
    FChecklist.Save;
  if Assigned(FOnCancelled) then
    FOnCancelled(Self);
end;

end.
