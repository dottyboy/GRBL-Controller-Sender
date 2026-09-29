unit ulaserusageform;

{ TLaserUsageForm: laser module usage/lifetime viewer+editor (plan Phase 20),
  concept from LaserGRBL's real "Tools > Laser Usage" dialog. A modal using
  only plain TListBox/TEdit/TButton controls (deliberately NOT a
  TStringGrid - this codebase already found a real, 100%-reproducible
  crash pairing a grid with a freshly-created modal on this Qt5/LCL build,
  see Phase 14's own notes; grid-based editors live in permanent tabs
  here, everything else stays a safe modal).

  Only one counter is ever "active" (live-accumulating, via
  TSender.LaserUsage - ticked from usender.pas's own worker-thread loop)
  at a time - this dialog lets the user view/rename/add/delete counters
  and switch which one is active, mirroring LaserGRBL's own multi-laser-
  module concept without its full purchase/monitoring/death-date
  lifecycle bookkeeping (a disclosed, deliberate scope reduction - not
  needed for this phase's own "usage increments on a test run and
  persists" Done bar). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Dialogs,
  ulaserusage, ui18n, ui18ncontrols;

type

  { TLaserUsageForm }

  TLaserUsageForm = class(TForm)
    BtnAddNew: TButton;
    BtnApply: TButton;
    BtnClose: TButton;
    BtnDelete: TButton;
    BtnSetActive: TButton;
    EdBrand: TEdit;
    EdModel: TEdit;
    EdName: TEdit;
    EdOpticalPower: TEdit;
    LblActive: TLabel;
    LblBrand: TLabel;
    LblModel: TLabel;
    LblName: TLabel;
    LblOpticalPower: TLabel;
    LblOpticalPowerUnit: TLabel;
    ListBox1: TListBox;
    procedure BtnAddNewClick(Sender: TObject);
    procedure BtnApplyClick(Sender: TObject);
    procedure BtnDeleteClick(Sender: TObject);
    procedure BtnSetActiveClick(Sender: TObject);
    procedure FieldChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ListBox1SelectionChange(Sender: TObject; User: Boolean);
  private
    FCounters: TLaserUsageCounterArray;
    FActiveGuid: string;
    FLoadingFields: Boolean;
    procedure RefreshList;
    procedure ShowSelected;
    function SelectedIndex: Integer;
  public
    // Shows the dialog modally. ACounters/AActiveGuid are both in (the
    // real on-disk list + which one is currently live) and out (whatever
    // the user changed - added/deleted/renamed/switched active) - the
    // caller (umain.pas) persists the result and re-points
    // TSender.LaserUsage at the (possibly new) active counter.
    class procedure Execute(var ACounters: TLaserUsageCounterArray; var AActiveGuid: string);
  end;

implementation

{$R *.frm}

{ TLaserUsageForm }

function FormatCounterLine(const AC: TLaserUsageCounter; AIsActive: Boolean): string;
var
  brandModel: string;
begin
  brandModel := Trim(AC.Brand + ' ' + AC.Model);
  if brandModel <> '' then
    brandModel := ' (' + brandModel + ')';
  Result := Format('%s%s - Run: %.1fh, Power: %.1fh, Stress: %.1fh, Avg: %.0f%%',
    [AC.Name, brandModel, AC.TimeInRunSeconds / 3600, AC.TimeUsageNormalizedPowerSeconds / 3600,
     StressTimeSeconds(AC) / 3600, AveragePowerFactor(AC) * 100]);
  if AIsActive then
    Result := '* ' + Result;
end;

procedure TLaserUsageForm.FormCreate(Sender: TObject);
begin
  TranslateControls(Self);
end;

procedure TLaserUsageForm.RefreshList;
var
  i, sel: Integer;
begin
  sel := ListBox1.ItemIndex;
  ListBox1.Items.BeginUpdate;
  try
    ListBox1.Items.Clear;
    for i := 0 to High(FCounters) do
      ListBox1.Items.Add(FormatCounterLine(FCounters[i], FCounters[i].Guid = FActiveGuid));
  finally
    ListBox1.Items.EndUpdate;
  end;
  if (sel >= 0) and (sel < ListBox1.Items.Count) then
    ListBox1.ItemIndex := sel
  else if ListBox1.Items.Count > 0 then
    ListBox1.ItemIndex := 0;
  ShowSelected;
end;

function TLaserUsageForm.SelectedIndex: Integer;
begin
  Result := ListBox1.ItemIndex;
  if (Result < 0) or (Result > High(FCounters)) then Result := -1;
end;

procedure TLaserUsageForm.ShowSelected;
var
  idx: Integer;
begin
  idx := SelectedIndex;
  FLoadingFields := True;
  try
    if idx < 0 then
    begin
      EdName.Text := ''; EdBrand.Text := ''; EdModel.Text := ''; EdOpticalPower.Text := '';
      EdName.Enabled := False; EdBrand.Enabled := False; EdModel.Enabled := False; EdOpticalPower.Enabled := False;
      BtnApply.Enabled := False; BtnDelete.Enabled := False; BtnSetActive.Enabled := False;
      LblActive.Caption := '';
      Exit;
    end;
    EdName.Enabled := True; EdBrand.Enabled := True; EdModel.Enabled := True; EdOpticalPower.Enabled := True;
    BtnApply.Enabled := True; BtnDelete.Enabled := True;
    EdName.Text := FCounters[idx].Name;
    EdBrand.Text := FCounters[idx].Brand;
    EdModel.Text := FCounters[idx].Model;
    if FCounters[idx].HasOpticalPower then
      EdOpticalPower.Text := FloatToStr(FCounters[idx].OpticalPower)
    else
      EdOpticalPower.Text := '';
    if FCounters[idx].Guid = FActiveGuid then
    begin
      LblActive.Caption := T('This is the currently active (live-tracking) laser.');
      BtnSetActive.Enabled := False;
    end
    else
    begin
      LblActive.Caption := '';
      BtnSetActive.Enabled := True;
    end;
  finally
    FLoadingFields := False;
  end;
end;

procedure TLaserUsageForm.ListBox1SelectionChange(Sender: TObject; User: Boolean);
begin
  ShowSelected;
end;

procedure TLaserUsageForm.FieldChange(Sender: TObject);
begin
  // Deliberately a no-op until "Apply" - editing the Name/Brand/Model/
  // Power fields shouldn't silently mutate FCounters (and the list's own
  // display text) on every keystroke; see BtnApplyClick.
  if FLoadingFields then Exit;
end;

procedure TLaserUsageForm.BtnApplyClick(Sender: TObject);
var
  idx: Integer;
  p: Double;
begin
  idx := SelectedIndex;
  if idx < 0 then Exit;
  if Trim(EdName.Text) = '' then
  begin
    ShowMessage(T('Name cannot be blank.'));
    Exit;
  end;
  FCounters[idx].Name := Trim(EdName.Text);
  FCounters[idx].Brand := Trim(EdBrand.Text);
  FCounters[idx].Model := Trim(EdModel.Text);
  if TryStrToFloat(Trim(EdOpticalPower.Text), p) then
  begin
    FCounters[idx].HasOpticalPower := True;
    FCounters[idx].OpticalPower := p;
  end
  else
    FCounters[idx].HasOpticalPower := False;
  RefreshList;
end;

procedure TLaserUsageForm.BtnAddNewClick(Sender: TObject);
begin
  SetLength(FCounters, Length(FCounters) + 1);
  FCounters[High(FCounters)] := CreateNewCounter;
  FCounters[High(FCounters)].Name := T('New laser') + ' ' + IntToStr(Length(FCounters));
  RefreshList;
  ListBox1.ItemIndex := High(FCounters);
  ShowSelected;
end;

procedure TLaserUsageForm.BtnDeleteClick(Sender: TObject);
var
  idx, i: Integer;
begin
  idx := SelectedIndex;
  if idx < 0 then Exit;
  if FCounters[idx].Guid = FActiveGuid then
  begin
    ShowMessage(T('Cannot delete the currently active laser - switch to another one first.'));
    Exit;
  end;
  for i := idx to High(FCounters) - 1 do
    FCounters[i] := FCounters[i + 1];
  SetLength(FCounters, Length(FCounters) - 1);
  RefreshList;
end;

procedure TLaserUsageForm.BtnSetActiveClick(Sender: TObject);
var
  idx: Integer;
begin
  idx := SelectedIndex;
  if idx < 0 then Exit;
  FActiveGuid := FCounters[idx].Guid;
  RefreshList;
end;

class procedure TLaserUsageForm.Execute(var ACounters: TLaserUsageCounterArray; var AActiveGuid: string);
var
  frm: TLaserUsageForm;
begin
  frm := TLaserUsageForm.Create(Application);
  try
    frm.FCounters := ACounters;
    frm.FActiveGuid := AActiveGuid;
    frm.RefreshList;
    frm.ShowModal;
    ACounters := frm.FCounters;
    AActiveGuid := frm.FActiveGuid;
  finally
    frm.Free;
  end;
end;

end.
