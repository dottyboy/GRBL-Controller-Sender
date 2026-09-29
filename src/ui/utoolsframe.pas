unit utoolsframe;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, StdCtrls, ExtCtrls, Grids, IniFiles,
  usender, utoolbits, uparametrictoolform;

const
  COL_NAME = 0;
  COL_DIAMETER = 1;
  COL_FLUTES = 2;
  COL_LENGTH = 3;
  COL_STEPOVER = 4;
  COL_COMMENT = 5;

type

  { TToolsFrame: a simple tool table (bCNC ToolsPage.py's EndMill database,
    trimmed to the fields that matter for streaming: diameter and stepover
    feed into TCNCState so jogging/canvas code can use them). Persisted as
    a flat ini file, one section per tool row. }
  TToolsFrame = class(TFrame)
    BtnAdd: TButton;
    BtnDelete: TButton;
    BtnLoadPreset: TButton;
    BtnParametric: TButton;
    BtnUse: TButton;
    CboPreset: TComboBox;
    Grid: TStringGrid;
    ToolBar: TPanel;
    procedure BtnAddClick(Sender: TObject);
    procedure BtnDeleteClick(Sender: TObject);
    procedure BtnLoadPresetClick(Sender: TObject);
    procedure BtnParametricClick(Sender: TObject);
    procedure BtnUseClick(Sender: TObject);
    procedure GridEditingDone(Sender: TObject);
  private
    FSender: TSender;
    FFileName: string;
    procedure LoadTools;
    procedure SaveTools;
    function AddBlankRow: Integer;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetSender(ASender: TSender);
  end;

implementation

{$R *.frm}

{ TToolsFrame }

constructor TToolsFrame.Create(AOwner: TComponent);
var
  i: Integer;
begin
  inherited Create(AOwner);
  Grid.Cells[COL_NAME, 0] := 'Name';
  Grid.Cells[COL_DIAMETER, 0] := 'Diam (mm)';
  Grid.Cells[COL_FLUTES, 0] := 'Flutes';
  Grid.Cells[COL_LENGTH, 0] := 'Length';
  Grid.Cells[COL_STEPOVER, 0] := 'Stepover %';
  Grid.Cells[COL_COMMENT, 0] := 'Comment';

  for i := 0 to PresetCount - 1 do
    CboPreset.Items.Add(GetPreset(i).Name);
  if CboPreset.Items.Count > 0 then
    CboPreset.ItemIndex := 0;

  FFileName := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'tools.ini';
  LoadTools;
end;

procedure TToolsFrame.SetSender(ASender: TSender);
begin
  FSender := ASender;
end;

procedure TToolsFrame.LoadTools;
var
  ini: TIniFile;
  sections: TStringList;
  i, row: Integer;
begin
  if not FileExists(FFileName) then
  begin
    // Seed with one sensible default so the table isn't empty on first run.
    Grid.RowCount := 2;
    Grid.Cells[COL_NAME, 1] := '3.175mm 2-flute';
    Grid.Cells[COL_DIAMETER, 1] := '3.175';
    Grid.Cells[COL_FLUTES, 1] := '2';
    Grid.Cells[COL_LENGTH, 1] := '20';
    Grid.Cells[COL_STEPOVER, 1] := '40';
    Grid.Cells[COL_COMMENT, 1] := '';
    Exit;
  end;

  ini := TIniFile.Create(FFileName);
  sections := TStringList.Create;
  try
    ini.ReadSections(sections);
    Grid.RowCount := Max(2, sections.Count + 1);
    for i := 0 to sections.Count - 1 do
    begin
      row := i + 1;
      Grid.Cells[COL_NAME, row] := ini.ReadString(sections[i], 'name', sections[i]);
      Grid.Cells[COL_DIAMETER, row] := ini.ReadString(sections[i], 'diameter', '3.175');
      Grid.Cells[COL_FLUTES, row] := ini.ReadString(sections[i], 'flutes', '2');
      Grid.Cells[COL_LENGTH, row] := ini.ReadString(sections[i], 'length', '20');
      Grid.Cells[COL_STEPOVER, row] := ini.ReadString(sections[i], 'stepover', '40');
      Grid.Cells[COL_COMMENT, row] := ini.ReadString(sections[i], 'comment', '');
    end;
  finally
    sections.Free;
    ini.Free;
  end;
end;

procedure TToolsFrame.SaveTools;
var
  ini: TIniFile;
  row: Integer;
  section: string;
begin
  if FileExists(FFileName) then
    DeleteFile(FFileName);
  ForceDirectories(ExtractFileDir(FFileName));
  ini := TIniFile.Create(FFileName);
  try
    for row := 1 to Grid.RowCount - 1 do
    begin
      if Trim(Grid.Cells[COL_NAME, row]) = '' then Continue;
      section := 'tool' + IntToStr(row);
      ini.WriteString(section, 'name', Grid.Cells[COL_NAME, row]);
      ini.WriteString(section, 'diameter', Grid.Cells[COL_DIAMETER, row]);
      ini.WriteString(section, 'flutes', Grid.Cells[COL_FLUTES, row]);
      ini.WriteString(section, 'length', Grid.Cells[COL_LENGTH, row]);
      ini.WriteString(section, 'stepover', Grid.Cells[COL_STEPOVER, row]);
      ini.WriteString(section, 'comment', Grid.Cells[COL_COMMENT, row]);
    end;
  finally
    ini.Free;
  end;
end;

function TToolsFrame.AddBlankRow: Integer;
begin
  Grid.RowCount := Grid.RowCount + 1;
  Result := Grid.RowCount - 1;
  Grid.Cells[COL_NAME, Result] := 'New tool';
  Grid.Cells[COL_DIAMETER, Result] := '3.175';
  Grid.Cells[COL_FLUTES, Result] := '2';
  Grid.Cells[COL_LENGTH, Result] := '20';
  Grid.Cells[COL_STEPOVER, Result] := '40';
end;

procedure TToolsFrame.BtnAddClick(Sender: TObject);
begin
  AddBlankRow;
  SaveTools;
end;

procedure TToolsFrame.BtnLoadPresetClick(Sender: TObject);
var
  preset: TToolBitPreset;
  row: Integer;
begin
  if CboPreset.ItemIndex < 0 then Exit;
  preset := GetPreset(CboPreset.ItemIndex);
  row := AddBlankRow;
  Grid.Cells[COL_NAME, row] := preset.Name;
  Grid.Cells[COL_DIAMETER, row] := FormatFloat('0.###', preset.Params.Diameter);
  Grid.Cells[COL_LENGTH, row] := FormatFloat('0.#', preset.Params.Length);
  Grid.Cells[COL_COMMENT, row] := DescribeToolBit(preset.Shape, preset.Params);
  Grid.Row := row;
  SaveTools;
end;

procedure TToolsFrame.BtnParametricClick(Sender: TObject);
var
  frm: TParametricToolForm;
  row: Integer;
begin
  frm := TParametricToolForm.Create(Self);
  try
    if frm.ShowModal = mrOK then
    begin
      row := AddBlankRow;
      Grid.Cells[COL_NAME, row] := frm.GetToolName;
      Grid.Cells[COL_DIAMETER, row] := FormatFloat('0.###', frm.GetDiameter);
      Grid.Cells[COL_COMMENT, row] := frm.GetToolComment;
      Grid.Row := row;
      SaveTools;
    end;
  finally
    frm.Free;
  end;
end;

procedure TToolsFrame.BtnDeleteClick(Sender: TObject);
begin
  if (Grid.RowCount > 2) and (Grid.Row >= 1) then
  begin
    Grid.DeleteRow(Grid.Row);
    SaveTools;
  end;
end;

procedure TToolsFrame.BtnUseClick(Sender: TObject);
var
  row: Integer;
begin
  if FSender = nil then Exit;
  row := Grid.Row;
  if row < 1 then Exit;
  FSender.State.Diameter := StrToFloatDef(Grid.Cells[COL_DIAMETER, row], FSender.State.Diameter);
  // stepover % is read directly from the grid by any future CAM feature;
  // no dedicated TCNCState field for it yet (mirrors bCNC's cnc()["stepover"]).
end;

procedure TToolsFrame.GridEditingDone(Sender: TObject);
begin
  SaveTools;
end;

end.
