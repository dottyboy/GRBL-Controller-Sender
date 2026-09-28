unit uprobeframe;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Grids, Dialogs,
  usender, uprobe, ui18n;

type

  { TProbeFrame }

  TProbeFrame = class(TFrame)
    BtnLoad: TButton;
    BtnSave: TButton;
    BtnScan: TButton;
    BtnTouchProbe: TButton;
    BtnZero: TButton;
    CboEdgeAxis: TComboBox;
    CboProbeType: TComboBox;
    ConfigPanel: TPanel;
    EdFeed: TEdit;
    EdSafeZ: TEdit;
    EdTPDiameter: TEdit;
    EdTPRetract: TEdit;
    EdTPSearchDist: TEdit;
    EdTPZOffset: TEdit;
    EdXMax: TEdit;
    EdXMin: TEdit;
    EdXN: TEdit;
    EdYMax: TEdit;
    EdYMin: TEdit;
    EdYN: TEdit;
    EdZMax: TEdit;
    EdZMin: TEdit;
    Grid: TStringGrid;
    LblFeed: TLabel;
    LblGrid: TLabel;
    LblSafeZ: TLabel;
    LblStatus: TLabel;
    LblTPDiameter: TLabel;
    LblTPRetract: TLabel;
    LblTPSearchDist: TLabel;
    LblTPZOffset: TLabel;
    LblTouchStatus: TLabel;
    LblXRange: TLabel;
    LblYRange: TLabel;
    LblZRange: TLabel;
    TouchProbePanel: TPanel;
    procedure BtnScanClick(Sender: TObject);
    procedure BtnTouchProbeClick(Sender: TObject);
    procedure BtnZeroClick(Sender: TObject);
    procedure BtnSaveClick(Sender: TObject);
    procedure BtnLoadClick(Sender: TObject);
    procedure CboProbeTypeChange(Sender: TObject);
  private
    FSender: TSender;
    FGrid: TProbeGrid;
    FTouchProbe: TTouchProbe;
    FSaveDialog: TSaveDialog;
    FOpenDialog: TOpenDialog;
    procedure RefreshGridDisplay;
    procedure RefreshStatus;
    procedure RefreshTouchProbeMode;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetSender(ASender: TSender);
    procedure HandleProbeResult(Sender: TObject; AX, AY, AZ: Double);
  end;

implementation

{$R *.frm}

{ TProbeFrame }

constructor TProbeFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FGrid := TProbeGrid.Create;
  FTouchProbe := TTouchProbe.Create;
  FSaveDialog := TSaveDialog.Create(Self);
  FSaveDialog.Filter := 'Probe grid files (*.probe)|*.probe|All files (*.*)|*.*';
  FSaveDialog.DefaultExt := 'probe';
  FOpenDialog := TOpenDialog.Create(Self);
  FOpenDialog.Filter := FSaveDialog.Filter;
  RefreshStatus;
  RefreshTouchProbeMode;
end;

destructor TProbeFrame.Destroy;
begin
  FTouchProbe.Free;
  FGrid.Free;
  inherited Destroy;
end;

procedure TProbeFrame.SetSender(ASender: TSender);
begin
  FSender := ASender;
  if FSender <> nil then
    FSender.OnProbeResult := @HandleProbeResult;
end;

procedure TProbeFrame.RefreshStatus;
begin
  if FGrid.IsEmpty then
    LblStatus.Caption := T('Grid not started')
  else if FGrid.IsComplete then
    LblStatus.Caption := Format('Complete: %d/%d points', [FGrid.PointCount, FGrid.XN * FGrid.YN])
  else
    LblStatus.Caption := Format('Probing: %d/%d points', [FGrid.PointCount, FGrid.XN * FGrid.YN]);
end;

procedure TProbeFrame.RefreshGridDisplay;
var
  i, j: Integer;
begin
  if FGrid.IsEmpty then
  begin
    Grid.ColCount := 2;
    Grid.RowCount := 2;
    Exit;
  end;
  Grid.ColCount := FGrid.XN;
  Grid.RowCount := FGrid.YN;
  for j := 0 to FGrid.YN - 1 do
    for i := 0 to FGrid.XN - 1 do
      // Display row 0 as the highest Y (matches typical top-down layout)
      Grid.Cells[i, FGrid.YN - 1 - j] := Format('%.3f', [FGrid.MatrixValue(j, i)]);
end;

procedure TProbeFrame.BtnScanClick(Sender: TObject);
var
  lines: TStringList;
begin
  if FSender = nil then Exit;
  if not FSender.Connected then
  begin
    LblStatus.Caption := T('Not connected');
    Exit;
  end;

  FGrid.Configure(
    StrToFloatDef(EdXMin.Text, 0), StrToFloatDef(EdXMax.Text, 100),
    StrToFloatDef(EdYMin.Text, 0), StrToFloatDef(EdYMax.Text, 100),
    StrToFloatDef(EdZMin.Text, -5), StrToFloatDef(EdZMax.Text, 3),
    StrToIntDef(EdXN.Text, 5), StrToIntDef(EdYN.Text, 5));
  FGrid.SafeZ := StrToFloatDef(EdSafeZ.Text, 5);
  FGrid.ProbeFeed := StrToFloatDef(EdFeed.Text, 10);

  lines := TStringList.Create;
  try
    FGrid.GenerateScanGCode(lines);
    FSender.EnqueueLines(lines);
  finally
    lines.Free;
  end;

  RefreshGridDisplay;
  RefreshStatus;
end;

// Probe type: 0=Z Touch-off, 1=Corner/Bore Center, 2=Edge Finder - only the
// fields relevant to the selected mode are meaningful, so grey out the rest
// rather than hiding them (layout/positioning is the user's own work - see
// [[grbl-controller-sender-project]] - toggling Enabled is a pure functional
// change with no layout impact).
procedure TProbeFrame.RefreshTouchProbeMode;
begin
  EdTPZOffset.Enabled := CboProbeType.ItemIndex = 0;
  CboEdgeAxis.Enabled := CboProbeType.ItemIndex = 2;
end;

procedure TProbeFrame.CboProbeTypeChange(Sender: TObject);
begin
  RefreshTouchProbeMode;
end;

procedure TProbeFrame.BtnTouchProbeClick(Sender: TObject);
var
  lines: TStringList;
  dir: Integer;
  axis: TTouchProbeAxis;
begin
  if (FSender = nil) or (not FSender.Connected) then
  begin
    LblTouchStatus.Caption := T('Not connected');
    Exit;
  end;
  if FTouchProbe.IsActive then Exit; // a sequence is already mid-flight

  FTouchProbe.Diameter := StrToFloatDef(EdTPDiameter.Text, 6.0);
  FTouchProbe.ZOffset := StrToFloatDef(EdTPZOffset.Text, 0.0);
  FTouchProbe.Retract := StrToFloatDef(EdTPRetract.Text, 2.0);
  FTouchProbe.SearchDist := StrToFloatDef(EdTPSearchDist.Text, 25.0);
  FTouchProbe.ProbeFeed := StrToFloatDef(EdFeed.Text, 10.0);

  lines := TStringList.Create;
  try
    case CboProbeType.ItemIndex of
      1: FTouchProbe.StartCornerCenter(lines);
      2:
        begin
          case CboEdgeAxis.ItemIndex of
            0: begin axis := paX; dir := -1; end;
            1: begin axis := paX; dir := 1; end;
            2: begin axis := paY; dir := -1; end;
          else
            begin axis := paY; dir := 1; end;
          end;
          FTouchProbe.StartEdgeFinder(axis, dir, lines);
        end;
    else
      FTouchProbe.StartZOnly(lines);
    end;
    FSender.EnqueueLines(lines);
  finally
    lines.Free;
  end;

  LblTouchStatus.Caption := T('Probing...');
end;

procedure TProbeFrame.BtnZeroClick(Sender: TObject);
begin
  if (FSender = nil) or FGrid.IsEmpty then Exit;
  FGrid.SetZero(FSender.State.WX, FSender.State.WY);
  RefreshGridDisplay;
end;

procedure TProbeFrame.BtnSaveClick(Sender: TObject);
begin
  if FGrid.IsEmpty then Exit;
  if not FSaveDialog.Execute then Exit;
  FGrid.SaveToFile(FSaveDialog.FileName);
end;

procedure TProbeFrame.BtnLoadClick(Sender: TObject);
begin
  if not FOpenDialog.Execute then Exit;
  FGrid.LoadFromFile(FOpenDialog.FileName);
  RefreshGridDisplay;
  RefreshStatus;
end;

procedure TProbeFrame.HandleProbeResult(Sender: TObject; AX, AY, AZ: Double);
var
  lines: TStringList;
begin
  if FTouchProbe.IsActive then
  begin
    lines := TStringList.Create;
    try
      if FTouchProbe.HandleProbeResult(AX, AY, AZ, lines) then
        LblTouchStatus.Caption := T('Probing...')
      else
        LblTouchStatus.Caption := Format('Done: %.3f, %.3f, %.3f', [AX, AY, AZ]);
      FSender.EnqueueLines(lines);
    finally
      lines.Free;
    end;
    Exit;
  end;

  FGrid.AddPoint(AX, AY, AZ);
  RefreshGridDisplay;
  RefreshStatus;
end;

end.
