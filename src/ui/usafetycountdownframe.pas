unit usafetycountdownframe;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls,
  ui18n, ui18ncontrols;

type
  { TSafetyCountdownFrame: modal countdown shown before a laser job starts
    (plan Phase 6 - LaserGRBL's own SafetyCountdown.cs), converted from a
    modal dialog to a plain Laser-group tab in a later session - this
    X11/Qt5 environment hit a real, reproducible crash creating ANY
    second top-level window via ShowModal, confirmed environment-level,
    not a code regression.

    Since this is a GATE before a job starts, not a passive settings
    panel, it can't just become an inert tab the way Axis Calibration/
    WiFi Config/Parametric Tool did - ulasercontrolframe.pas's own
    BtnStartClick used to call this modally and block until it returned;
    it now instead fires OnCountdownRequested and returns immediately
    without starting the job, and THIS frame fires OnFinished/OnCancelled
    once the countdown really ends - umain.pas wires all three so the
    job only actually starts (or is abandoned) from those callbacks,
    matching the old modal's exact two outcomes (ran out / Cancelled). }
  TOnCountdownDone = procedure(Sender: TObject; ADontShowAgain: Boolean) of object;

  { TSafetyCountdownFrame }

  TSafetyCountdownFrame = class(TFrame)
    BtnCancel: TButton;
    ChkDontShowAgain: TCheckBox;
    LblMessage: TLabel;
    LblSeconds: TLabel;
    Timer1: TTimer;
    procedure BtnCancelClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    FSecondsLeft: Integer;
    FOnFinished: TOnCountdownDone;
    FOnCancelled: TOnCountdownDone;
    procedure UpdateLabel;
  public
    constructor Create(AOwner: TComponent); override;
    // Starts (or restarts) the countdown at ASeconds, pre-filling the
    // checkbox from ADontShowAgain (e.g. a persisted TAppConfig value).
    procedure StartCountdown(ASeconds: Integer; ADontShowAgain: Boolean);
    property OnFinished: TOnCountdownDone read FOnFinished write FOnFinished;
    property OnCancelled: TOnCountdownDone read FOnCancelled write FOnCancelled;
  end;

implementation

{$R *.frm}

{ TSafetyCountdownFrame }

constructor TSafetyCountdownFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  TranslateControls(Self);
end;

procedure TSafetyCountdownFrame.UpdateLabel;
begin
  LblSeconds.Caption := IntToStr(FSecondsLeft);
end;

procedure TSafetyCountdownFrame.StartCountdown(ASeconds: Integer; ADontShowAgain: Boolean);
begin
  if ASeconds < 1 then ASeconds := 1;
  FSecondsLeft := ASeconds;
  ChkDontShowAgain.Checked := ADontShowAgain;
  UpdateLabel;
  Timer1.Enabled := False;
  Timer1.Interval := 1000;
  Timer1.Enabled := True;
end;

procedure TSafetyCountdownFrame.Timer1Timer(Sender: TObject);
begin
  Dec(FSecondsLeft);
  if FSecondsLeft <= 0 then
  begin
    Timer1.Enabled := False;
    if Assigned(FOnFinished) then
      FOnFinished(Self, ChkDontShowAgain.Checked);
  end
  else
    UpdateLabel;
end;

procedure TSafetyCountdownFrame.BtnCancelClick(Sender: TObject);
begin
  Timer1.Enabled := False;
  if Assigned(FOnCancelled) then
    FOnCancelled(Self, ChkDontShowAgain.Checked);
end;

end.
