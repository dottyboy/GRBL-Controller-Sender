unit uaxiscalibrationform;

{ TAxisCalibrationForm: axis steps/mm calibration wizard (plan Phase 24),
  concept from OpenBuilds CONTROL's own calibration dialog
  (app/wizards/calibration/calibrate-x.js, -y.js, -z.js, read directly): pick an
  axis, jog a known distance, hand-measure the actual real-world distance
  moved, and correct GRBL's $100/$101/$102 by
    newsteps = currentsteps * (requested / measured)
  - the exact formula OpenBuilds' own applycalibrationx() uses. The math
  lives in uaxiscalibration.pas (pure, LCL-free, standalone-tested); this
  form only owns the jog/WriteSetting calls, reusing TSender.Jog/
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

  { TAxisCalibrationForm }

  TAxisCalibrationForm = class(TForm)
    BtnApply: TButton;
    BtnClose: TButton;
    BtnJog: TButton;
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
    procedure EdMeasuredChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
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
    class procedure Execute(ASender: TSender);
  end;

implementation

{$R *.frm}

{ TAxisCalibrationForm }

procedure TAxisCalibrationForm.FormCreate(Sender: TObject);
begin
  TranslateControls(Self);
  RbAxisX.Checked := True;
  FRequestedDistance := 0;
  LblFormula.Caption := '';
  // FSender isn't set yet at this point (Execute below assigns it right
  // after Create, which is what fires this handler) - RequestCurrentSteps
  // runs again once it is, see Execute.
end;

function TAxisCalibrationForm.SelectedAxis: Char;
begin
  if RbAxisY.Checked then Result := 'Y'
  else if RbAxisZ.Checked then Result := 'Z'
  else Result := 'X';
end;

procedure TAxisCalibrationForm.SetStatus(const AMsg: string; AIsError: Boolean);
begin
  LblStatus.Caption := AMsg;
  if AIsError then
    LblStatus.Font.Color := clRed
  else
    LblStatus.Font.Color := clGreen;
end;

procedure TAxisCalibrationForm.RequestCurrentSteps;
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

procedure TAxisCalibrationForm.RefreshTimerTimer(Sender: TObject);
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

procedure TAxisCalibrationForm.AxisChanged(Sender: TObject);
begin
  RequestCurrentSteps;
end;

procedure TAxisCalibrationForm.BtnJogClick(Sender: TObject);
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

procedure TAxisCalibrationForm.EdMeasuredChange(Sender: TObject);
begin
  UpdatePreview;
end;

procedure TAxisCalibrationForm.UpdatePreview;
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

procedure TAxisCalibrationForm.BtnApplyClick(Sender: TObject);
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

class procedure TAxisCalibrationForm.Execute(ASender: TSender);
var
  frm: TAxisCalibrationForm;
begin
  frm := TAxisCalibrationForm.Create(Application);
  try
    frm.FSender := ASender;
    frm.RequestCurrentSteps;
    frm.ShowModal;
  finally
    frm.Free;
  end;
end;

end.
