unit uresumejobform;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, StdCtrls, ExtCtrls, Spin,
  ustatebuilder, ui18n, ui18ncontrols;

type

  { TResumeJobForm: shown when an active laser job unexpectedly stops
    (Alarm, buffer/connection issue - see umain.pas's SenderStateChanged
    hook) so the user can pick where to resume from and whether to re-home
    or restore the work-coordinate offset, mirrors LaserGRBL's
    ResumeJobForm.cs but scoped to this app's simpler progress model
    (Executed/Sent counts, no separate "planner buffer" concept - see
    TSender.LaserJobProgress in usender.pas). }
  TResumeJobForm = class(TForm)
    BtnCancel: TButton;
    BtnOK: TButton;
    CbRedoHoming: TCheckBox;
    CbUnlockOnly: TCheckBox;
    CbRestoreWCO: TCheckBox;
    LblCause: TLabel;
    LblCauseValue: TLabel;
    LblCounts: TLabel;
    RbFromBeginning: TRadioButton;
    RbFromExecuted: TRadioButton;
    RbFromSent: TRadioButton;
    RbFromSpecific: TRadioButton;
    SpecificLine: TSpinEdit;
    procedure FormCreate(Sender: TObject);
    procedure RbCheckedChanged(Sender: TObject);
    procedure CbRedoHomingChange(Sender: TObject);
    procedure BtnOKClick(Sender: TObject);
    procedure BtnCancelClick(Sender: TObject);
  private
    FTarget: Integer;
    function SelectedLine: Integer; // 0-based, or -1 if nothing valid selected
  public
    // Modal entry point. AExecuted/ASent/ATarget are 0-based counts into
    // the job's body (see TLaserJobProgress). AHasWCO gates whether the
    // restore-WCO checkbox is offered at all (no point showing it if the
    // work offset is still zero/unknown). Returns True + fills AResumeLine
    // (0-based) and AOpts on OK, False (AResumeLine=-1) on Cancel.
    class function Execute(AExecuted, ASent, ATarget: Integer; const ACause: string;
      AHasWCO: Boolean; AWCOX, AWCOY, AWCOZ: Double;
      out AResumeLine: Integer; out AOpts: TResumeOptions): Boolean;
  end;

implementation

{$R *.frm}

procedure TResumeJobForm.FormCreate(Sender: TObject);
begin
  TranslateControls(Self);
end;

function TResumeJobForm.SelectedLine: Integer;
begin
  if RbFromBeginning.Checked then Result := 0
  else if RbFromExecuted.Checked then Result := RbFromExecuted.Tag
  else if RbFromSent.Checked then Result := RbFromSent.Tag
  else if RbFromSpecific.Checked then Result := SpecificLine.Value - 1
  else Result := -1;

  if (Result < 0) or (Result > FTarget) then Result := -1;
end;

procedure TResumeJobForm.RbCheckedChanged(Sender: TObject);
begin
  SpecificLine.Enabled := RbFromSpecific.Checked;
  BtnOK.Enabled := SelectedLine >= 0;
end;

procedure TResumeJobForm.CbRedoHomingChange(Sender: TObject);
begin
  // Re-homing and a bare unlock are mutually exclusive recovery choices -
  // $H already clears an alarm as part of homing, $X is only meaningful
  // when NOT also homing.
  if CbRedoHoming.Checked then CbUnlockOnly.Checked := False;
end;

procedure TResumeJobForm.BtnOKClick(Sender: TObject);
begin
  if SelectedLine < 0 then Exit;
  ModalResult := mrOK;
end;

procedure TResumeJobForm.BtnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

class function TResumeJobForm.Execute(AExecuted, ASent, ATarget: Integer; const ACause: string;
  AHasWCO: Boolean; AWCOX, AWCOY, AWCOZ: Double;
  out AResumeLine: Integer; out AOpts: TResumeOptions): Boolean;
var
  frm: TResumeJobForm;
begin
  AResumeLine := -1;
  AOpts.DoHoming := False;
  AOpts.DoUnlock := False;
  AOpts.RestoreWCO := False;
  AOpts.WCOX := AWCOX; AOpts.WCOY := AWCOY; AOpts.WCOZ := AWCOZ;

  frm := TResumeJobForm.Create(Application);
  try
    frm.FTarget := ATarget;
    frm.LblCauseValue.Caption := ACause;
    frm.LblCounts.Caption := Format(T('Executed %d / Sent %d / Target %d'),
      [AExecuted, ASent, ATarget]);

    frm.RbFromBeginning.Checked := True;
    frm.RbFromExecuted.Caption := Format(T('From last executed line (#%d)'), [AExecuted + 1]);
    frm.RbFromExecuted.Tag := AExecuted;
    frm.RbFromExecuted.Enabled := (AExecuted > 0) and (AExecuted < ATarget);
    frm.RbFromSent.Caption := Format(T('From last sent line (#%d)'), [ASent + 1]);
    frm.RbFromSent.Tag := ASent;
    frm.RbFromSent.Enabled := (ASent > 0) and (ASent <> AExecuted) and (ASent < ATarget);
    frm.RbFromSpecific.Enabled := ATarget > 0;
    frm.SpecificLine.MaxValue := Max(1, ATarget);
    frm.SpecificLine.Value := Max(1, AExecuted + 1);
    frm.SpecificLine.Enabled := False;

    frm.CbRestoreWCO.Visible := AHasWCO;
    frm.CbRestoreWCO.Checked := AHasWCO;
    if AHasWCO then
      frm.CbRestoreWCO.Caption := Format('%s X%s Y%s Z%s',
        [T('Restore work offset'), GCodeNum(AWCOX), GCodeNum(AWCOY), GCodeNum(AWCOZ)]);

    frm.RbCheckedChanged(nil);

    Result := frm.ShowModal = mrOK;
    if Result then
    begin
      AResumeLine := frm.SelectedLine;
      AOpts.DoHoming := frm.CbRedoHoming.Checked;
      AOpts.DoUnlock := frm.CbUnlockOnly.Checked;
      AOpts.RestoreWCO := frm.CbRestoreWCO.Visible and frm.CbRestoreWCO.Checked;
    end;
  finally
    frm.Free;
  end;
end;

end.
