unit usettinghelp;

{ usettinghelp: plan Phase 18 - human-readable $-setting descriptions for
  boards that DON'T implement grblHAL's $ES ("enumerate settings")
  extension (see usettingsmeta.pas/Phase F2, which already covers boards
  that DO). Vanilla grbl 1.1 and its close forks (Ortur, Longer, etc.)
  never gained a machine-readable settings-description wire format, so
  the only way to show these at all is a baked-in table - the exact same
  "real, sourced, baked-in const data" pattern already used by
  ui18n_data.inc and umachinecatalog_data.inc in this project.

  NOT invented: transcribed directly from LaserGRBL's own real
  CSV/setting_codes.v1.1.csv (34 rows, grbl 1.1's real published $-setting
  list, name/units/description columns) - not guessed, not paraphrased.
  Deliberately does NOT duplicate ugenericgrbl.pas's ErrorCodes table -
  that one describes STATUS/error:/ALARM: codes (a different, already-
  covered wire format), this one describes plain $N=value settings,
  which had no description source anywhere in this app before. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

// Returns '' if AID isn't a known grbl 1.1 setting (e.g. a grblHAL-only
// or vendor-specific ID - those are exactly what $ES/usettingsmeta.pas
// is for instead).
function SettingDescription(AID: Integer): string;
function SettingName(AID: Integer): string;
function SettingUnits(AID: Integer): string;

implementation

type
  TSettingHelpRow = record
    ID: Integer;
    Name: string;
    Units: string;
    Description: string;
  end;

const
  // Source: LaserGRBL CSV/setting_codes.v1.1.csv, transcribed verbatim.
  Rows: array[0..33] of TSettingHelpRow = (
    (ID: 0;   Name: 'Step pulse time';               Units: 'microseconds'; Description: 'Sets time length per step. Minimum 3usec.'),
    (ID: 1;   Name: 'Step idle delay';                Units: 'milliseconds'; Description: 'Sets a short hold delay when stopping to let dynamics settle before disabling steppers. Value 255 keeps motors enabled with no delay.'),
    (ID: 2;   Name: 'Step pulse invert';               Units: 'mask'; Description: 'Inverts the step signal. Set axis bit to invert (00000ZYX).'),
    (ID: 3;   Name: 'Step direction invert';           Units: 'mask'; Description: 'Inverts the direction signal. Set axis bit to invert (00000ZYX).'),
    (ID: 4;   Name: 'Invert step enable pin';          Units: 'boolean'; Description: 'Inverts the stepper driver enable pin signal.'),
    (ID: 5;   Name: 'Invert limit pins';               Units: 'boolean'; Description: 'Inverts all of the limit input pins.'),
    (ID: 6;   Name: 'Invert probe pin';                Units: 'boolean'; Description: 'Inverts the probe input pin signal.'),
    (ID: 10;  Name: 'Status report options';           Units: 'mask'; Description: 'Alters data included in status reports.'),
    (ID: 11;  Name: 'Junction deviation';              Units: 'millimeters'; Description: 'Sets how fast Grbl travels through consecutive motions. Lower value slows it down.'),
    (ID: 12;  Name: 'Arc tolerance';                   Units: 'millimeters'; Description: 'Sets the G2 and G3 arc tracing accuracy based on radial error. Beware: A very small value may effect performance.'),
    (ID: 13;  Name: 'Report in inches';                Units: 'boolean'; Description: 'Enables inch units when returning any position and rate value that is not a settings value.'),
    (ID: 20;  Name: 'Soft limits enable';              Units: 'boolean'; Description: 'Enables soft limits checks within machine travel and sets alarm when exceeded. Requires homing.'),
    (ID: 21;  Name: 'Hard limits enable';              Units: 'boolean'; Description: 'Enables hard limits. Immediately halts motion and throws an alarm when switch is triggered.'),
    (ID: 22;  Name: 'Homing cycle enable';             Units: 'boolean'; Description: 'Enables homing cycle. Requires limit switches on all axes.'),
    (ID: 23;  Name: 'Homing direction invert';         Units: 'mask'; Description: 'Homing searches for a switch in the positive direction. Set axis bit (00000ZYX) to search in negative direction.'),
    (ID: 24;  Name: 'Homing locate feed rate';         Units: 'mm/min'; Description: 'Feed rate to slowly engage limit switch to determine its location accurately.'),
    (ID: 25;  Name: 'Homing search seek rate';         Units: 'mm/min'; Description: 'Seek rate to quickly find the limit switch before the slower locating phase.'),
    (ID: 26;  Name: 'Homing switch debounce delay';    Units: 'milliseconds'; Description: 'Sets a short delay between phases of homing cycle to let a switch debounce.'),
    (ID: 27;  Name: 'Homing switch pull-off distance'; Units: 'millimeters'; Description: 'Retract distance after triggering switch to disengage it. Homing will fail if switch isn''t cleared.'),
    (ID: 30;  Name: 'Maximum spindle speed';           Units: 'RPM'; Description: 'Maximum spindle speed. Sets PWM to 100% duty cycle.'),
    (ID: 31;  Name: 'Minimum spindle speed';           Units: 'RPM'; Description: 'Minimum spindle speed. Sets PWM to 0.4% or lowest duty cycle.'),
    (ID: 32;  Name: 'Laser-mode enable';               Units: 'boolean'; Description: 'Enables laser mode. Consecutive G1/2/3 commands will not halt when spindle speed is changed.'),
    (ID: 100; Name: 'X-axis travel resolution';        Units: 'step/mm'; Description: 'X-axis travel resolution in steps per millimeter.'),
    (ID: 101; Name: 'Y-axis travel resolution';        Units: 'step/mm'; Description: 'Y-axis travel resolution in steps per millimeter.'),
    (ID: 102; Name: 'Z-axis travel resolution';        Units: 'step/mm'; Description: 'Z-axis travel resolution in steps per millimeter.'),
    (ID: 110; Name: 'X-axis maximum rate';             Units: 'mm/min'; Description: 'X-axis maximum rate. Used as G0 rapid rate.'),
    (ID: 111; Name: 'Y-axis maximum rate';             Units: 'mm/min'; Description: 'Y-axis maximum rate. Used as G0 rapid rate.'),
    (ID: 112; Name: 'Z-axis maximum rate';             Units: 'mm/min'; Description: 'Z-axis maximum rate. Used as G0 rapid rate.'),
    (ID: 120; Name: 'X-axis acceleration';             Units: 'mm/sec^2'; Description: 'X-axis acceleration. Used for motion planning to not exceed motor torque and lose steps.'),
    (ID: 121; Name: 'Y-axis acceleration';             Units: 'mm/sec^2'; Description: 'Y-axis acceleration. Used for motion planning to not exceed motor torque and lose steps.'),
    (ID: 122; Name: 'Z-axis acceleration';             Units: 'mm/sec^2'; Description: 'Z-axis acceleration. Used for motion planning to not exceed motor torque and lose steps.'),
    (ID: 130; Name: 'X-axis maximum travel';           Units: 'millimeters'; Description: 'Maximum X-axis travel distance from homing switch. Determines valid machine space for soft-limits and homing search distances.'),
    (ID: 131; Name: 'Y-axis maximum travel';           Units: 'millimeters'; Description: 'Maximum Y-axis travel distance from homing switch. Determines valid machine space for soft-limits and homing search distances.'),
    (ID: 132; Name: 'Z-axis maximum travel';           Units: 'millimeters'; Description: 'Maximum Z-axis travel distance from homing switch. Determines valid machine space for soft-limits and homing search distances.')
  );

function FindRow(AID: Integer): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(Rows) do
    if Rows[i].ID = AID then
    begin
      Result := i;
      Exit;
    end;
end;

function SettingDescription(AID: Integer): string;
var
  idx: Integer;
begin
  idx := FindRow(AID);
  if idx >= 0 then Result := Rows[idx].Description
  else Result := '';
end;

function SettingName(AID: Integer): string;
var
  idx: Integer;
begin
  idx := FindRow(AID);
  if idx >= 0 then Result := Rows[idx].Name
  else Result := '';
end;

function SettingUnits(AID: Integer): string;
var
  idx: Integer;
begin
  idx := FindRow(AID);
  if idx >= 0 then Result := Rows[idx].Units
  else Result := '';
end;

end.
