unit umaterialpreset;

{ TMaterialPreset: one saved laser material setting (plan Phase 13) - LCL-
  free so both the ini-backed store (umaterialpresetstore.pas) and the grid
  UI (umaterialpresetframe.pas) share one plain-data definition. }

{$mode objfpc}{$H+}

interface

type
  TMaterialPreset = record
    Name: string;
    Material: string;    // free text (e.g. "Plywood 3mm"), not an enum - the
                          // real range of laser materials/thicknesses is too
                          // open-ended to model as a fixed list
    Power: Double;        // raw S word value - same convention as
                          // ulasercontrolframe.pas's Test Fire power field.
                          // Deliberately NOT a percent: converting a percent
                          // to a real S value needs the connected board's
                          // actual $30 max-S setting, which isn't reliably
                          // known ahead of connecting - see the plan note.
    Speed: Double;         // mm/min (F word value)
    Passes: Integer;
    Notes: string;
  end;

  TMaterialPresetArray = array of TMaterialPreset;

function DefaultMaterialPreset: TMaterialPreset;

implementation

function DefaultMaterialPreset: TMaterialPreset;
begin
  Result.Name := 'New material';
  Result.Material := '';
  Result.Power := 100;
  Result.Speed := 1000;
  Result.Passes := 1;
  Result.Notes := '';
end;

end.
