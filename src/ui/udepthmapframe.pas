unit udepthmapframe;

{ TDepthMapFrame: Phase 23's "photo -> real depth-map" tab, a tab (not a
  modal, per this project's standing Phase 41 rule) that loads a photo,
  runs it through udepthmap.pas's ONNX depth-estimation pipeline, and
  then offers it to either of two destinations:

  - "Send to Raster Import" hands it to the existing Raster Import tab
    via its own file-based ImportFile - the same bridge-by-file pattern
    Phases 27/28/29 already use for external tools - for a LASER job
    (power modulated by brightness, Z fixed).

  - "Generate CNC Relief" (user's own follow-up request: "depthmap
    možemo koristiti i u cnc modu za reljefe") runs the same depth map
    through the new ureliefmachining.pas instead, for a CNC job (Z
    modulated by brightness, true 3D surfacing) - goes straight to the
    Editor/3D View, the same destination every other G-code generator in
    this app uses, since none of Raster Import's own fields (power,
    invert-for-power, threshold) apply to a CNC relief pass.

  Three explicit steps rather than auto-chaining: "Load Photo..." runs
  the (several-second) ONNX inference and shows its own result/error
  status before anything else happens; either destination button only
  then acts on the already-computed depth map - keeps a failed/slow
  inference from silently jumping the user to a different tab with
  nothing to show. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, Spin, Dialogs,
  uimageio, udepthmap, uscandirections, ureliefmachining, ui18n;

type
  TOnDepthMapReady = procedure(const APngPath: string) of object;
  TOnReliefGenerated = procedure(const AProgramText: string) of object;

  { TDepthMapFrame }

  TDepthMapFrame = class(TFrame)
    BtnLoadPhoto: TButton;
    BtnSendToRaster: TButton;
    BtnGenerateRelief: TButton;
    CboDirection: TComboBox;
    ChkInvert: TCheckBox;
    EdPixelSize: TFloatSpinEdit;
    EdMaxDepth: TFloatSpinEdit;
    EdFeedRate: TSpinEdit;
    EdSafeZ: TFloatSpinEdit;
    LblDirection: TLabel;
    LblFeedRate: TLabel;
    LblFile: TLabel;
    LblMaxDepth: TLabel;
    LblPixelSize: TLabel;
    LblReliefGroup: TLabel;
    LblSafeZ: TLabel;
    LblStatus: TLabel;
    procedure BtnLoadPhotoClick(Sender: TObject);
    procedure BtnSendToRasterClick(Sender: TObject);
    procedure BtnGenerateReliefClick(Sender: TObject);
  private
    FOpenDialog: TOpenDialog;
    FOnDepthMapReady: TOnDepthMapReady;
    FOnReliefGenerated: TOnReliefGenerated;
    FDepthMap: TDepthMapImage;
    FHasDepthMap: Boolean;
    procedure SetStatus(const AMsg: string; AIsError: Boolean);
    function DepthMapAsGrayscale: TGrayscaleImage;
  public
    constructor Create(AOwner: TComponent); override;
    property OnDepthMapReady: TOnDepthMapReady read FOnDepthMapReady write FOnDepthMapReady;
    property OnReliefGenerated: TOnReliefGenerated read FOnReliefGenerated write FOnReliefGenerated;
  end;

implementation

{$R *.frm}

{ TDepthMapFrame }

constructor TDepthMapFrame.Create(AOwner: TComponent);
var
  cfg: TReliefConfig;
begin
  inherited Create(AOwner);
  FOpenDialog := TOpenDialog.Create(Self);
  FOpenDialog.Filter := 'Image files (*.png;*.jpg;*.jpeg;*.bmp)|*.png;*.jpg;*.jpeg;*.bmp|All files (*.*)|*.*';
  FHasDepthMap := False;
  BtnSendToRaster.Enabled := False;
  BtnGenerateRelief.Enabled := False;

  CboDirection.Items.Add(T('Horizontal'));
  CboDirection.Items.Add(T('Vertical'));
  CboDirection.Items.Add(T('Diagonal'));
  CboDirection.Items.Add(T('ZigZag'));

  cfg := DefaultReliefConfig;
  EdPixelSize.Value := cfg.PixelSizeMM;
  EdMaxDepth.Value := cfg.MaxDepthMM;
  EdFeedRate.Value := Round(cfg.FeedRate);
  EdSafeZ.Value := cfg.SafeZ;
  CboDirection.ItemIndex := Ord(cfg.Direction);
  ChkInvert.Checked := cfg.Invert;
end;

procedure TDepthMapFrame.SetStatus(const AMsg: string; AIsError: Boolean);
begin
  LblStatus.Caption := AMsg;
  if AIsError then
    LblStatus.Font.Color := clRed
  else
    LblStatus.Font.Color := clGreen;
end;

function TDepthMapFrame.DepthMapAsGrayscale: TGrayscaleImage;
var
  i: Integer;
begin
  Result.Width := FDepthMap.Width;
  Result.Height := FDepthMap.Height;
  SetLength(Result.Pixels, Length(FDepthMap.Pixels));
  for i := 0 to High(FDepthMap.Pixels) do
    Result.Pixels[i] := FDepthMap.Pixels[i];
end;

procedure TDepthMapFrame.BtnLoadPhotoClick(Sender: TObject);
var
  err: string;
  runtimeLib, modelPath: string;
begin
  if not FOpenDialog.Execute then Exit;

  BtnSendToRaster.Enabled := False;
  BtnGenerateRelief.Enabled := False;
  FHasDepthMap := False;
  LblFile.Caption := ExtractFileName(FOpenDialog.FileName);
  SetStatus(T('Generating depth map (a few seconds)...'), False);
  BtnLoadPhoto.Enabled := False;
  Application.ProcessMessages; // paint the status before the blocking inference call

  runtimeLib := DefaultOnnxRuntimeLibPath;
  modelPath := DefaultDepthModelPath;

  if not FileExists(runtimeLib) then
  begin
    SetStatus(Format(T('ONNX Runtime not found at %s - see packaging/appimage/README.md'), [runtimeLib]), True);
    BtnLoadPhoto.Enabled := True;
    Exit;
  end;
  if not FileExists(modelPath) then
  begin
    SetStatus(Format(T('Depth model not found at %s - see packaging/appimage/README.md'), [modelPath]), True);
    BtnLoadPhoto.Enabled := True;
    Exit;
  end;

  if GenerateDepthMap(FOpenDialog.FileName, modelPath, runtimeLib, FDepthMap, err) then
  begin
    FHasDepthMap := True;
    BtnSendToRaster.Enabled := True;
    BtnGenerateRelief.Enabled := True;
    SetStatus(Format(T('Depth map ready: %dx%d'), [FDepthMap.Width, FDepthMap.Height]), False);
  end
  else
    SetStatus(err, True);

  BtnLoadPhoto.Enabled := True;
end;

procedure TDepthMapFrame.BtnSendToRasterClick(Sender: TObject);
var
  grayImg: TGrayscaleImage;
  tmpPath: string;
  err: string;
begin
  if not FHasDepthMap then Exit;

  grayImg := DepthMapAsGrayscale;
  tmpPath := IncludeTrailingPathDelimiter(GetTempDir) + 'grbl-depthmap-preview.png';
  if not uimageio.SaveGrayscaleImage(grayImg, tmpPath, err) then
  begin
    SetStatus(err, True);
    Exit;
  end;

  if Assigned(FOnDepthMapReady) then
    FOnDepthMapReady(tmpPath);
end;

procedure TDepthMapFrame.BtnGenerateReliefClick(Sender: TObject);
var
  grayImg: TGrayscaleImage;
  cfg: TReliefConfig;
  prog: TStringList;
begin
  if not FHasDepthMap then Exit;

  grayImg := DepthMapAsGrayscale;

  cfg.PixelSizeMM := EdPixelSize.Value;
  cfg.MaxDepthMM := EdMaxDepth.Value;
  cfg.FeedRate := EdFeedRate.Value;
  cfg.SafeZ := EdSafeZ.Value;
  cfg.Direction := TScanDirection(CboDirection.ItemIndex);
  cfg.Invert := ChkInvert.Checked;

  prog := GenerateReliefProgram(grayImg, cfg);
  try
    if Assigned(FOnReliefGenerated) then
      FOnReliefGenerated(prog.Text);
    SetStatus(Format(T('CNC relief generated: %d lines'), [prog.Count]), False);
  finally
    prog.Free;
  end;
end;

end.
