unit ugerberimportframe;

{ TGerberImportFrame: the "Gerber Import" tab (plan Phase 33) - loads a
  Gerber (RS-274X) file, offsets an isolation-routing toolpath around its
  copper using ugerberimport.pas + uisolationrouting.pas, and hands the
  resulting G-code to the same Generate -> Editor -> 3D View pipeline
  every other generator frame in this app already uses (see
  usvgimportframe.pas/uspoilboardframe.pas's own TOnGenerated pattern). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls, Dialogs,
  Spin, ugerberimport, uisolationrouting, ui18n;

type
  TOnGenerated = procedure(const AProgramText: string) of object;

  { TGerberImportFrame }

  TGerberImportFrame = class(TFrame)
    BtnGenerate: TButton;
    BtnOpenGerber: TButton;
    EdCutDepth: TFloatSpinEdit;
    EdDepthPerPass: TFloatSpinEdit;
    EdFeedRate: TSpinEdit;
    EdIsolationGap: TFloatSpinEdit;
    EdPasses: TSpinEdit;
    EdPassStepover: TFloatSpinEdit;
    EdPlungeRate: TSpinEdit;
    EdSafeZ: TFloatSpinEdit;
    EdSpindleRPM: TSpinEdit;
    EdToolDiameter: TFloatSpinEdit;
    LblCutDepth: TLabel;
    LblDepthPerPass: TLabel;
    LblFeedRate: TLabel;
    LblGerberFile: TLabel;
    LblIsolationGap: TLabel;
    LblPasses: TLabel;
    LblPassStepover: TLabel;
    LblPlungeRate: TLabel;
    LblSafeZ: TLabel;
    LblSpindleRPM: TLabel;
    LblStatus: TLabel;
    LblToolDiameter: TLabel;
    procedure BtnGenerateClick(Sender: TObject);
    procedure BtnOpenGerberClick(Sender: TObject);
  private
    FDialog: TOpenDialog;
    FGerberFile: string;
    FOnGenerated: TOnGenerated;
    procedure SetStatus(const AMsg: string; AIsError: Boolean);
    function ConfigFromUI: TIsolationConfig;
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
end;

procedure TGerberImportFrame.SetStatus(const AMsg: string; AIsError: Boolean);
begin
  LblStatus.Caption := AMsg;
  if AIsError then
    LblStatus.Font.Color := clRed
  else
    LblStatus.Font.Color := clGreen;
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
  passes: TIsoPassArray;
  gcode: TStringList;
  ringCount, p: Integer;
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

  cfg := ConfigFromUI;
  try
    passes := GenerateIsolationToolpaths(feats, cfg);
  except
    on E: EGenerateError do
    begin
      SetStatus(E.Message, True);
      Exit;
    end;
  end;

  ringCount := 0;
  for p := 0 to High(passes) do
    ringCount := ringCount + Length(passes[p]);

  if ringCount = 0 then
  begin
    SetStatus(T('No copper found - nothing to isolate.'), True);
    Exit;
  end;

  gcode := TStringList.Create;
  try
    AppendIsolationGCode(passes, cfg, gcode);
    if Length(warnings) > 0 then
      SetStatus(Format(T('%d isolation rings, %d parser warnings (see file for detail).'), [ringCount, Length(warnings)]), False)
    else
      SetStatus(Format(T('%d isolation rings generated.'), [ringCount]), False);
    if Assigned(FOnGenerated) then FOnGenerated(gcode.Text);
  finally
    gcode.Free;
  end;
end;

end.
