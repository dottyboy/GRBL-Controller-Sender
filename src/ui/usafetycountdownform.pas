unit usafetycountdownform;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls,
  ui18n, ui18ncontrols;

type

  { TSafetyCountdownForm: modal countdown shown before a laser job starts
    (plan Phase 6 - LaserGRBL's own SafetyCountdown.cs). Not wired to a
    real Start button yet (that's Phase 9's TabLaserControl) - Execute is
    the entry point a future caller uses; exercised standalone this phase
    via a temporary debug call, per the plan's own testing convention. }
  TSafetyCountdownForm = class(TForm)
    BtnCancel: TButton;
    ChkDontShowAgain: TCheckBox;
    LblMessage: TLabel;
    LblSeconds: TLabel;
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    FSecondsLeft: Integer;
    procedure UpdateLabel;
  public
    // Shows the countdown modally. ASeconds is the starting count.
    // ADontShowAgain is both an in (pre-fills the checkbox, e.g. from a
    // persisted TAppConfig.SkipSafetyCountdown) and out (the checkbox's
    // final state, for the caller to persist) parameter. Returns True if
    // the countdown ran to completion or the user didn't cancel, False if
    // Cancel was clicked.
    class function Execute(ASeconds: Integer; var ADontShowAgain: Boolean): Boolean;
  end;

implementation

{$R *.frm}

procedure TSafetyCountdownForm.FormCreate(Sender: TObject);
begin
  TranslateControls(Self);
end;

procedure TSafetyCountdownForm.UpdateLabel;
begin
  LblSeconds.Caption := IntToStr(FSecondsLeft);
end;

procedure TSafetyCountdownForm.Timer1Timer(Sender: TObject);
begin
  Dec(FSecondsLeft);
  if FSecondsLeft <= 0 then
  begin
    Timer1.Enabled := False;
    ModalResult := mrOK;
  end
  else
    UpdateLabel;
end;

class function TSafetyCountdownForm.Execute(ASeconds: Integer; var ADontShowAgain: Boolean): Boolean;
var
  frm: TSafetyCountdownForm;
begin
  if ASeconds < 1 then ASeconds := 1;
  frm := TSafetyCountdownForm.Create(Application);
  try
    frm.FSecondsLeft := ASeconds;
    frm.ChkDontShowAgain.Checked := ADontShowAgain;
    frm.UpdateLabel;
    frm.Timer1.Interval := 1000;
    frm.Timer1.Enabled := True;
    Result := frm.ShowModal <> mrCancel;
    ADontShowAgain := frm.ChkDontShowAgain.Checked;
  finally
    frm.Free;
  end;
end;

end.
