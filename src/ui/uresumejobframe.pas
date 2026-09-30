unit uresumejobframe;

{ TResumeJobFrame: shown when an active laser job unexpectedly stops
  (Alarm, buffer/connection issue - see umain.pas's SenderStateChanged
  hook) so the user can pick where to resume from and whether to re-home
  or restore the work-coordinate offset, mirrors LaserGRBL's
  ResumeJobForm.cs but scoped to this app's simpler progress model
  (Executed/Sent counts, no separate "planner buffer" concept - see
  TSender.LaserJobProgress in usender.pas).

  Converted from a modal dialog to a plain Laser-group tab in the same
  session as the other 4 stretch-goal dialogs - this X11/Qt5
  environment hit a real, reproducible crash creating ANY second
  top-level window via ShowModal, confirmed environment-level, not a
  code regression. Fires OnResumeDecided/OnAborted instead of returning
  from a blocking ShowModal call; umain.pas's own OfferLaserResume now
  just shows this tab and returns immediately - the actual
  ResumeLaserJob/EndLaserJob calls happen from those two callbacks. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, StdCtrls, ExtCtrls, Spin,
  ustatebuilder, ui18n, ui18ncontrols;

type
  TOnResumeDecided = procedure(Sender: TObject; AResumeLine: Integer;
    const AOpts: TResumeOptions) of object;

  { TResumeJobFrame }

  TResumeJobFrame = class(TFrame)
    BtnAbort: TButton;
    BtnResume: TButton;
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
    procedure BtnAbortClick(Sender: TObject);
    procedure BtnResumeClick(Sender: TObject);
    procedure CbRedoHomingChange(Sender: TObject);
    procedure RbCheckedChanged(Sender: TObject);
  private
    FTarget: Integer;
    FWCOX, FWCOY, FWCOZ: Double;
    FOnResumeDecided: TOnResumeDecided;
    FOnAborted: TNotifyEvent;
    function SelectedLine: Integer; // 0-based, or -1 if nothing valid selected
  public
    constructor Create(AOwner: TComponent); override;
    // AExecuted/ASent/ATarget are 0-based counts into the job's body
    // (see TLaserJobProgress). AHasWCO gates whether the restore-WCO
    // checkbox is offered at all (no point showing it if the work
    // offset is still zero/unknown).
    procedure ShowResumeOptions(AExecuted, ASent, ATarget: Integer; const ACause: string;
      AHasWCO: Boolean; AWCOX, AWCOY, AWCOZ: Double);
    property OnResumeDecided: TOnResumeDecided read FOnResumeDecided write FOnResumeDecided;
    property OnAborted: TNotifyEvent read FOnAborted write FOnAborted;
  end;

implementation

{$R *.frm}

constructor TResumeJobFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  TranslateControls(Self);
end;

function TResumeJobFrame.SelectedLine: Integer;
begin
  if RbFromBeginning.Checked then Result := 0
  else if RbFromExecuted.Checked then Result := RbFromExecuted.Tag
  else if RbFromSent.Checked then Result := RbFromSent.Tag
  else if RbFromSpecific.Checked then Result := SpecificLine.Value - 1
  else Result := -1;

  if (Result < 0) or (Result > FTarget) then Result := -1;
end;

procedure TResumeJobFrame.RbCheckedChanged(Sender: TObject);
begin
  SpecificLine.Enabled := RbFromSpecific.Checked;
  BtnResume.Enabled := SelectedLine >= 0;
end;

procedure TResumeJobFrame.CbRedoHomingChange(Sender: TObject);
begin
  // Re-homing and a bare unlock are mutually exclusive recovery choices -
  // $H already clears an alarm as part of homing, $X is only meaningful
  // when NOT also homing.
  if CbRedoHoming.Checked then CbUnlockOnly.Checked := False;
end;

procedure TResumeJobFrame.ShowResumeOptions(AExecuted, ASent, ATarget: Integer;
  const ACause: string; AHasWCO: Boolean; AWCOX, AWCOY, AWCOZ: Double);
begin
  FTarget := ATarget;
  FWCOX := AWCOX; FWCOY := AWCOY; FWCOZ := AWCOZ;
  LblCauseValue.Caption := ACause;
  LblCounts.Caption := Format(T('Executed %d / Sent %d / Target %d'),
    [AExecuted, ASent, ATarget]);

  RbFromBeginning.Checked := True;
  RbFromExecuted.Caption := Format(T('From last executed line (#%d)'), [AExecuted + 1]);
  RbFromExecuted.Tag := AExecuted;
  RbFromExecuted.Enabled := (AExecuted > 0) and (AExecuted < ATarget);
  RbFromSent.Caption := Format(T('From last sent line (#%d)'), [ASent + 1]);
  RbFromSent.Tag := ASent;
  RbFromSent.Enabled := (ASent > 0) and (ASent <> AExecuted) and (ASent < ATarget);
  RbFromSpecific.Enabled := ATarget > 0;
  SpecificLine.MaxValue := Max(1, ATarget);
  SpecificLine.Value := Max(1, AExecuted + 1);
  SpecificLine.Enabled := False;

  CbRestoreWCO.Visible := AHasWCO;
  CbRestoreWCO.Checked := AHasWCO;
  if AHasWCO then
    CbRestoreWCO.Caption := Format('%s X%s Y%s Z%s',
      [T('Restore work offset'), GCodeNum(AWCOX), GCodeNum(AWCOY), GCodeNum(AWCOZ)]);

  RbCheckedChanged(nil);
end;

procedure TResumeJobFrame.BtnResumeClick(Sender: TObject);
var
  resumeLine: Integer;
  opts: TResumeOptions;
begin
  resumeLine := SelectedLine;
  if resumeLine < 0 then Exit;
  opts.DoHoming := CbRedoHoming.Checked;
  opts.DoUnlock := CbUnlockOnly.Checked;
  opts.RestoreWCO := CbRestoreWCO.Visible and CbRestoreWCO.Checked;
  opts.WCOX := FWCOX; opts.WCOY := FWCOY; opts.WCOZ := FWCOZ;
  if Assigned(FOnResumeDecided) then
    FOnResumeDecided(Self, resumeLine, opts);
end;

procedure TResumeJobFrame.BtnAbortClick(Sender: TObject);
begin
  if Assigned(FOnAborted) then
    FOnAborted(Self);
end;

end.
