unit ugenericgrbl;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ugenericcontroller;

type
  { TGenericGRBLController mirrors _GenericGRBL.py: GRBL-family command set
    (viewSettings/$$, viewBuild/$I, ...) and the full ERROR_CODES lookup
    table (error:N / ALARM:N / Hold:N / Door:N descriptions), shared by
    GRBL0 and GRBL1. }
  TGenericGRBLController = class(TGenericController)
  public
    procedure ViewSettings; virtual;
    procedure ViewBuild; virtual;
    procedure ViewStartup; virtual;
    procedure CheckGcode; virtual;
    procedure GrblRestoreSettings; virtual;
    procedure GrblRestoreWCS; virtual;
    function ErrorDescription(const ACode: string): string; override;
  end;

implementation

var
  ErrorCodes: TStringList;

procedure InitErrorCodes;
begin
  ErrorCodes := TStringList.Create;
  ErrorCodes.CaseSensitive := True;
  // Source: controllers/_GenericGRBL.py ERROR_CODES
  // (https://github.com/grbl/grbl/wiki/Interfacing-with-Grbl, grblHAL)
  with ErrorCodes do
  begin
    Values['Run'] := 'bCNC is currently sending a gcode program to Grbl';
    Values['Idle'] := 'Grbl is in idle state and waiting for user commands';
    Values['Hold'] := 'Grbl is on hold state. Click on resume (pause) to continue';
    Values['Alarm'] := 'Alarm is an emergency state - homing/reset is likely required';
    Values['Check'] := 'Grbl is in g-code check mode (no motion)';
    Values['Jog'] := 'Grbl executes jogging motion';
    Values['Sleep'] := 'Grbl is in sleep mode; motors disabled';
    Values['Queue'] := 'Grbl is in queue state (old GRBL version)';
    Values['Not connected'] := 'Please specify the correct port and click Open';
    Values['Connected'] := 'Connection is established with Grbl';
    Values['ok'] := 'Last line was understood and executed';
    Values['error:1'] := 'G-code words consist of a letter and a value. Letter was not found.';
    Values['error:2'] := 'Numeric value format is not valid or missing an expected value.';
    Values['error:3'] := 'Grbl ''$'' system command was not recognized or supported.';
    Values['error:4'] := 'Negative value received for an expected positive value.';
    Values['error:5'] := 'Homing cycle is not enabled via settings.';
    Values['error:6'] := 'Minimum step pulse time must be greater than 3usec';
    Values['error:7'] := 'EEPROM read failed. Reset and restored to default values.';
    Values['error:8'] := 'Grbl ''$'' command cannot be used unless Grbl is IDLE.';
    Values['error:9'] := 'G-code locked out during alarm or jog state';
    Values['error:10'] := 'Soft limits cannot be enabled without homing also enabled.';
    Values['error:11'] := 'Max characters per line exceeded. Line was not processed.';
    Values['error:12'] := '(Compile Option) $ setting value exceeds max step rate.';
    Values['error:13'] := 'Safety door detected as opened.';
    Values['error:14'] := '(Grbl-Mega) Build info/startup line exceeded EEPROM limit.';
    Values['error:15'] := 'Jog target exceeds machine travel. Command ignored.';
    Values['error:16'] := 'Jog command with no ''='' or contains prohibited g-code.';
    Values['error:17'] := 'Laser mode requires PWM output.';
    Values['error:20'] := 'Unsupported or invalid g-code command found in block.';
    Values['error:21'] := 'More than one g-code command from same modal group in block.';
    Values['error:22'] := 'Feed rate has not yet been set or is undefined.';
    Values['error:23'] := 'G-code command in block requires an integer value.';
    Values['error:24'] := 'Two G-code commands requiring XYZ axis words in same block.';
    Values['error:25'] := 'A G-code word was repeated in the block.';
    Values['error:26'] := 'Required XYZ axis words missing in block.';
    Values['error:27'] := 'N line number not within valid range 1 - 9,999,999.';
    Values['error:28'] := 'G-code command missing required P or L value word.';
    Values['error:29'] := 'G59.1/.2/.3 are not supported.';
    Values['error:30'] := 'G53 requires an active G0 seek or G1 feed motion mode.';
    Values['error:31'] := 'Unused axis words present with G80 motion mode cancel active.';
    Values['error:32'] := 'G2/G3 arc commanded with no XYZ words in selected plane.';
    Values['error:33'] := 'Motion command has an invalid target.';
    Values['error:34'] := 'G2/G3 arc (radius def.) had a math error computing geometry.';
    Values['error:35'] := 'G2/G3 arc (offset def.) missing IJK offset word.';
    Values['error:36'] := 'Unused leftover G-code words not used by any command.';
    Values['error:37'] := 'G43.1 dynamic TLO cannot apply offset to non-configured axis.';
    Values['error:38'] := 'Tool number greater than max/undefined tool. (grblHAL)';
    Values['error:39'] := 'Value out of range. (grblHAL)';
    Values['error:40'] := 'G-code not allowed when tool change pending. (grblHAL)';
    Values['error:41'] := 'Spindle not running when motion commanded in CSS mode. (grblHAL)';
    Values['error:42'] := 'Plane must be ZX for threading. (grblHAL)';
    Values['error:43'] := 'Max. feed rate exceeded. (grblHAL)';
    Values['error:44'] := 'RPM out of range. (grblHAL)';
    Values['error:45'] := 'Only homing allowed when a limit switch is engaged. (grblHAL)';
    Values['error:46'] := 'Home machine to continue. (grblHAL)';
    Values['error:47'] := 'ATC: current tool not set. Set with M61. (grblHAL)';
    Values['error:48'] := 'Value word conflict. (grblHAL)';
    Values['error:50'] := 'Emergency stop active. (grblHAL)';
    Values['error:55'] := 'Attempt to home two auto squared axes at the same time. (grblHAL)';
    Values['ALARM:1'] := 'Hard limit triggered. Re-homing highly recommended.';
    Values['ALARM:2'] := 'G-code motion target exceeds machine travel.';
    Values['ALARM:3'] := 'Reset while in motion. Lost steps likely; re-home.';
    Values['ALARM:4'] := 'Probe fail: probe not in expected initial state.';
    Values['ALARM:5'] := 'Probe fail: probe did not contact workpiece within travel.';
    Values['ALARM:6'] := 'Homing fail: reset during active homing cycle.';
    Values['ALARM:7'] := 'Homing fail: safety door opened during homing cycle.';
    Values['ALARM:8'] := 'Homing fail: cycle failed to clear limit switch on pull-off.';
    Values['ALARM:9'] := 'Homing fail: could not find limit switch within search distance.';
    Values['ALARM:10'] := 'EStop asserted. Clear and reset. (grblHAL)';
    Values['ALARM:11'] := 'Homing required. Execute $H to continue. (grblHAL)';
    Values['ALARM:12'] := 'Limit switch engaged. Clear before continuing. (grblHAL)';
    Values['ALARM:15'] := 'Homing fail. Could not find second limit switch for auto squared axis within search distances. Try increasing max travel, decreasing pull-off distance, or check wiring. (grblHAL)';
    Values['Hold:0'] := 'Hold complete. Ready to resume.';
    Values['Hold:1'] := 'Hold in-progress. Reset will throw an alarm.';
    Values['Door:0'] := 'Door closed. Ready to resume.';
    Values['Door:1'] := 'Machine stopped. Door still ajar. Can''t resume until closed.';
    Values['Door:2'] := 'Door opened. Hold in-progress. Reset will throw an alarm.';
    Values['Door:3'] := 'Door closed and resuming. Reset will throw an alarm.';
  end;
end;

{ TGenericGRBLController }

procedure TGenericGRBLController.ViewSettings;
begin
  FHost.SendGCode('$$');
end;

procedure TGenericGRBLController.ViewBuild;
begin
  FHost.SendGCode('$I');
end;

procedure TGenericGRBLController.ViewStartup;
begin
  FHost.SendGCode('$N');
end;

procedure TGenericGRBLController.CheckGcode;
begin
  FHost.SendGCode('$C');
end;

procedure TGenericGRBLController.GrblRestoreSettings;
begin
  FHost.SendGCode('$RST=$');
end;

procedure TGenericGRBLController.GrblRestoreWCS;
begin
  FHost.SendGCode('$RST=#');
end;

function TGenericGRBLController.ErrorDescription(const ACode: string): string;
var
  idx: Integer;
begin
  idx := ErrorCodes.IndexOfName(ACode);
  if idx >= 0 then
    Result := ErrorCodes.ValueFromIndex[idx]
  else
    Result := ACode;
end;

initialization
  InitErrorCodes;

finalization
  ErrorCodes.Free;

end.
