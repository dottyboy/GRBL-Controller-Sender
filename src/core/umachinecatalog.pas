unit umachinecatalog;

{ umachinecatalog: curated catalog of real, named CNC machine models (mostly
  Chinese manufacturers, plus a few well-known others) with their real work
  area/travel and drive type - so the Spoilboard tab (and, later, other
  places that care about machine geometry) can offer a "Machine preset"
  instead of the user typing dimensions from memory.

  Every entry here is sourced from the manufacturer's own product page or
  an official spec sheet (see Notes for caveats where a number wasn't
  published or is a size shared across a product family, not independently
  confirmed per size) - no invented/guessed dimensions, matching this
  project's existing board-catalog discipline (see uboardcatalog.pas).
  TravelZ = 0 means "not published", never a real zero-travel machine -
  callers must check for that before trusting/showing it as a hard number. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ui18n;

type
  TDriveType = (dtBelt, dtLeadscrew, dtBallscrew);

  TMachineProfile = record
    DisplayName: string;   // shown in the preset dropdown, already unique
    Manufacturer: string;
    FamilyGroup: string;   // groups size variants of the same product line
    TravelX: Double;       // mm
    TravelY: Double;       // mm
    TravelZ: Double;       // mm; 0 = not published (see unit comment)
    Drive: TDriveType;     // the X/Y drive, or the machine's primary one
    DriveNote: string;     // e.g. a different Z-axis drive type
    Controller: string;    // stock controller/firmware, free text
    Notes: string;         // sourcing caveats
  end;

  TMachineProfileArray = array of TMachineProfile;

function MachineCatalog: TMachineProfileArray;
function FindMachineProfile(const ADisplayName: string; out AProfile: TMachineProfile): Boolean;
function DriveTypeName(ADrive: TDriveType): string;

implementation

{$I umachinecatalog_data.inc}

function MachineCatalog: TMachineProfileArray;
begin
  Result := Catalog;
end;

function FindMachineProfile(const ADisplayName: string; out AProfile: TMachineProfile): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(Catalog) do
    if Catalog[i].DisplayName = ADisplayName then
    begin
      AProfile := Catalog[i];
      Result := True;
      Exit;
    end;
end;

function DriveTypeName(ADrive: TDriveType): string;
begin
  case ADrive of
    dtBelt: Result := T('belt');
    dtLeadscrew: Result := T('leadscrew (ACME)');
    dtBallscrew: Result := T('ball screw (linear)');
  else
    Result := '?';
  end;
end;

end.
