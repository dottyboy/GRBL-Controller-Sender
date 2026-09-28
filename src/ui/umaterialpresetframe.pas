unit umaterialpresetframe;

{ TMaterialPresetFrame: the "Materials" tab (plan Phase 13) - a flat grid
  editor for a laser material library (name/material/power/speed/passes/
  notes), persisted via umaterialpresetstore.pas, structurally mirroring
  utoolsframe.pas's tool table (Add/Delete row + edit-in-place + a "Use"-
  style Apply action) rather than uspoilboardstore.pas's named-profile
  pattern - a material library is one flat list you pick FROM, not
  multiple named whole-configs.

  "Apply" fires OnApply so umain.pas can push the selected preset into
  TLaserControlFrame without this frame needing a direct dependency on it
  (same decoupling uspoilboardframe.pas's OnGenerated already uses). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, StdCtrls, ExtCtrls, Grids,
  umaterialpreset, umaterialpresetstore, ui18n;

const
  COL_NAME = 0;
  COL_MATERIAL = 1;
  COL_POWER = 2;
  COL_SPEED = 3;
  COL_PASSES = 4;
  COL_NOTES = 5;

type

  TApplyMaterialPresetEvent = procedure(const APreset: TMaterialPreset) of object;

  { TMaterialPresetFrame }

  TMaterialPresetFrame = class(TFrame)
    BtnAdd: TButton;
    BtnApply: TButton;
    BtnDelete: TButton;
    Grid: TStringGrid;
    ToolBar: TPanel;
    procedure BtnAddClick(Sender: TObject);
    procedure BtnApplyClick(Sender: TObject);
    procedure BtnDeleteClick(Sender: TObject);
    procedure GridEditingDone(Sender: TObject);
  private
    FStore: TMaterialPresetStore;
    FOnApply: TApplyMaterialPresetEvent;
    procedure LoadPresets;
    procedure SavePresets;
    function RowToPreset(ARow: Integer): TMaterialPreset;
    procedure PresetToRow(const APreset: TMaterialPreset; ARow: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property OnApply: TApplyMaterialPresetEvent read FOnApply write FOnApply;
  end;

implementation

{$R *.frm}

{ TMaterialPresetFrame }

constructor TMaterialPresetFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Grid.Cells[COL_NAME, 0] := 'Name';
  Grid.Cells[COL_MATERIAL, 0] := 'Material';
  Grid.Cells[COL_POWER, 0] := 'Power (S)';
  Grid.Cells[COL_SPEED, 0] := 'Speed (mm/min)';
  Grid.Cells[COL_PASSES, 0] := 'Passes';
  Grid.Cells[COL_NOTES, 0] := 'Notes';

  FStore := TMaterialPresetStore.Create(
    IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'materialpresets.ini');
  LoadPresets;
end;

destructor TMaterialPresetFrame.Destroy;
begin
  FStore.Free;
  inherited Destroy;
end;

function TMaterialPresetFrame.RowToPreset(ARow: Integer): TMaterialPreset;
begin
  Result.Name := Grid.Cells[COL_NAME, ARow];
  Result.Material := Grid.Cells[COL_MATERIAL, ARow];
  Result.Power := StrToFloatDef(Grid.Cells[COL_POWER, ARow], 100);
  Result.Speed := StrToFloatDef(Grid.Cells[COL_SPEED, ARow], 1000);
  Result.Passes := StrToIntDef(Grid.Cells[COL_PASSES, ARow], 1);
  Result.Notes := Grid.Cells[COL_NOTES, ARow];
end;

procedure TMaterialPresetFrame.PresetToRow(const APreset: TMaterialPreset; ARow: Integer);
begin
  Grid.Cells[COL_NAME, ARow] := APreset.Name;
  Grid.Cells[COL_MATERIAL, ARow] := APreset.Material;
  Grid.Cells[COL_POWER, ARow] := FloatToStr(APreset.Power);
  Grid.Cells[COL_SPEED, ARow] := FloatToStr(APreset.Speed);
  Grid.Cells[COL_PASSES, ARow] := IntToStr(APreset.Passes);
  Grid.Cells[COL_NOTES, ARow] := APreset.Notes;
end;

procedure TMaterialPresetFrame.LoadPresets;
var
  presets: TMaterialPresetArray;
  i: Integer;
  seed: TMaterialPreset;
begin
  presets := FStore.LoadAll;
  if Length(presets) = 0 then
  begin
    // Seed with one clearly-generic placeholder so the table isn't empty
    // on first run - NOT presented as a real, sourced material default
    // (unlike e.g. umachinecatalog_data.inc's sourced specs), since actual
    // power/speed values are too laser-wattage/lens/material-specific to
    // responsibly invent a "correct" number here - the user fills in their
    // own real values, same as utoolsframe.pas's single seeded tool row.
    seed := DefaultMaterialPreset;
    seed.Name := T('Example (edit me)');
    Grid.RowCount := 2;
    PresetToRow(seed, 1);
    Exit;
  end;

  Grid.RowCount := Max(2, Length(presets) + 1);
  for i := 0 to High(presets) do
    PresetToRow(presets[i], i + 1);
end;

procedure TMaterialPresetFrame.SavePresets;
var
  presets: TMaterialPresetArray;
  row, n: Integer;
begin
  SetLength(presets, Grid.RowCount - 1);
  n := 0;
  for row := 1 to Grid.RowCount - 1 do
  begin
    if Trim(Grid.Cells[COL_NAME, row]) = '' then Continue;
    presets[n] := RowToPreset(row);
    Inc(n);
  end;
  SetLength(presets, n);
  FStore.SaveAll(presets);
end;

procedure TMaterialPresetFrame.BtnAddClick(Sender: TObject);
begin
  Grid.RowCount := Grid.RowCount + 1;
  PresetToRow(DefaultMaterialPreset, Grid.RowCount - 1);
  SavePresets;
end;

procedure TMaterialPresetFrame.BtnDeleteClick(Sender: TObject);
begin
  if (Grid.RowCount > 2) and (Grid.Row >= 1) then
  begin
    Grid.DeleteRow(Grid.Row);
    SavePresets;
  end;
end;

procedure TMaterialPresetFrame.GridEditingDone(Sender: TObject);
begin
  SavePresets;
end;

procedure TMaterialPresetFrame.BtnApplyClick(Sender: TObject);
begin
  if Grid.Row < 1 then Exit;
  if Assigned(FOnApply) then
    FOnApply(RowToPreset(Grid.Row));
end;

end.
