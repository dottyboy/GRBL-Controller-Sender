unit uheaderfooterpreset;

{ uheaderfooterpreset: named Header/Footer presets (plan Phase 37),
  reachable from both Laser Control and the Editor tab - the same
  "Load preset..." shape already established by Phase 13 (materials)
  and Phase 26 (settings templates): picking one fills the relevant
  Header/Footer fields, nothing sent until the user actually starts/
  sends the job.

  Real source, not guessed: LaserGRBL's own `Core/GrblCore.cs` auto-
  pushes a real default pair at program-push time -
  `GCODE_STD_HEADER = "G90 (use absolute coordinates)"`,
  `GCODE_STD_FOOTER = "G0 X0 Y0 Z0 (move back to origin)"` - ported as
  this app's own built-in seed entry, used for BOTH laser and plain CNC
  jobs now that the mechanism is shared (G90/return-to-origin are
  equally sensible defaults for a plain CNC job, not laser-specific).

  The rest of the built-in set is individually real/documented, not
  padded for volume: M7/M8 (mist/flood coolant - air-assist, in
  practice, for a laser) before a job + M9 after are real GRBL M-codes
  already in this project's own usettinghelp.pas table; $H (homing) is
  GRBL's own real homing command; a safe-Z-retract-before-park uses
  G53 G0 Z0 (machine-coordinate rapid to Z0, GRBL's own real documented
  "G53 lets you use machine coordinates for exactly one line" feature -
  the standard, safe way to retract without needing to know the work
  offset). }

{$mode objfpc}{$H+}

interface

type
  { THFKind: which job kind(s) a preset makes sense for - metadata only,
    lets the picker UI filter/label sensibly without needing two
    separate preset lists (plan's own explicit requirement). }
  THFKind = (hfkUniversal, hfkLaser, hfkCNC);

  THeaderFooterPreset = record
    Name: string;
    Header: string; // one or more lines, joined by LineEnding
    Footer: string;
    Kind: THFKind;
  end;

  THeaderFooterPresetArray = array of THeaderFooterPreset;

function BuiltInPresetCount: Integer;
function GetBuiltInPreset(AIndex: Integer): THeaderFooterPreset;
function KindName(AKind: THFKind): string;

implementation

uses
  SysUtils;

const
  PRESET_COUNT = 4;

var
  GPresets: array[0..PRESET_COUNT - 1] of THeaderFooterPreset;

function KindName(AKind: THFKind): string;
begin
  case AKind of
    hfkLaser: Result := 'Laser';
    hfkCNC: Result := 'CNC';
  else
    Result := 'Universal';
  end;
end;

function BuiltInPresetCount: Integer;
begin
  Result := PRESET_COUNT;
end;

function GetBuiltInPreset(AIndex: Integer): THeaderFooterPreset;
begin
  Result := GPresets[AIndex];
end;

procedure Seed(AIndex: Integer; const AName, AHeader, AFooter: string; AKind: THFKind);
begin
  GPresets[AIndex].Name := AName;
  GPresets[AIndex].Header := AHeader;
  GPresets[AIndex].Footer := AFooter;
  GPresets[AIndex].Kind := AKind;
end;

initialization
  // LaserGRBL's own real default pair (GrblCore.cs GCODE_STD_HEADER/FOOTER).
  Seed(0, 'LaserGRBL default', 'G90 (use absolute coordinates)',
    'G0 X0 Y0 Z0 (move back to origin)', hfkUniversal);

  Seed(1, 'Air assist on/off', 'M8 (air assist on)', 'M9 (air assist off)', hfkLaser);

  Seed(2, 'Home before start', '$H (home all axes)', '', hfkUniversal);

  Seed(3, 'Safe Z park', '', 'G53 G0 Z0 (rapid to machine Z0, safe park)', hfkCNC);

end.
