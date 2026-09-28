unit uaxeseditform;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Dialogs,
  ufluidncaxes, ui18n;

type

  { TAxesEditForm: structured editor for a FluidNC config.yaml's "axes:"
    block (Phase H MVP) - reads/writes through TFluidNCAxesConfig, which
    does the actual YAML parsing/generation/splicing. This form only knows
    about TAxisConfig field values and which axis/motor is on screen. }
  TAxesEditForm = class(TForm)
    BtnCancel: TButton;
    BtnOK: TButton;
    CboAxis: TComboBox;
    CboDriverType: TComboBox;
    CboMotor: TComboBox;
    ChkHardLimits: TCheckBox;
    ChkPositiveDirection: TCheckBox;
    ChkSoftLimits: TCheckBox;
    EdAcceleration: TEdit;
    EdDirectionPin: TEdit;
    EdDisablePin: TEdit;
    EdFeedRate: TEdit;
    EdFeedScaler: TEdit;
    EdHomingCycle: TEdit;
    EdLimitAllPin: TEdit;
    EdLimitNegPin: TEdit;
    EdLimitPosPin: TEdit;
    EdMaxRate: TEdit;
    EdMaxTravel: TEdit;
    EdMposMM: TEdit;
    EdMS3Pin: TEdit;
    EdPulloffMM: TEdit;
    EdSeekRate: TEdit;
    EdSeekScaler: TEdit;
    EdSettleMs: TEdit;
    EdStepPin: TEdit;
    EdStepsPerMM: TEdit;
    LblAcceleration: TLabel;
    LblAxis: TLabel;
    LblAxisSection: TLabel;
    LblDirectionPin: TLabel;
    LblDisablePin: TLabel;
    LblDriverType: TLabel;
    LblFeedRate: TLabel;
    LblFeedScaler: TLabel;
    LblHomingCycle: TLabel;
    LblHomingSection: TLabel;
    LblLimitAllPin: TLabel;
    LblLimitNegPin: TLabel;
    LblLimitPosPin: TLabel;
    LblMaxRate: TLabel;
    LblMaxTravel: TLabel;
    LblMotor: TLabel;
    LblMotorSection: TLabel;
    LblMposMM: TLabel;
    LblMS3Pin: TLabel;
    LblPulloffMM: TLabel;
    LblSeekRate: TLabel;
    LblSeekScaler: TLabel;
    LblSettleMs: TLabel;
    LblStatus: TLabel;
    LblStepPin: TLabel;
    LblStepsPerMM: TLabel;
    procedure BtnOKClick(Sender: TObject);
    procedure CboAxisChange(Sender: TObject);
    procedure CboDriverTypeChange(Sender: TObject);
    procedure CboMotorChange(Sender: TObject);
  private
    FConfig: TFluidNCAxesConfig;
    FCurrentAxisIndex: Integer;
    FCurrentMotorSlot: Integer;
    FLoading: Boolean; // guards against re-entrant Save-while-populating
    procedure PopulateAxisCombo;
    procedure SaveCurrentIntoConfig;
    procedure LoadCurrentFromConfig;
    procedure RefreshDriverFieldsEnabled;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // Returns False (dialog should not be shown) if AFullText has no
    // top-level "axes:" block to edit.
    function LoadFromYAML(const AFullText: string): Boolean;
    // Call after ShowModal returns mrOK - splices the edited axes: block
    // back into AOriginalFullText (everything else passes through
    // unchanged, see TFluidNCAxesConfig.ApplyToFullYAML).
    function ApplyToYAML(const AOriginalFullText: string): string;
  end;

implementation

{$R *.frm}

{ TAxesEditForm }

constructor TAxesEditForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FConfig := TFluidNCAxesConfig.Create;
  FCurrentAxisIndex := -1;
  FCurrentMotorSlot := 0;
  CboDriverType.Items.Clear;
  CboDriverType.Items.Add('standard_stepper');
  CboDriverType.Items.Add('stepstick');
  CboMotor.Items.Clear;
  CboMotor.Items.Add('Motor 0');
  CboMotor.Items.Add('Motor 1');
end;

destructor TAxesEditForm.Destroy;
begin
  FConfig.Free;
  inherited Destroy;
end;

function TAxesEditForm.LoadFromYAML(const AFullText: string): Boolean;
begin
  Result := FConfig.ParseFromYAML(AFullText);
  if not Result then Exit;
  PopulateAxisCombo;
  if CboAxis.Items.Count > 0 then
  begin
    CboAxis.ItemIndex := 0;
    CboMotor.ItemIndex := 0;
    FCurrentAxisIndex := 0;
    FCurrentMotorSlot := 0;
    LoadCurrentFromConfig;
  end;
end;

function TAxesEditForm.ApplyToYAML(const AOriginalFullText: string): string;
begin
  SaveCurrentIntoConfig;
  Result := FConfig.ApplyToFullYAML(AOriginalFullText);
end;

procedure TAxesEditForm.PopulateAxisCombo;
var
  i: Integer;
begin
  CboAxis.Items.Clear;
  for i := 0 to FConfig.Count - 1 do
    CboAxis.Items.Add(string(FConfig.AxisAt(i).Letter));
end;

// Pushes the currently-displayed fields back into FConfig for whichever
// axis/motor was on screen before a combo change or OK - so switching
// axes (or clicking OK) never silently drops an in-progress edit.
procedure TAxesEditForm.SaveCurrentIntoConfig;
var
  a: TAxisConfig;
begin
  if (FCurrentAxisIndex < 0) or (FCurrentAxisIndex >= FConfig.Count) then Exit;
  a := FConfig.AxisAt(FCurrentAxisIndex);

  a.StepsPerMM := StrToFloatDef(EdStepsPerMM.Text, a.StepsPerMM);
  a.MaxRateMMPerMin := StrToFloatDef(EdMaxRate.Text, a.MaxRateMMPerMin);
  a.AccelerationMMPerSec2 := StrToFloatDef(EdAcceleration.Text, a.AccelerationMMPerSec2);
  a.MaxTravelMM := StrToFloatDef(EdMaxTravel.Text, a.MaxTravelMM);
  a.SoftLimits := ChkSoftLimits.Checked;

  a.Homing.Cycle := StrToIntDef(EdHomingCycle.Text, a.Homing.Cycle);
  a.Homing.PositiveDirection := ChkPositiveDirection.Checked;
  a.Homing.MposMM := StrToFloatDef(EdMposMM.Text, a.Homing.MposMM);
  a.Homing.FeedMMPerMin := StrToFloatDef(EdFeedRate.Text, a.Homing.FeedMMPerMin);
  a.Homing.SeekMMPerMin := StrToFloatDef(EdSeekRate.Text, a.Homing.SeekMMPerMin);
  a.Homing.SettleMs := StrToIntDef(EdSettleMs.Text, a.Homing.SettleMs);
  a.Homing.SeekScaler := StrToFloatDef(EdSeekScaler.Text, a.Homing.SeekScaler);
  a.Homing.FeedScaler := StrToFloatDef(EdFeedScaler.Text, a.Homing.FeedScaler);

  a.Motors[FCurrentMotorSlot].Present := True;
  a.Motors[FCurrentMotorSlot].LimitNegPin := EdLimitNegPin.Text;
  a.Motors[FCurrentMotorSlot].LimitPosPin := EdLimitPosPin.Text;
  a.Motors[FCurrentMotorSlot].LimitAllPin := EdLimitAllPin.Text;
  a.Motors[FCurrentMotorSlot].HardLimits := ChkHardLimits.Checked;
  a.Motors[FCurrentMotorSlot].PulloffMM := StrToFloatDef(EdPulloffMM.Text, a.Motors[FCurrentMotorSlot].PulloffMM);
  if CboDriverType.ItemIndex = 1 then
    a.Motors[FCurrentMotorSlot].DriverType := mdtStepStick
  else
    a.Motors[FCurrentMotorSlot].DriverType := mdtStandardStepper;
  a.Motors[FCurrentMotorSlot].StepPin := EdStepPin.Text;
  a.Motors[FCurrentMotorSlot].DirectionPin := EdDirectionPin.Text;
  a.Motors[FCurrentMotorSlot].DisablePin := EdDisablePin.Text;
  a.Motors[FCurrentMotorSlot].MS3Pin := EdMS3Pin.Text;
  // An edit made through this dialog always produces a modeled driver
  // block - any previously-preserved-verbatim unknown driver type is
  // superseded once the user has touched this motor here.
  a.Motors[FCurrentMotorSlot].UnknownDriverBlock := '';

  FConfig.SetAxis(FCurrentAxisIndex, a);
end;

procedure TAxesEditForm.LoadCurrentFromConfig;
var
  a: TAxisConfig;
  m: TAxisMotorConfig;
begin
  if (FCurrentAxisIndex < 0) or (FCurrentAxisIndex >= FConfig.Count) then Exit;
  FLoading := True;
  try
    a := FConfig.AxisAt(FCurrentAxisIndex);

    EdStepsPerMM.Text := FormatFloat('0.###', a.StepsPerMM);
    EdMaxRate.Text := FormatFloat('0.###', a.MaxRateMMPerMin);
    EdAcceleration.Text := FormatFloat('0.###', a.AccelerationMMPerSec2);
    EdMaxTravel.Text := FormatFloat('0.###', a.MaxTravelMM);
    ChkSoftLimits.Checked := a.SoftLimits;

    EdHomingCycle.Text := IntToStr(a.Homing.Cycle);
    ChkPositiveDirection.Checked := a.Homing.PositiveDirection;
    EdMposMM.Text := FormatFloat('0.###', a.Homing.MposMM);
    EdFeedRate.Text := FormatFloat('0.###', a.Homing.FeedMMPerMin);
    EdSeekRate.Text := FormatFloat('0.###', a.Homing.SeekMMPerMin);
    EdSettleMs.Text := IntToStr(a.Homing.SettleMs);
    EdSeekScaler.Text := FormatFloat('0.###', a.Homing.SeekScaler);
    EdFeedScaler.Text := FormatFloat('0.###', a.Homing.FeedScaler);

    m := a.Motors[FCurrentMotorSlot];
    if not m.Present then
    begin
      // Motor 1 not present yet on a currently-single-motor axis - offer
      // sensible blank/default starting values rather than stale data
      // from whatever motor was displayed a moment ago.
      m.LimitNegPin := 'NO_PIN';
      m.LimitPosPin := 'NO_PIN';
      m.LimitAllPin := 'NO_PIN';
      m.HardLimits := False;
      m.PulloffMM := 1.0;
      m.DriverType := mdtStandardStepper;
      m.StepPin := 'NO_PIN';
      m.DirectionPin := 'NO_PIN';
      m.DisablePin := 'NO_PIN';
      m.MS3Pin := 'NO_PIN';
    end;

    EdLimitNegPin.Text := m.LimitNegPin;
    EdLimitPosPin.Text := m.LimitPosPin;
    EdLimitAllPin.Text := m.LimitAllPin;
    ChkHardLimits.Checked := m.HardLimits;
    EdPulloffMM.Text := FormatFloat('0.###', m.PulloffMM);
    if m.DriverType = mdtStepStick then
      CboDriverType.ItemIndex := 1
    else
      CboDriverType.ItemIndex := 0;
    EdStepPin.Text := m.StepPin;
    EdDirectionPin.Text := m.DirectionPin;
    EdDisablePin.Text := m.DisablePin;
    EdMS3Pin.Text := m.MS3Pin;

    RefreshDriverFieldsEnabled;

    if m.UnknownDriverBlock <> '' then
      LblStatus.Caption := T('This motor uses a driver type this editor doesn''t model - saving here replaces it with the selected type below.')
    else
      LblStatus.Caption := '';
  finally
    FLoading := False;
  end;
end;

procedure TAxesEditForm.RefreshDriverFieldsEnabled;
begin
  // ms3_pin only exists on stepstick, not standard_stepper.
  EdMS3Pin.Enabled := CboDriverType.ItemIndex = 1;
end;

procedure TAxesEditForm.CboAxisChange(Sender: TObject);
begin
  if FLoading then Exit;
  SaveCurrentIntoConfig;
  FCurrentAxisIndex := CboAxis.ItemIndex;
  CboMotor.ItemIndex := 0;
  FCurrentMotorSlot := 0;
  LoadCurrentFromConfig;
end;

procedure TAxesEditForm.CboMotorChange(Sender: TObject);
begin
  if FLoading then Exit;
  SaveCurrentIntoConfig;
  FCurrentMotorSlot := CboMotor.ItemIndex;
  LoadCurrentFromConfig;
end;

procedure TAxesEditForm.CboDriverTypeChange(Sender: TObject);
begin
  RefreshDriverFieldsEnabled;
end;

procedure TAxesEditForm.BtnOKClick(Sender: TObject);
begin
  SaveCurrentIntoConfig;
  ModalResult := mrOK;
end;

end.
