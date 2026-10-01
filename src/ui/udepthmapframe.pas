unit udepthmapframe;

{ TDepthMapFrame: Phase 23's "photo -> real depth-map" tab, a tab (not a
  modal, per this project's standing Phase 41 rule) that loads a photo,
  runs it through udepthmap.pas's ONNX depth-estimation pipeline, and
  hands the resulting grayscale depth map to the existing Raster Import
  tab via its own file-based ImportFile - the same bridge-by-file pattern
  Phases 27/28/29 already use for external tools, reused here for an
  in-process hand-off instead of duplicating any dithering/G-code logic.

  Two explicit steps rather than one auto-chaining action: "Load Photo..."
  runs the (several-second) ONNX inference and shows its own result/error
  status before anything else happens; "Send to Raster Import" only then
  does the hand-off and switches tabs. Keeps a failed/slow inference from
  silently jumping the user to a different tab with nothing to show. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, Dialogs,
  uimageio, udepthmap, ui18n;

type
  TOnDepthMapReady = procedure(const APngPath: string) of object;

  { TDepthMapFrame }

  TDepthMapFrame = class(TFrame)
    BtnLoadPhoto: TButton;
    BtnSendToRaster: TButton;
    LblFile: TLabel;
    LblStatus: TLabel;
    procedure BtnLoadPhotoClick(Sender: TObject);
    procedure BtnSendToRasterClick(Sender: TObject);
  private
    FOpenDialog: TOpenDialog;
    FOnDepthMapReady: TOnDepthMapReady;
    FDepthMap: TDepthMapImage;
    FHasDepthMap: Boolean;
    procedure SetStatus(const AMsg: string; AIsError: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
    property OnDepthMapReady: TOnDepthMapReady read FOnDepthMapReady write FOnDepthMapReady;
  end;

implementation

{$R *.frm}

{ TDepthMapFrame }

constructor TDepthMapFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FOpenDialog := TOpenDialog.Create(Self);
  FOpenDialog.Filter := 'Image files (*.png;*.jpg;*.jpeg;*.bmp)|*.png;*.jpg;*.jpeg;*.bmp|All files (*.*)|*.*';
  FHasDepthMap := False;
  BtnSendToRaster.Enabled := False;
end;

procedure TDepthMapFrame.SetStatus(const AMsg: string; AIsError: Boolean);
begin
  LblStatus.Caption := AMsg;
  if AIsError then
    LblStatus.Font.Color := clRed
  else
    LblStatus.Font.Color := clGreen;
end;

procedure TDepthMapFrame.BtnLoadPhotoClick(Sender: TObject);
var
  err: string;
  runtimeLib, modelPath: string;
begin
  if not FOpenDialog.Execute then Exit;

  BtnSendToRaster.Enabled := False;
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
  i: Integer;
begin
  if not FHasDepthMap then Exit;

  grayImg.Width := FDepthMap.Width;
  grayImg.Height := FDepthMap.Height;
  SetLength(grayImg.Pixels, Length(FDepthMap.Pixels));
  for i := 0 to High(FDepthMap.Pixels) do
    grayImg.Pixels[i] := FDepthMap.Pixels[i];

  tmpPath := IncludeTrailingPathDelimiter(GetTempDir) + 'grbl-depthmap-preview.png';
  if not uimageio.SaveGrayscaleImage(grayImg, tmpPath, err) then
  begin
    SetStatus(err, True);
    Exit;
  end;

  if Assigned(FOnDepthMapReady) then
    FOnDepthMapReady(tmpPath);
end;

end.
