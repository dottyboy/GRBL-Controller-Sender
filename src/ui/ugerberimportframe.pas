unit ugerberimportframe;

{ TGerberImportFrame: the "Gerber Import" tab (plan Phase 33, extended by
  Phase 39) - loads a Gerber (RS-274X) file and generates a machining
  toolpath for it using ugerberimport.pas + uisolationrouting.pas, then
  hands the resulting G-code to the same Generate -> Editor -> 3D View
  pipeline every other generator frame in this app already uses (see
  usvgimportframe.pas/uspoilboardframe.pas's own TOnGenerated pattern).

  Phase 39 adds two independent selectors: which TOOL (CNC mill vs laser -
  a G-code-emission difference over the same ring geometry for Isolate)
  and which STRATEGY (Isolate - Phase 33's original offset-ring behavior -
  vs Draw, CNC-only, which follows the raw parsed trace/pad geometry
  directly instead of offsetting around it). Laser+Draw is not a real
  combination (a laser "drawing" ink makes no physical sense, and a laser
  following copper directly is just Isolate with a near-zero gap) -
  selecting Laser forces Strategy back to Isolate. "Clear all copper
  except the traces" (the plan's own third strategy) is NOT implemented
  yet - it needs a second (board-outline) Gerber layer and a fill-hatching
  toolpath generator neither of which exist yet, disclosed rather than
  faked with a menu option that does nothing. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls, Dialogs,
  Spin, ugerberimport, uisolationrouting, uregistrationholes, ui18n;

type
  TOnGenerated = procedure(const AProgramText: string) of object;

  { TGerberImportFrame }

  TGerberImportFrame = class(TFrame)
    BtnGenerate: TButton;
    BtnGenerateRegHoles: TButton;
    BtnOpenGerber: TButton;
    ChkMirror: TCheckBox;
    EdCutDepth: TFloatSpinEdit;
    EdDepthPerPass: TFloatSpinEdit;
    EdFeedRate: TSpinEdit;
    EdIsolationGap: TFloatSpinEdit;
    EdLaserFeedRate: TSpinEdit;
    EdLaserPower: TSpinEdit;
    EdMirrorAxisX: TFloatSpinEdit;
    EdPasses: TSpinEdit;
    EdPassStepover: TFloatSpinEdit;
    EdPlungeRate: TSpinEdit;
    EdRegDrillDepth: TFloatSpinEdit;
    EdRegHole1X: TFloatSpinEdit;
    EdRegHole1Y: TFloatSpinEdit;
    EdRegHole2X: TFloatSpinEdit;
    EdRegHole2Y: TFloatSpinEdit;
    EdRegHoleDiameter: TFloatSpinEdit;
    EdRegPeckDepth: TFloatSpinEdit;
    EdSafeZ: TFloatSpinEdit;
    EdSpindleRPM: TSpinEdit;
    EdToolDiameter: TFloatSpinEdit;
    LblCutDepth: TLabel;
    LblDepthPerPass: TLabel;
    LblFeedRate: TLabel;
    LblGerberFile: TLabel;
    LblIsolationGap: TLabel;
    LblLaserFeedRate: TLabel;
    LblLaserPower: TLabel;
    LblMirrorAxisX: TLabel;
    LblMirrorSection: TLabel;
    LblPasses: TLabel;
    LblPassStepover: TLabel;
    LblPlungeRate: TLabel;
    LblRegDrillDepth: TLabel;
    LblRegHole1: TLabel;
    LblRegHole2: TLabel;
    LblRegHoleDiameter: TLabel;
    LblRegPeckDepth: TLabel;
    LblRegSection: TLabel;
    LblSafeZ: TLabel;
    LblSpindleRPM: TLabel;
    LblStatus: TLabel;
    LblToolDiameter: TLabel;
    RgStrategy: TRadioGroup;
    RgTool: TRadioGroup;
    procedure BtnGenerateClick(Sender: TObject);
    procedure BtnGenerateRegHolesClick(Sender: TObject);
    procedure BtnOpenGerberClick(Sender: TObject);
    procedure ChkMirrorClick(Sender: TObject);
    procedure RgStrategyClick(Sender: TObject);
    procedure RgToolClick(Sender: TObject);
  private
    FDialog: TOpenDialog;
    FGerberFile: string;
    FOnGenerated: TOnGenerated;
    procedure SetStatus(const AMsg: string; AIsError: Boolean);
    function ConfigFromUI: TIsolationConfig;
    function LaserConfigFromUI: TLaserConfig;
    function RegHoleConfigFromUI: TRegistrationHoleConfig;
    procedure UpdateFieldVisibility;
    function IsLaser: Boolean;
    function IsDraw: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ImportFile(const AFileName: string);
    property OnGenerated: TOnGenerated read FOnGenerated write FOnGenerated;
  end;

implementation

{$R *.frm}

{ TGerberImportFrame }

constructor TGerberImportFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDialog := TOpenDialog.Create(Self);
  FDialog.Filter := 'Gerber files (*.gbr;*.ger;*.gtl;*.gbl;*.gts;*.gbs)|*.gbr;*.ger;*.gtl;*.gbl;*.gts;*.gbs|All files (*.*)|*.*';
  UpdateFieldVisibility;
  ChkMirrorClick(Self);
end;

procedure TGerberImportFrame.ChkMirrorClick(Sender: TObject);
begin
  EdMirrorAxisX.Enabled := ChkMirror.Checked;
end;

procedure TGerberImportFrame.SetStatus(const AMsg: string; AIsError: Boolean);
begin
  LblStatus.Caption := AMsg;
  if AIsError then
    LblStatus.Font.Color := clRed
  else
    LblStatus.Font.Color := clGreen;
end;

function TGerberImportFrame.IsLaser: Boolean;
begin
  Result := RgTool.ItemIndex = 1;
end;

function TGerberImportFrame.IsDraw: Boolean;
begin
  Result := RgStrategy.ItemIndex = 1;
end;

procedure TGerberImportFrame.RgToolClick(Sender: TObject);
begin
  if IsLaser and IsDraw then
  begin
    RgStrategy.ItemIndex := 0; // Draw is CNC-only - fall back to Isolate
    SetStatus(T('Draw is CNC-only - switched to Isolate for laser output.'), False);
  end;
  UpdateFieldVisibility;
end;

procedure TGerberImportFrame.RgStrategyClick(Sender: TObject);
begin
  if IsDraw and IsLaser then
  begin
    RgTool.ItemIndex := 0; // Draw is CNC-only - fall back to CNC
    SetStatus(T('Draw is CNC-only - switched to CNC output.'), False);
  end;
  UpdateFieldVisibility;
end;

procedure TGerberImportFrame.UpdateFieldVisibility;
var
  showIsolateOnly, showCNC, showLaser: Boolean;
begin
  showIsolateOnly := not IsDraw;   // ToolDiameter/IsolationGap/Passes/PassStepover
                                   // only mean anything for the offset-ring
                                   // Isolate strategy, not Draw's direct trace.
  showCNC := not IsLaser;
  showLaser := IsLaser;

  LblToolDiameter.Visible := showIsolateOnly;
  EdToolDiameter.Visible := showIsolateOnly;
  LblIsolationGap.Visible := showIsolateOnly;
  EdIsolationGap.Visible := showIsolateOnly;
  LblPasses.Visible := showIsolateOnly;
  EdPasses.Visible := showIsolateOnly;
  LblPassStepover.Visible := showIsolateOnly;
  EdPassStepover.Visible := showIsolateOnly;

  LblCutDepth.Visible := showCNC;
  EdCutDepth.Visible := showCNC;
  LblDepthPerPass.Visible := showCNC;
  EdDepthPerPass.Visible := showCNC;
  LblSafeZ.Visible := showCNC;
  EdSafeZ.Visible := showCNC;
  LblFeedRate.Visible := showCNC;
  EdFeedRate.Visible := showCNC;
  LblPlungeRate.Visible := showCNC;
  EdPlungeRate.Visible := showCNC;
  LblSpindleRPM.Visible := showCNC;
  EdSpindleRPM.Visible := showCNC;

  LblLaserPower.Visible := showLaser;
  EdLaserPower.Visible := showLaser;
  LblLaserFeedRate.Visible := showLaser;
  EdLaserFeedRate.Visible := showLaser;

  // Registration holes (Phase 40) need an actual drilled hole for a
  // dowel pin - CNC-only, no laser equivalent. Mirror stays available
  // for either tool (Isolate can run on laser too).
  LblRegSection.Visible := showCNC;
  LblRegHoleDiameter.Visible := showCNC;
  EdRegHoleDiameter.Visible := showCNC;
  LblRegDrillDepth.Visible := showCNC;
  EdRegDrillDepth.Visible := showCNC;
  LblRegPeckDepth.Visible := showCNC;
  EdRegPeckDepth.Visible := showCNC;
  LblRegHole1.Visible := showCNC;
  EdRegHole1X.Visible := showCNC;
  EdRegHole1Y.Visible := showCNC;
  LblRegHole2.Visible := showCNC;
  EdRegHole2X.Visible := showCNC;
  EdRegHole2Y.Visible := showCNC;
  BtnGenerateRegHoles.Visible := showCNC;
end;

function TGerberImportFrame.ConfigFromUI: TIsolationConfig;
begin
  Result.ToolDiameter := EdToolDiameter.Value;
  Result.IsolationGap := EdIsolationGap.Value;
  Result.Passes := EdPasses.Value;
  Result.PassStepover := EdPassStepover.Value;
  Result.CutDepth := EdCutDepth.Value;
  Result.DepthPerPass := EdDepthPerPass.Value;
  Result.SafeZ := EdSafeZ.Value;
  Result.FeedRate := EdFeedRate.Value;
  Result.PlungeRate := EdPlungeRate.Value;
  Result.SpindleRPM := EdSpindleRPM.Value;
end;

function TGerberImportFrame.LaserConfigFromUI: TLaserConfig;
begin
  Result.Power := EdLaserPower.Value;
  Result.FeedRate := EdLaserFeedRate.Value;
end;

function TGerberImportFrame.RegHoleConfigFromUI: TRegistrationHoleConfig;
begin
  Result.HoleDiameter := EdRegHoleDiameter.Value;
  Result.DrillDepth := EdRegDrillDepth.Value;
  Result.PeckDepth := EdRegPeckDepth.Value;
  // Registration holes reuse the tab's existing CNC SafeZ/PlungeRate/
  // SpindleRPM fields rather than duplicating them - same physical
  // machine setup, no reason for a second set of values.
  Result.PlungeRate := EdPlungeRate.Value;
  Result.SafeZ := EdSafeZ.Value;
  Result.SpindleRPM := EdSpindleRPM.Value;
end;

procedure TGerberImportFrame.BtnGenerateRegHolesClick(Sender: TObject);
var
  pts: TRegistrationPointArray;
  cfg: TRegistrationHoleConfig;
  gcode: TStringList;
begin
  SetLength(pts, 2);
  pts[0].X := EdRegHole1X.Value;
  pts[0].Y := EdRegHole1Y.Value;
  pts[1].X := EdRegHole2X.Value;
  pts[1].Y := EdRegHole2Y.Value;
  cfg := RegHoleConfigFromUI;

  gcode := TStringList.Create;
  try
    try
      uregistrationholes.AppendRegistrationHolesGCode(pts, cfg, gcode);
    except
      on E: uregistrationholes.EGenerateError do
      begin
        SetStatus(E.Message, True);
        Exit;
      end;
    end;
    SetStatus(T('Registration holes program generated.'), False);
    if Assigned(FOnGenerated) then FOnGenerated(gcode.Text);
  finally
    gcode.Free;
  end;
end;

procedure TGerberImportFrame.ImportFile(const AFileName: string);
begin
  FGerberFile := AFileName;
  LblGerberFile.Caption := ExtractFileName(FGerberFile);
  BtnGenerateClick(Self);
end;

procedure TGerberImportFrame.BtnOpenGerberClick(Sender: TObject);
begin
  if not FDialog.Execute then Exit;
  FGerberFile := FDialog.FileName;
  LblGerberFile.Caption := ExtractFileName(FGerberFile);
  SetStatus('', False);
end;

procedure TGerberImportFrame.BtnGenerateClick(Sender: TObject);
var
  raw: TStringList;
  lines: array of string;
  i: Integer;
  feats: TGerberFeatureArray;
  units: TGerberUnits;
  warnings: array of string;
  cfg: TIsolationConfig;
  laserCfg: TLaserConfig;
  passes: TIsoPassArray;
  drawPaths: TIsoPathArray;
  gcode: TStringList;
  shapeCount, p: Integer;
begin
  if FGerberFile = '' then
  begin
    SetStatus(T('Open a Gerber file first.'), True);
    Exit;
  end;

  raw := TStringList.Create;
  try
    try
      raw.LoadFromFile(FGerberFile);
    except
      on E: Exception do
      begin
        SetStatus(Format(T('Could not read file: %s'), [E.Message]), True);
        Exit;
      end;
    end;

    SetLength(lines, raw.Count);
    for i := 0 to raw.Count - 1 do lines[i] := raw[i];
  finally
    raw.Free;
  end;

  if not ParseGerberLines(lines, feats, units, warnings) then
  begin
    SetStatus(T('Gerber parse failed - see warnings.'), True);
    Exit;
  end;

  // Phase 40: mirror the ALREADY-parsed geometry before either toolpath
  // generator ever sees it - both GenerateDrawToolpaths and
  // GenerateIsolationToolpaths stay completely unaware this happened.
  if ChkMirror.Checked then
    feats := MirrorFeaturesX(feats, EdMirrorAxisX.Value);

  cfg := ConfigFromUI;
  laserCfg := LaserConfigFromUI;
  gcode := TStringList.Create;
  try
    if IsDraw then
    begin
      // Draw (CNC only): follow the raw parsed geometry directly, no
      // offsetting - GenerateDrawToolpaths never raises EGenerateError
      // (no Passes/ToolDiameter validation applies to it), but
      // AppendDrawGCode still validates the shared CNC depth fields.
      drawPaths := GenerateDrawToolpaths(feats);
      shapeCount := Length(drawPaths);
      if shapeCount = 0 then
      begin
        SetStatus(T('No copper found - nothing to draw.'), True);
        Exit;
      end;
      try
        AppendDrawGCode(drawPaths, cfg, gcode);
      except
        // uisolationrouting's own EGenerateError, explicitly qualified -
        // uregistrationholes (Phase 40) declares an unrelated class of
        // the same short name, and a bare reference would silently pick
        // whichever unit comes later in this file's own uses clause.
        on E: uisolationrouting.EGenerateError do
        begin
          SetStatus(E.Message, True);
          Exit;
        end;
      end;
      if Length(warnings) > 0 then
        SetStatus(Format(T('%d drawn shapes, %d parser warnings (see file for detail).'), [shapeCount, Length(warnings)]), False)
      else
        SetStatus(Format(T('%d drawn shapes generated.'), [shapeCount]), False);
    end
    else
    begin
      // Isolate (CNC or laser): the existing Phase 33 offset-ring pipeline.
      try
        passes := GenerateIsolationToolpaths(feats, cfg);
      except
        on E: uisolationrouting.EGenerateError do
        begin
          SetStatus(E.Message, True);
          Exit;
        end;
      end;

      shapeCount := 0;
      for p := 0 to High(passes) do
        shapeCount := shapeCount + Length(passes[p]);

      if shapeCount = 0 then
      begin
        SetStatus(T('No copper found - nothing to isolate.'), True);
        Exit;
      end;

      if IsLaser then
        AppendIsolationGCodeLaser(passes, laserCfg, gcode)
      else
        AppendIsolationGCode(passes, cfg, gcode);

      if Length(warnings) > 0 then
        SetStatus(Format(T('%d isolation rings, %d parser warnings (see file for detail).'), [shapeCount, Length(warnings)]), False)
      else
        SetStatus(Format(T('%d isolation rings generated.'), [shapeCount]), False);
    end;

    if Assigned(FOnGenerated) then FOnGenerated(gcode.Text);
  finally
    gcode.Free;
  end;
end;

end.
