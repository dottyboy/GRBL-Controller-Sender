unit uaxiscalibration;

{ Pure axis steps/mm calibration math (plan Phase 24), concept from
  OpenBuilds CONTROL's own calibration wizard
  (app/wizards/calibration/calibrate-x.js, -y.js, -z.js, read directly): jog a
  known distance, hand-measure the actual real-world distance moved, and
  correct GRBL's $100/$101/$102 by the same ratio OpenBuilds itself uses -
    newsteps = currentsteps * (requested / actual)
  (see calibrate-x.js's own applycalibrationx(), identical for Y/$101 and
  Z/$102). No LCL/BGRA dependency here - the UI form
  (uaxiscalibrationform.pas) owns the Jog/WriteSetting calls, this unit
  only owns the math and the axis-letter<->setting-ID mapping.

  OpenBuilds CONTROL's servo pen-up/pen-down calibration
  (calibrate-servo.js) is deliberately NOT ported - it calibrates M3 S-word
  positions for a pen-plotter servo, a concept with no equivalent in this
  laser/CNC app (no $10x setting involved at all). }

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

// AxisStepsSettingID: 'X'/'Y'/'Z' (case-insensitive) -> GRBL $100/$101/
// $102, '' for anything else.
function AxisStepsSettingID(AAxis: Char): string;

// TryCalibrateStepsPerMM: newsteps = current * (requested / measured),
// mirroring OpenBuilds CONTROL's applycalibrationx() exactly. False
// (ANewStepsPerMM left unset) if either distance is zero or negative -
// nothing sane to compute.
function TryCalibrateStepsPerMM(ACurrentStepsPerMM, ARequestedDistanceMM,
  AMeasuredDistanceMM: Double; out ANewStepsPerMM: Double): Boolean;

// JogDistanceString: 'X' + 100 -> 'X100' - matches ujogframe.pas's own
// Format('%s%g', ...) positive-direction convention, i.e. exactly what
// TSender.Jog expects (TGRBL1Controller.Jog wraps it as
// "$J=G91 <this> F100000").
function JogDistanceString(AAxis: Char; ADistanceMM: Double): string;

implementation

function AxisStepsSettingID(AAxis: Char): string;
begin
  case UpCase(AAxis) of
    'X': Result := '100';
    'Y': Result := '101';
    'Z': Result := '102';
  else
    Result := '';
  end;
end;

function TryCalibrateStepsPerMM(ACurrentStepsPerMM, ARequestedDistanceMM,
  AMeasuredDistanceMM: Double; out ANewStepsPerMM: Double): Boolean;
begin
  Result := (ARequestedDistanceMM > 0) and (AMeasuredDistanceMM > 0);
  if Result then
    ANewStepsPerMM := ACurrentStepsPerMM * (ARequestedDistanceMM / AMeasuredDistanceMM);
end;

function JogDistanceString(AAxis: Char; ADistanceMM: Double): string;
begin
  Result := UpCase(AAxis) + Format('%g', [ADistanceMM]);
end;

end.
