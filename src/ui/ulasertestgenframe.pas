unit ulasertestgenframe;

{ TLaserTestGenFrame: laser test-pattern UI (plan Phase 16) - "Generate
  G-Code" builds a program from the current fields (see ulasertestgen.pas
  for the actual generation, ported from LaserGRBL's real GrblFile.cs) and
  loads it into the app's existing G-code editor tab for review/sending,
  same pattern as uspoilboardframe.pas. This frame never talks to the
  controller directly.

  TestType selects which of the 3 field groups (Cutting/Greyscale/Shake)
  is visible and which config gets built on Generate. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Graphics,
  ulasertestgen, ui18n;

type
  TOnGenerated = procedure(const AProgramText: string) of object;

  TTestGenType = (tgCutting, tgGreyscale, tgShake);

  { TLaserTestGenFrame }

  TLaserTestGenFrame = class(TFrame)
    BtnGenerate: TButton;
    CbTestType: TComboBox;
    CbShakeAxis: TComboBox;
    EdCutFeedColumns: TEdit;
    EdCutFeedStart: TEdit;
    EdCutFeedEnd: TEdit;
    EdCutPassStart: TEdit;
    EdCutPassEnd: TEdit;
    EdCutFixedPower: TEdit;
    EdCutTextFeed: TEdit;
    EdCutTextPower: TEdit;
    EdGreyFeedRows: TEdit;
    EdGreyPowerCols: TEdit;
    EdGreyFeedStart: TEdit;
    EdGreyFeedEnd: TEdit;
    EdGreyPowerStart: TEdit;
    EdGreyPowerEnd: TEdit;
    EdGreySizeX: TEdit;
    EdGreySizeY: TEdit;
    EdGreyResolution: TEdit;
    EdGreyGridFeed: TEdit;
    EdGreyGridPower: TEdit;
    EdGreyTextFeed: TEdit;
    EdGreyTextPower: TEdit;
    EdShakeFeedLimit: TEdit;
    EdShakeAxisLength: TEdit;
    EdShakeCrossPower: TEdit;
    EdShakeCrossSpeed: TEdit;
    EdTitle: TEdit;
    EdTurnOnCmd: TEdit;
    LblStatus: TLabel;
    PnlCutting: TPanel;
    PnlGreyscale: TPanel;
    PnlShake: TPanel;
    ScrollBox1: TScrollBox;
    TopBar: TPanel;
    BottomBar: TPanel;
    procedure BtnGenerateClick(Sender: TObject);
    procedure CbTestTypeChange(Sender: TObject);
  private
    FOnGenerated: TOnGenerated;
    procedure SetStatus(const AMsg: string; AIsError: Boolean);
    function BuildCuttingConfig: TCuttingTestConfig;
    function BuildGreyscaleConfig: TGreyscaleTestConfig;
    function BuildShakeConfig: TShakeTestConfig;
  public
    constructor Create(AOwner: TComponent); override;
    property OnGenerated: TOnGenerated read FOnGenerated write FOnGenerated;
  end;

implementation

{$R *.frm}

{ TLaserTestGenFrame }

constructor TLaserTestGenFrame.Create(AOwner: TComponent);
var
  cutCfg: TCuttingTestConfig;
  greyCfg: TGreyscaleTestConfig;
  shakeCfg: TShakeTestConfig;
begin
  inherited Create(AOwner);

  CbTestType.Items.Clear;
  CbTestType.Items.Add(T('Cutting Test'));
  CbTestType.Items.Add(T('Power/Speed Grid'));
  CbTestType.Items.Add(T('Shake Test'));
  CbTestType.ItemIndex := 0;

  CbShakeAxis.Items.Clear;
  CbShakeAxis.Items.Add('X');
  CbShakeAxis.Items.Add('Y');
  CbShakeAxis.ItemIndex := 0;

  cutCfg := DefaultCuttingTestConfig;
  EdCutFeedColumns.Text := IntToStr(cutCfg.FeedColumns);
  EdCutFeedStart.Text := IntToStr(cutCfg.FeedStart);
  EdCutFeedEnd.Text := IntToStr(cutCfg.FeedEnd);
  EdCutPassStart.Text := IntToStr(cutCfg.PassStart);
  EdCutPassEnd.Text := IntToStr(cutCfg.PassEnd);
  EdCutFixedPower.Text := IntToStr(cutCfg.FixedPower);
  EdCutTextFeed.Text := IntToStr(cutCfg.TextFeed);
  EdCutTextPower.Text := IntToStr(cutCfg.TextPower);

  greyCfg := DefaultGreyscaleTestConfig;
  EdGreyFeedRows.Text := IntToStr(greyCfg.FeedRows);
  EdGreyPowerCols.Text := IntToStr(greyCfg.PowerCols);
  EdGreyFeedStart.Text := IntToStr(greyCfg.FeedStart);
  EdGreyFeedEnd.Text := IntToStr(greyCfg.FeedEnd);
  EdGreyPowerStart.Text := IntToStr(greyCfg.PowerStart);
  EdGreyPowerEnd.Text := IntToStr(greyCfg.PowerEnd);
  EdGreySizeX.Text := IntToStr(greyCfg.SizeX);
  EdGreySizeY.Text := IntToStr(greyCfg.SizeY);
  EdGreyResolution.Text := FloatToStr(greyCfg.Resolution);
  EdGreyGridFeed.Text := IntToStr(greyCfg.GridFeed);
  EdGreyGridPower.Text := IntToStr(greyCfg.GridPower);
  EdGreyTextFeed.Text := IntToStr(greyCfg.TextFeed);
  EdGreyTextPower.Text := IntToStr(greyCfg.TextPower);

  shakeCfg := DefaultShakeTestConfig;
  EdShakeFeedLimit.Text := IntToStr(shakeCfg.FeedLimit);
  EdShakeAxisLength.Text := IntToStr(shakeCfg.AxisLength);
  EdShakeCrossPower.Text := IntToStr(shakeCfg.CrossPower);
  EdShakeCrossSpeed.Text := IntToStr(shakeCfg.CrossSpeed);

  CbTestTypeChange(Self);
end;

procedure TLaserTestGenFrame.SetStatus(const AMsg: string; AIsError: Boolean);
begin
  LblStatus.Caption := AMsg;
  if AIsError then
    LblStatus.Font.Color := clRed
  else
    LblStatus.Font.Color := clGreen;
end;

procedure TLaserTestGenFrame.CbTestTypeChange(Sender: TObject);
var
  testType: TTestGenType;
begin
  testType := TTestGenType(CbTestType.ItemIndex);
  PnlCutting.Visible := (testType = tgCutting);
  PnlGreyscale.Visible := (testType = tgGreyscale);
  PnlShake.Visible := (testType = tgShake);
end;

function TLaserTestGenFrame.BuildCuttingConfig: TCuttingTestConfig;
begin
  Result := DefaultCuttingTestConfig;
  Result.FeedColumns := StrToIntDef(EdCutFeedColumns.Text, Result.FeedColumns);
  Result.FeedStart := StrToIntDef(EdCutFeedStart.Text, Result.FeedStart);
  Result.FeedEnd := StrToIntDef(EdCutFeedEnd.Text, Result.FeedEnd);
  Result.PassStart := StrToIntDef(EdCutPassStart.Text, Result.PassStart);
  Result.PassEnd := StrToIntDef(EdCutPassEnd.Text, Result.PassEnd);
  Result.FixedPower := StrToIntDef(EdCutFixedPower.Text, Result.FixedPower);
  Result.TextFeed := StrToIntDef(EdCutTextFeed.Text, Result.TextFeed);
  Result.TextPower := StrToIntDef(EdCutTextPower.Text, Result.TextPower);
  Result.Title := Trim(EdTitle.Text);
  Result.TurnOnCmd := Trim(EdTurnOnCmd.Text);
  if Result.TurnOnCmd = '' then Result.TurnOnCmd := 'M4';
end;

function TLaserTestGenFrame.BuildGreyscaleConfig: TGreyscaleTestConfig;
begin
  Result := DefaultGreyscaleTestConfig;
  Result.FeedRows := StrToIntDef(EdGreyFeedRows.Text, Result.FeedRows);
  Result.PowerCols := StrToIntDef(EdGreyPowerCols.Text, Result.PowerCols);
  Result.FeedStart := StrToIntDef(EdGreyFeedStart.Text, Result.FeedStart);
  Result.FeedEnd := StrToIntDef(EdGreyFeedEnd.Text, Result.FeedEnd);
  Result.PowerStart := StrToIntDef(EdGreyPowerStart.Text, Result.PowerStart);
  Result.PowerEnd := StrToIntDef(EdGreyPowerEnd.Text, Result.PowerEnd);
  Result.SizeX := StrToIntDef(EdGreySizeX.Text, Result.SizeX);
  Result.SizeY := StrToIntDef(EdGreySizeY.Text, Result.SizeY);
  Result.Resolution := StrToFloatDef(EdGreyResolution.Text, Result.Resolution);
  Result.GridFeed := StrToIntDef(EdGreyGridFeed.Text, Result.GridFeed);
  Result.GridPower := StrToIntDef(EdGreyGridPower.Text, Result.GridPower);
  Result.TextFeed := StrToIntDef(EdGreyTextFeed.Text, Result.TextFeed);
  Result.TextPower := StrToIntDef(EdGreyTextPower.Text, Result.TextPower);
  Result.Title := Trim(EdTitle.Text);
  Result.TurnOnCmd := Trim(EdTurnOnCmd.Text);
  if Result.TurnOnCmd = '' then Result.TurnOnCmd := 'M4';
end;

function TLaserTestGenFrame.BuildShakeConfig: TShakeTestConfig;
begin
  Result := DefaultShakeTestConfig;
  if CbShakeAxis.Text = 'Y' then
    Result.Axis := saY
  else
    Result.Axis := saX;
  Result.FeedLimit := StrToIntDef(EdShakeFeedLimit.Text, Result.FeedLimit);
  Result.AxisLength := StrToIntDef(EdShakeAxisLength.Text, Result.AxisLength);
  Result.CrossPower := StrToIntDef(EdShakeCrossPower.Text, Result.CrossPower);
  Result.CrossSpeed := StrToIntDef(EdShakeCrossSpeed.Text, Result.CrossSpeed);
end;

procedure TLaserTestGenFrame.BtnGenerateClick(Sender: TObject);
var
  lines: TStringList;
  testType: TTestGenType;
begin
  testType := TTestGenType(CbTestType.ItemIndex);
  lines := TStringList.Create;
  try
    case testType of
      tgCutting: GenerateCuttingTest(BuildCuttingConfig, lines);
      tgGreyscale: GenerateGreyscaleTest(BuildGreyscaleConfig, lines);
      tgShake: GenerateShakeTest(BuildShakeConfig, lines);
    end;
    SetStatus(Format(T('Generated %d lines.'), [lines.Count]), False);
    if Assigned(FOnGenerated) then
      FOnGenerated(lines.Text);
  finally
    lines.Free;
  end;
end;

end.
