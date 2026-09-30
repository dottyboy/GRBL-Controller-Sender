unit uparametrictoolframe;

{ TParametricToolFrame: plan Phase 34's "wizard-like flow" half of the tool
  bit catalog - pick a shape template (Endmill/Ball End/Bull Nose/V-Bit/
  Drill/Chamfer), fill in ITS OWN real parameter set (utoolbits.pas,
  itself transcribed from a genuine local FreeCAD install's own default
  tool bit files), get a fully-specified tool. Complements the flat
  preset list (utoolsframe.pas's "Load preset" combo) for sizes/angles a
  preset doesn't cover.

  Converted from a modal dialog to a plain Settings & Tools tab in a
  later session - this X11/Qt5 environment hit a real, reproducible
  crash creating ANY second top-level window via ShowModal, confirmed
  environment-level, not a code regression. "Add to Tool Table" now
  fires OnToolCreated instead of setting ModalResult - umain.pas wires
  it to utoolsframe.pas's own AddParametricTool, which does exactly what
  the old modal's caller used to do with its return value. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, Spin, ExtCtrls,
  Dialogs, utoolbits, ui18n;

type
  TOnToolCreated = procedure(const AName, AComment: string; ADiameter: Double) of object;

  { TParametricToolFrame }

  TParametricToolFrame = class(TFrame)
    BtnAddToTools: TButton;
    CboShape: TComboBox;
    EdCornerRadius: TFloatSpinEdit;
    EdCuttingEdgeAngle: TFloatSpinEdit;
    EdDiameter: TFloatSpinEdit;
    EdLength: TFloatSpinEdit;
    EdShankDiameter: TFloatSpinEdit;
    EdTipAngle: TFloatSpinEdit;
    EdTipDiameter: TFloatSpinEdit;
    LblCornerRadius: TLabel;
    LblCuttingEdgeAngle: TLabel;
    LblDiameter: TLabel;
    LblLength: TLabel;
    LblShankDiameter: TLabel;
    LblShape: TLabel;
    LblStatus: TLabel;
    LblTipAngle: TLabel;
    LblTipDiameter: TLabel;
    procedure BtnAddToToolsClick(Sender: TObject);
    procedure CboShapeChange(Sender: TObject);
  private
    FOnToolCreated: TOnToolCreated;
    function CurrentShape: TToolBitShape;
    function CurrentParams: TToolBitParams;
    function GetToolName: string;
    function GetToolComment: string;
    procedure UpdateFieldVisibility;
  public
    constructor Create(AOwner: TComponent); override;
    property OnToolCreated: TOnToolCreated read FOnToolCreated write FOnToolCreated;
  end;

implementation

{$R *.frm}

{ TParametricToolFrame }

constructor TParametricToolFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  CboShape.Items.Add(T('Endmill'));
  CboShape.Items.Add(T('Ball End'));
  CboShape.Items.Add(T('Bull Nose'));
  CboShape.Items.Add(T('V-Bit'));
  CboShape.Items.Add(T('Drill'));
  CboShape.Items.Add(T('Chamfer'));
  CboShape.ItemIndex := 0;
  CboShapeChange(Self);
end;

function TParametricToolFrame.CurrentShape: TToolBitShape;
begin
  case CboShape.ItemIndex of
    0: Result := tbsEndmill;
    1: Result := tbsBallend;
    2: Result := tbsBullnose;
    3: Result := tbsVBit;
    4: Result := tbsDrill;
    5: Result := tbsChamfer;
  else
    Result := tbsEndmill;
  end;
end;

procedure TParametricToolFrame.CboShapeChange(Sender: TObject);
var
  p: TToolBitParams;
begin
  p := DefaultParamsForShape(CurrentShape);
  EdDiameter.Value := p.Diameter;
  EdShankDiameter.Value := p.ShankDiameter;
  EdLength.Value := p.Length;
  EdCuttingEdgeAngle.Value := p.CuttingEdgeAngle;
  EdTipDiameter.Value := p.TipDiameter;
  EdCornerRadius.Value := p.CornerRadius;
  EdTipAngle.Value := p.TipAngle;
  UpdateFieldVisibility;
end;

procedure TParametricToolFrame.UpdateFieldVisibility;
var
  shape: TToolBitShape;
  showShank, showAngle, showTip, showCorner, showTipAngle: Boolean;
begin
  shape := CurrentShape;
  showShank := shape in [tbsEndmill, tbsBallend, tbsBullnose, tbsVBit, tbsChamfer];
  showAngle := shape in [tbsVBit, tbsChamfer];
  showTip := shape in [tbsVBit, tbsChamfer];
  showCorner := shape = tbsBullnose;
  showTipAngle := shape = tbsDrill;

  LblShankDiameter.Visible := showShank;
  EdShankDiameter.Visible := showShank;
  LblCuttingEdgeAngle.Visible := showAngle;
  EdCuttingEdgeAngle.Visible := showAngle;
  LblTipDiameter.Visible := showTip;
  EdTipDiameter.Visible := showTip;
  LblCornerRadius.Visible := showCorner;
  EdCornerRadius.Visible := showCorner;
  LblTipAngle.Visible := showTipAngle;
  EdTipAngle.Visible := showTipAngle;
end;

function TParametricToolFrame.CurrentParams: TToolBitParams;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Diameter := EdDiameter.Value;
  Result.ShankDiameter := EdShankDiameter.Value;
  Result.Length := EdLength.Value;
  Result.CuttingEdgeAngle := EdCuttingEdgeAngle.Value;
  Result.TipDiameter := EdTipDiameter.Value;
  Result.CornerRadius := EdCornerRadius.Value;
  Result.TipAngle := EdTipAngle.Value;
end;

function TParametricToolFrame.GetToolName: string;
begin
  case CurrentShape of
    tbsVBit, tbsChamfer:
      Result := Format('%s %.1fdeg', [ShapeName(CurrentShape), EdCuttingEdgeAngle.Value]);
  else
    Result := Format('%s %.3fmm', [ShapeName(CurrentShape), EdDiameter.Value]);
  end;
end;

function TParametricToolFrame.GetToolComment: string;
begin
  Result := DescribeToolBit(CurrentShape, CurrentParams);
end;

procedure TParametricToolFrame.BtnAddToToolsClick(Sender: TObject);
begin
  if Assigned(FOnToolCreated) then
    FOnToolCreated(GetToolName, GetToolComment, EdDiameter.Value);
  LblStatus.Caption := T('Added.');
  LblStatus.Font.Color := clGreen;
end;

end.
