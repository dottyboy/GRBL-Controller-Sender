unit uaxiscalibrationframe;

{ TAxisCalibrationFrame: axis steps/mm calibration wizard (plan Phase 24,
  converted from a modal dialog to a plain Settings & Tools tab in a
  later session - this X11/Qt5 environment hit a real, reproducible
  crash creating ANY second top-level window via ShowModal, confirmed
  environment-level, not a code regression, unfixable from here - a
  tab sidesteps it entirely by never creating a second window), concept
  from OpenBuilds CONTROL's own calibration dialog
  (app/wizards/calibration/calibrate-x.js, -y.js, -z.js, read directly): pick an
  axis, jog a known distance, hand-measure the actual real-world distance
  moved, and correct GRBL's $100/$101/$102 by
    newsteps = currentsteps * (requested / measured)
  - the exact formula OpenBuilds' own applycalibrationx() uses. The math
  lives in uaxiscalibration.pas (pure, LCL-free, standalone-tested); this
  frame only owns the jog/WriteSetting calls, reusing TSender.Jog/
  WriteSetting/RequestSettings unchanged (no new protocol work, per the
  plan's own note).

  One deliberate difference from OpenBuilds' own three-slide wizard: the
  distance actually commanded to the machine is FROZEN at the moment
  BtnJog is clicked (FRequestedDistance), not re-read from EdDistance at
  Apply time - OpenBuilds' own JS reads its move-distance variable live at
  both jog time and apply time, so editing the distance field after
  jogging but before applying silently uses the wrong number in its own
  formula. Freezing it here avoids reproducing that.

  Servo pen-up/pen-down calibration (calibrate-servo.js) is deliberately
  NOT ported here - see uaxiscalibration.pas's own doc comment. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls, Dialogs,
  Spin, usender, uaxiscalibration, ui18n, ui18ncontrols;

type

  { TAxisCalibrationFrame }

  TAxisCalibrationFrame = class(TFrame)
    BtnApply: TButton;
    BtnJog: TButton;
    BtnRefresh: TButton;
    EdDistance: TFloatSpinEdit;
    EdMeasured: TFloatSpinEdit;
    LblCurrentStepsCaption: TLabel;
    LblCurrentStepsVal: TLabel;
    LblDistanceCaption: TLabel;
    LblFormula: TLabel;
    LblMeasuredCaption: TLabel;
    LblStatus: TLabel;
    RbAxisX: TRadioButton;
    RbAxisY: TRadioButton;
    RbAxisZ: TRadioButton;
    RefreshTimer: TTimer;
    procedure AxisChanged(Sender: TObject);
    procedure BtnApplyClick(Sender: TObject);
    procedure BtnJogClick(Sender: TObject);
    procedure BtnRefreshClick(Sender: TObject);
    procedure EdMeasuredChange(Sender: TObject);
    procedure RefreshTimerTimer(Sender: TObject);
  private
    FSender: TSender;
    FCurrentSteps: Double;
    FRequestedDistance: Double;  // frozen at BtnJog click, see class doc
    FNewSteps: Double;
    function SelectedAxis: Char;
    procedure RequestCurrentSteps;
    procedure UpdatePreview;
    procedure SetStatus(const AMsg: string; AIsError: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetSender(ASender: TSender);
  end;

implementation

{$R *.frm}

{ TAxisCalibrationFrame }

constructor TAxisCalibrationFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  TranslateControls(Self);
  RbAxisX.Checked := True;
  FRequestedDistance := 0;
  LblFormula.Caption := '';
end;

procedure TAxisCalibrationFrame.SetSender(ASender: TSender);
begin
  FSender := ASender;
  RequestCurrentSteps;
end;

function TAxisCalibrationFrame.SelectedAxis: Char;
begin
  if RbAxisY.Checked then Result := 'Y'
  else if RbAxisZ.Checked then Result := 'Z'
  else Result := 'X';
end;

procedure TAxisCalibrationFrame.SetStatus(const AMsg: string; AIsError: Boolean);
begin
  LblStatus.Caption := AMsg;
  if AIsError then
    LblStatus.Font.Color := clRed
  else
    LblStatus.Font.Color := clGreen;
end;

procedure TAxisCalibrationFrame.RequestCurrentSteps;
begin
  LblCurrentStepsVal.Caption := '?';
  FRequestedDistance := 0;
  LblFormula.Caption := '';
  BtnApply.Enabled := False;
  if (FSender = nil) or (not FSender.Connected) then
  begin
    SetStatus(T('Not connected'), True);
    Exit;
  end;
  SetStatus(T('Requesting $$...'), False);
  FSender.RequestSettings;
  // No explicit "dump complete" signal on the wire (same reasoning as
  // usettingsgridframe.pas's own BtnRefreshClick) - give it a beat.
  RefreshTimer.Enabled := False;
  RefreshTimer.Enabled := True;
end;

procedure TAxisCalibrationFrame.RefreshTimerTimer(Sender: TObject);
var
  id: string;
begin
  RefreshTimer.Enabled := False;
  if (FSender = nil) or (not FSender.Connected) then Exit;
  id := AxisStepsSettingID(SelectedAxis);
  FCurrentSteps := StrToFloatDef(FSender.State.Settings.Values[id], 0);
  if FCurrentSteps > 0 then
  begin
    LblCurrentStepsVal.Caption := FormatFloat('0.###', FCurrentSteps);
    SetStatus(Format(T('Current $%s = %s'), [id, LblCurrentStepsVal.Caption]), False);
  end
  else
  begin
    LblCurrentStepsVal.Caption := '?';
    SetStatus(T('No settings loaded yet - is the board connected?'), True);
  end;
end;

procedure TAxisCalibrationFrame.AxisChanged(Sender: TObject);
begin
  RequestCurrentSteps;
end;

procedure TAxisCalibrationFrame.BtnRefreshClick(Sender: TObject);
begin
  RequestCurrentSteps;
end;

procedure TAxisCalibrationFrame.BtnJogClick(Sender: TObject);
begin
  if (FSender = nil) or (not FSender.Connected) then
  begin
    SetStatus(T('Not connected'), True);
    Exit;
  end;
  if EdDistance.Value <= 0 then Exit;
  FRequestedDistance := EdDistance.Value;
  FSender.Jog(JogDistanceString(SelectedAxis, FRequestedDistance));
  EdMeasured.Value := FRequestedDistance;
  SetStatus(Format(T('Jogged %s%s - now measure the actual distance moved'),
    [SelectedAxis, FormatFloat('0.###', FRequestedDistance)]), False);
  UpdatePreview;
end;

procedure TAxisCalibrationFrame.EdMeasuredChange(Sender: TObject);
begin
  UpdatePreview;
end;

procedure TAxisCalibrationFrame.UpdatePreview;
begin
  BtnApply.Enabled := False;
  if (FRequestedDistance <= 0) or (FCurrentSteps <= 0) then
  begin
    LblFormula.Caption := '';
    Exit;
  end;
  if not TryCalibrateStepsPerMM(FCurrentSteps, FRequestedDistance, EdMeasured.Value, FNewSteps) then
  begin
    LblFormula.Caption := '';
    Exit;
  end;
  LblFormula.Caption := Format('%s * (%s / %s) = %s',
    [FormatFloat('0.###', FCurrentSteps), FormatFloat('0.###', FRequestedDistance),
     FormatFloat('0.###', EdMeasured.Value), FormatFloat('0.##', FNewSteps)]);
  BtnApply.Enabled := (FSender <> nil) and FSender.Connected;
end;

procedure TAxisCalibrationFrame.BtnApplyClick(Sender: TObject);
var
  id: string;
begin
  if (FSender = nil) or (not FSender.Connected) then Exit;
  id := AxisStepsSettingID(SelectedAxis);
  if id = '' then Exit;
  FSender.WriteSetting(id, FormatFloat('0.##', FNewSteps));
  SetStatus(Format(T('Applied: $%s = %s'), [id, FormatFloat('0.##', FNewSteps)]), False);
  // Refresh the displayed current value from the board's own confirmation,
  // rather than just trusting what we sent.
  RequestCurrentSteps;
end;

end.
