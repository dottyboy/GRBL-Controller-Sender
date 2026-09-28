unit uconnectframe;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Graphics,
  usender, uportlist, uboardcatalog, ui18n;

type

  { TConnectFrame }

  TConnectFrame = class(TFrame)
    BtnOpenClose: TButton;
    BtnRefresh: TButton;
    BtnRefreshInfo: TButton;
    CboBaud: TComboBox;
    CboBoardProfile: TComboBox;
    CboController: TComboBox;
    CboPort: TComboBox;
    LblBaud: TLabel;
    LblBoardInfo: TLabel;
    LblBoardProfile: TLabel;
    LblController: TLabel;
    LblPort: TLabel;
    LblState: TLabel;
    procedure BtnRefreshClick(Sender: TObject);
    procedure BtnOpenCloseClick(Sender: TObject);
    procedure BtnRefreshInfoClick(Sender: TObject);
    procedure CboBoardProfileChange(Sender: TObject);
  private
    FSender: TSender;
    FCatalogIndexByRow: array of Integer; // CboBoardProfile row -> Catalog index, -1 = "(Auto-detect)"
    procedure PopulateBoardProfiles;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetSender(ASender: TSender);
    procedure RefreshState;
  end;

implementation

{$R *.frm}

{ TConnectFrame }

constructor TConnectFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BtnRefreshClick(Self);
  PopulateBoardProfiles;
end;

procedure TConnectFrame.SetSender(ASender: TSender);
begin
  FSender := ASender;
end;

procedure TConnectFrame.PopulateBoardProfiles;
var
  i: Integer;
  profile: TBoardProfile;
  catalog: TBoardProfileArray;
begin
  CboBoardProfile.Items.BeginUpdate;
  try
    CboBoardProfile.Items.Clear;
    CboBoardProfile.Items.Add('(Auto-detect)');
    catalog := BoardCatalog;
    SetLength(FCatalogIndexByRow, Length(catalog) + 1);
    FCatalogIndexByRow[0] := -1;
    for i := 0 to High(catalog) do
    begin
      profile := catalog[i];
      CboBoardProfile.Items.Add(profile.Ecosystem + ': ' + profile.Name +
        ' (' + profile.Family + ')');
      FCatalogIndexByRow[i + 1] := i;
    end;
    CboBoardProfile.ItemIndex := 0;
  finally
    CboBoardProfile.Items.EndUpdate;
  end;
end;

procedure TConnectFrame.CboBoardProfileChange(Sender: TObject);
var
  row, catIdx: Integer;
  profile: TBoardProfile;
begin
  if FSender = nil then Exit;
  row := CboBoardProfile.ItemIndex;
  if (row < 0) or (row >= Length(FCatalogIndexByRow)) then Exit;
  catIdx := FCatalogIndexByRow[row];

  if catIdx < 0 then
  begin
    // "(Auto-detect)" - clear any manual override, fall back to whatever
    // $I actually reported (or nothing, if not connected/detected yet).
    FSender.State.BoardInfo.ManuallySelected := False;
    RefreshState;
    Exit;
  end;

  profile := ProfileAt(catIdx);
  FSender.State.BoardInfo.BoardName := profile.Name;
  FSender.State.BoardInfo.AxisCount := profile.AxisCount;
  if profile.AxisCount = 3 then
    FSender.State.BoardInfo.AxisLetters := 'XYZ'
  else
    FSender.State.BoardInfo.AxisLetters := ''; // unknown beyond count for a manual pick
  FSender.State.BoardInfo.ManuallySelected := True;
  RefreshState;
end;

procedure TConnectFrame.BtnRefreshInfoClick(Sender: TObject);
begin
  if (FSender = nil) or (not FSender.Connected) then Exit;
  FSender.EnqueueGCode('$I');
end;

procedure TConnectFrame.BtnRefreshClick(Sender: TObject);
var
  ports: TStringList;
  cur: string;
begin
  cur := CboPort.Text;
  ports := TStringList.Create;
  try
    ListSerialPorts(ports);
    CboPort.Items.Assign(ports);
  finally
    ports.Free;
  end;
  if (cur <> '') and (CboPort.Items.IndexOf(cur) < 0) then
    CboPort.Items.Add(cur);
  if CboPort.Text = '' then
  begin
    if CboPort.Items.Count > 0 then
      CboPort.ItemIndex := 0
    else
      CboPort.Text := cur;
  end
  else
    CboPort.Text := cur;
end;

procedure TConnectFrame.BtnOpenCloseClick(Sender: TObject);
var
  kind: TControllerKind;
begin
  if FSender = nil then Exit;

  if FSender.Connected then
  begin
    FSender.Disconnect;
    BtnOpenClose.Caption := T('Open');
    RefreshState;
    Exit;
  end;

  if CboPort.Text = '' then
  begin
    LblState.Caption := T('Select a port first');
    Exit;
  end;

  case CboController.ItemIndex of
    0: kind := ckGRBL1;
    1: kind := ckGRBL0;
    2: kind := ckSmoothie;
    3: kind := ckG2Core;
  else
    kind := ckGRBL1;
  end;

  FSender.Connect(CboPort.Text, StrToIntDef(CboBaud.Text, 115200), kind);
  BtnOpenClose.Caption := T('Close');
  RefreshState;
end;

procedure TConnectFrame.RefreshState;
begin
  if FSender = nil then Exit;
  LblState.Caption := FSender.State.StateStr;
  if FSender.Connected then
    BtnOpenClose.Caption := T('Close')
  else
    BtnOpenClose.Caption := T('Open');
  LblBoardInfo.Caption := FSender.State.BoardInfo.DisplaySummary;
end;

end.
