unit usettingsform;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Dialogs,
  ucncstate;

type

  { TSettingsForm }

  TSettingsForm = class(TForm)
    BtnCancel: TButton;
    BtnOK: TButton;
    EdAccelX: TEdit;
    EdAccelY: TEdit;
    EdAccelZ: TEdit;
    EdCutFeed: TEdit;
    EdCutFeedZ: TEdit;
    EdDiameter: TEdit;
    EdFeedMaxX: TEdit;
    EdFeedMaxY: TEdit;
    EdFeedMaxZ: TEdit;
    EdSafe: TEdit;
    EdStartup: TEdit;
    EdTravelX: TEdit;
    EdTravelY: TEdit;
    EdTravelZ: TEdit;
    ChkGangedX: TCheckBox;
    ChkGangedY: TCheckBox;
    ChkGangedZ: TCheckBox;
    LblAccel: TLabel;
    LblCutFeed: TLabel;
    LblDiameter: TLabel;
    LblFeedMax: TLabel;
    LblGanged: TLabel;
    LblSafe: TLabel;
    LblStartup: TLabel;
    LblTravel: TLabel;
    LblTravel1: TLabel;
    LblTravel2: TLabel;
    LblTravel3: TLabel;
  public
    procedure LoadFromState(AState: TCNCState);
    procedure SaveToState(AState: TCNCState);
  end;

implementation

{$R *.frm}

{ TSettingsForm }

procedure TSettingsForm.LoadFromState(AState: TCNCState);
begin
  with AState do
  begin
    EdTravelX.Text := FloatToStr(TravelX);
    EdTravelY.Text := FloatToStr(TravelY);
    EdTravelZ.Text := FloatToStr(TravelZ);
    EdFeedMaxX.Text := FloatToStr(FeedMaxX);
    EdFeedMaxY.Text := FloatToStr(FeedMaxY);
    EdFeedMaxZ.Text := FloatToStr(FeedMaxZ);
    EdAccelX.Text := FloatToStr(AccelX);
    EdAccelY.Text := FloatToStr(AccelY);
    EdAccelZ.Text := FloatToStr(AccelZ);
    EdSafe.Text := FloatToStr(Safe);
    EdDiameter.Text := FloatToStr(Diameter);
    EdCutFeed.Text := FloatToStr(CutFeed);
    EdCutFeedZ.Text := FloatToStr(CutFeedZ);
    EdStartup.Text := StartupGCode;
    ChkGangedX.Checked := Pos('X', GangedAxes) > 0;
    ChkGangedY.Checked := Pos('Y', GangedAxes) > 0;
    ChkGangedZ.Checked := Pos('Z', GangedAxes) > 0;
  end;
end;

procedure TSettingsForm.SaveToState(AState: TCNCState);
begin
  with AState do
  begin
    TravelX := StrToFloatDef(EdTravelX.Text, TravelX);
    TravelY := StrToFloatDef(EdTravelY.Text, TravelY);
    TravelZ := StrToFloatDef(EdTravelZ.Text, TravelZ);
    FeedMaxX := StrToFloatDef(EdFeedMaxX.Text, FeedMaxX);
    FeedMaxY := StrToFloatDef(EdFeedMaxY.Text, FeedMaxY);
    FeedMaxZ := StrToFloatDef(EdFeedMaxZ.Text, FeedMaxZ);
    AccelX := StrToFloatDef(EdAccelX.Text, AccelX);
    AccelY := StrToFloatDef(EdAccelY.Text, AccelY);
    AccelZ := StrToFloatDef(EdAccelZ.Text, AccelZ);
    Safe := StrToFloatDef(EdSafe.Text, Safe);
    Diameter := StrToFloatDef(EdDiameter.Text, Diameter);
    CutFeed := StrToFloatDef(EdCutFeed.Text, CutFeed);
    CutFeedZ := StrToFloatDef(EdCutFeedZ.Text, CutFeedZ);
    StartupGCode := EdStartup.Text;

    GangedAxes := '';
    if ChkGangedX.Checked then GangedAxes := GangedAxes + 'X';
    if ChkGangedY.Checked then GangedAxes := GangedAxes + 'Y';
    if ChkGangedZ.Checked then GangedAxes := GangedAxes + 'Z';
  end;
end;

end.
