unit usettingsgridframe;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, StdCtrls, ExtCtrls, Grids,
  usender, usettingsmeta, ui18n, usettinghelp;

const
  COL_ID = 0;
  COL_VALUE = 1;
  COL_DESC = 2;

type

  { TSettingsGridFrame: universal $$ settings editor (Phase F) - a bare
    $ID/Value grid, already a complete, real settings editor for grblHAL/
    uCNC/GRBL0/GRBL1 alike, since all four speak the identical $N=value
    wire format. The Description column (Phase F2) is an enrichment layer
    on top: grblHAL-only, populated from $ES if the user asks for it -
    stays blank (and totally harmless) for boards that don't implement it. }
  TSettingsGridFrame = class(TFrame)
    BtnApply: TButton;
    BtnFetchDescriptions: TButton;
    BtnRefresh: TButton;
    DescTimer: TTimer;
    Grid: TStringGrid;
    LblStatus: TLabel;
    RefreshTimer: TTimer;
    ToolBar: TPanel;
    procedure BtnApplyClick(Sender: TObject);
    procedure BtnFetchDescriptionsClick(Sender: TObject);
    procedure BtnRefreshClick(Sender: TObject);
    procedure DescTimerTimer(Sender: TObject);
    procedure RefreshTimerTimer(Sender: TObject);
  private
    FSender: TSender;
    // Shadow of the last-loaded/last-applied values, keyed by setting ID -
    // Apply diffs the grid against this and only writes rows that actually
    // changed, rather than re-sending the whole map on every click.
    FShadow: TStringList;
    procedure PopulateGridFromState;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetSender(ASender: TSender);
  end;

implementation

{$R *.frm}

function CompareIDs(AList: TStringList; AIndex1, AIndex2: Integer): Integer;
begin
  Result := StrToIntDef(AList.Names[AIndex1], 0) - StrToIntDef(AList.Names[AIndex2], 0);
end;

{ TSettingsGridFrame }

constructor TSettingsGridFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FShadow := TStringList.Create;
  Grid.Cells[COL_ID, 0] := '$ID';
  Grid.Cells[COL_VALUE, 0] := 'Value';
  Grid.Cells[COL_DESC, 0] := 'Description';
  LblStatus.Caption := T('Not connected');
end;

destructor TSettingsGridFrame.Destroy;
begin
  FShadow.Free;
  inherited Destroy;
end;

procedure TSettingsGridFrame.SetSender(ASender: TSender);
begin
  FSender := ASender;
end;

procedure TSettingsGridFrame.PopulateGridFromState;
var
  i, id: Integer;
  meta: TSettingMeta;
  descCount: Integer;
  fallbackDesc: string;
begin
  if FSender = nil then Exit;
  FShadow.Assign(FSender.State.Settings);

  // Sort numerically by ID (Settings is a plain Name=Value list in arrival
  // order, which is already ascending for a real $$ dump, but don't rely on
  // that - sort explicitly so a partial/re-requested dump still displays
  // sensibly).
  FShadow.CustomSort(@CompareIDs);

  Grid.RowCount := Max(2, FShadow.Count + 1);
  descCount := 0;
  for i := 0 to FShadow.Count - 1 do
  begin
    Grid.Cells[COL_ID, i + 1] := FShadow.Names[i];
    Grid.Cells[COL_VALUE, i + 1] := FShadow.ValueFromIndex[i];
    id := StrToIntDef(FShadow.Names[i], -1);
    if (id >= 0) and FSender.State.SettingsMeta.TryGet(id, meta) then
    begin
      Grid.Cells[COL_DESC, i + 1] := meta.Name + ' - ' + DescribeSettingMeta(meta);
      Inc(descCount);
    end
    else if id >= 0 then
    begin
      // Phase 18: no $ES metadata (grblHAL only) for this board/setting -
      // fall back to the baked-in grbl 1.1 description table
      // (usettinghelp.pas) so standard settings still show something
      // human-readable on vanilla grbl 1.1 / Ortur / Longer / etc boards.
      fallbackDesc := SettingDescription(id);
      if fallbackDesc <> '' then
      begin
        Grid.Cells[COL_DESC, i + 1] := SettingName(id) + ' - ' + fallbackDesc;
        Inc(descCount);
      end
      else
        Grid.Cells[COL_DESC, i + 1] := '';
    end
    else
      Grid.Cells[COL_DESC, i + 1] := '';
  end;
  for i := FShadow.Count to Grid.RowCount - 2 do
  begin
    Grid.Cells[COL_ID, i + 1] := '';
    Grid.Cells[COL_VALUE, i + 1] := '';
    Grid.Cells[COL_DESC, i + 1] := '';
  end;

  if FShadow.Count = 0 then
    LblStatus.Caption := T('No settings loaded yet - click Refresh')
  else if descCount = 0 then
    LblStatus.Caption := Format('%d settings loaded', [FShadow.Count])
  else
    LblStatus.Caption := Format('%d settings loaded (%d with descriptions)', [FShadow.Count, descCount]);
end;

procedure TSettingsGridFrame.BtnRefreshClick(Sender: TObject);
begin
  if (FSender = nil) or (not FSender.Connected) then
  begin
    LblStatus.Caption := T('Not connected');
    Exit;
  end;
  LblStatus.Caption := T('Requesting $$...');
  FSender.RequestSettings;
  // No explicit "dump complete" signal on the wire (just N lines then ok) -
  // give it a beat to arrive, then read whatever's in FState.Settings.
  RefreshTimer.Enabled := False;
  RefreshTimer.Enabled := True;
end;

procedure TSettingsGridFrame.RefreshTimerTimer(Sender: TObject);
begin
  RefreshTimer.Enabled := False;
  PopulateGridFromState;
end;

procedure TSettingsGridFrame.BtnFetchDescriptionsClick(Sender: TObject);
begin
  if (FSender = nil) or (not FSender.Connected) then
  begin
    LblStatus.Caption := T('Not connected');
    Exit;
  end;
  LblStatus.Caption := T('Requesting $ES...');
  FSender.RequestSettingsDetails;
  // $ES can be a much longer dump than $$ (one line per setting, every
  // field spelled out) - give it more time than the plain-value Refresh.
  DescTimer.Enabled := False;
  DescTimer.Enabled := True;
end;

procedure TSettingsGridFrame.DescTimerTimer(Sender: TObject);
begin
  DescTimer.Enabled := False;
  PopulateGridFromState;
end;

procedure TSettingsGridFrame.BtnApplyClick(Sender: TObject);
var
  row, sentCount: Integer;
  id, newVal, oldVal: string;
begin
  if (FSender = nil) or (not FSender.Connected) then
  begin
    LblStatus.Caption := T('Not connected');
    Exit;
  end;

  // Use FShadow's ID for each row (by position), not whatever text is
  // currently in the ID cell - the ID column is meant to be read-only, but
  // TStringGrid's default editor doesn't enforce that per-column, so this
  // sidesteps a user edit there ever producing a bogus $N write.
  sentCount := 0;
  for row := 1 to Min(Grid.RowCount - 1, FShadow.Count) do
  begin
    id := FShadow.Names[row - 1];
    newVal := Trim(Grid.Cells[COL_VALUE, row]);
    oldVal := FShadow.ValueFromIndex[row - 1];
    if (newVal <> '') and (newVal <> oldVal) then
    begin
      FSender.WriteSetting(id, newVal);
      FShadow.Values[id] := newVal;
      Inc(sentCount);
    end;
  end;

  LblStatus.Caption := Format('%d changed row(s) sent', [sentCount]);
end;

end.
