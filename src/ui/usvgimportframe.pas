unit usvgimportframe;

{ TSvgImportFrame: the "SVG / Vectorize" tab (plan Phase 12) - three
  related import paths sharing one Generate pipeline:
   - Import SVG: loads a .svg file's shapes directly (usvgimport.pas)
   - Vectorize: loads a raster image (reusing uimageio.pas) and traces it
     into closed polygons (uvectorize.pas)
   - Centerline: shells to system `autotrace -centerline` (uautotrace.pas)
     on a loaded raster image

  All three converge on the same TSvgShapeArray-or-TPolygonArray ->
  g-code step: each shape/polygon becomes G0 (laser off) to its first
  point, M3, G1 through the remaining points, M5 - a straight outline
  follow, NOT interior fill-hatching (Clipper-based fill is deliberately
  deferred, see uvectorize.pas's own doc comment). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls, Dialogs,
  Spin, uimageio, uvectorize, usvgimport, uautotrace, ui18n;

type
  TOnGenerated = procedure(const AProgramText: string) of object;

  { TSvgImportFrame }

  TSvgImportFrame = class(TFrame)
    BtnCenterline: TButton;
    BtnGenerateShapes: TButton;
    BtnGenerateVector: TButton;
    BtnOpenImage: TButton;
    BtnOpenSvg: TButton;
    BtnVectorize: TButton;
    EdFeedRate: TSpinEdit;
    EdPixelSize: TFloatSpinEdit;
    EdPower: TSpinEdit;
    EdThreshold: TSpinEdit;
    LblFeedRate: TLabel;
    LblImageFile: TLabel;
    LblPixelSize: TLabel;
    LblPower: TLabel;
    LblStatus: TLabel;
    LblSvgFile: TLabel;
    LblThreshold: TLabel;
    procedure BtnCenterlineClick(Sender: TObject);
    procedure BtnGenerateShapesClick(Sender: TObject);
    procedure BtnGenerateVectorClick(Sender: TObject);
    procedure BtnOpenImageClick(Sender: TObject);
    procedure BtnOpenSvgClick(Sender: TObject);
    procedure BtnVectorizeClick(Sender: TObject);
  private
    FSvgDialog, FImageDialog: TOpenDialog;
    FSvgFile, FImageFile: string;
    FSvgShapes: TSvgShapeArray;
    FVectorPolys: TPolygonArray;
    FOnGenerated: TOnGenerated;
    procedure SetStatus(const AMsg: string; AIsError: Boolean);
    function ShapesToGCode(const AShapes: TSvgShapeArray): string;
    function PolygonsToGCode(const APolys: TPolygonArray): string;
  public
    constructor Create(AOwner: TComponent); override;
    // ImportFile: plan Phase 22 (SincroStart's IMPORT_SVG:<path> message) -
    // programmatic equivalent of "Open SVG..." followed by "Generate from
    // SVG", for a caller (umain.pas) that already has a path in hand and
    // isn't going through the Open-file dialog.
    procedure ImportFile(const AFileName: string);
    property OnGenerated: TOnGenerated read FOnGenerated write FOnGenerated;
  end;

implementation

{$R *.frm}

{ TSvgImportFrame }

constructor TSvgImportFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSvgDialog := TOpenDialog.Create(Self);
  FSvgDialog.Filter := 'SVG files (*.svg)|*.svg|All files (*.*)|*.*';
  FImageDialog := TOpenDialog.Create(Self);
  FImageDialog.Filter := 'Image files (*.png;*.jpg;*.jpeg;*.bmp;*.gif)|*.png;*.jpg;*.jpeg;*.bmp;*.gif|All files (*.*)|*.*';
end;

procedure TSvgImportFrame.SetStatus(const AMsg: string; AIsError: Boolean);
begin
  LblStatus.Caption := AMsg;
  if AIsError then
    LblStatus.Font.Color := clRed
  else
    LblStatus.Font.Color := clGreen;
end;

function FmtG(AValue: Double): string;
begin
  Result := FormatFloat('0.###', AValue);
end;

function TSvgImportFrame.ShapesToGCode(const AShapes: TSvgShapeArray): string;
var
  lines: TStringList;
  s, i: Integer;
  scale: Double;
begin
  scale := EdPixelSize.Value;
  lines := TStringList.Create;
  try
    lines.Add('G21');
    lines.Add('G90');
    for s := 0 to High(AShapes) do
    begin
      if Length(AShapes[s].Points) = 0 then Continue;
      lines.Add(Format('G0 X%s Y%s', [FmtG(AShapes[s].Points[0].X * scale), FmtG(AShapes[s].Points[0].Y * scale)]));
      lines.Add(Format('M3 S%d', [EdPower.Value]));
      for i := 1 to High(AShapes[s].Points) do
        lines.Add(Format('G1 X%s Y%s F%d', [FmtG(AShapes[s].Points[i].X * scale), FmtG(AShapes[s].Points[i].Y * scale), EdFeedRate.Value]));
      lines.Add('M5');
    end;
    Result := lines.Text;
  finally
    lines.Free;
  end;
end;

function TSvgImportFrame.PolygonsToGCode(const APolys: TPolygonArray): string;
var
  lines: TStringList;
  s, i: Integer;
  scale: Double;
begin
  scale := EdPixelSize.Value;
  lines := TStringList.Create;
  try
    lines.Add('G21');
    lines.Add('G90');
    for s := 0 to High(APolys) do
    begin
      if Length(APolys[s]) = 0 then Continue;
      lines.Add(Format('G0 X%s Y%s', [FmtG(APolys[s][0].X * scale), FmtG(APolys[s][0].Y * scale)]));
      lines.Add(Format('M3 S%d', [EdPower.Value]));
      for i := 1 to High(APolys[s]) do
        lines.Add(Format('G1 X%s Y%s F%d', [FmtG(APolys[s][i].X * scale), FmtG(APolys[s][i].Y * scale), EdFeedRate.Value]));
      lines.Add('M5');
    end;
    Result := lines.Text;
  finally
    lines.Free;
  end;
end;

procedure TSvgImportFrame.ImportFile(const AFileName: string);
begin
  FSvgFile := AFileName;
  LblSvgFile.Caption := ExtractFileName(FSvgFile);
  BtnGenerateShapesClick(Self);
end;

procedure TSvgImportFrame.BtnOpenSvgClick(Sender: TObject);
begin
  if not FSvgDialog.Execute then Exit;
  FSvgFile := FSvgDialog.FileName;
  LblSvgFile.Caption := ExtractFileName(FSvgFile);
  SetStatus('', False);
end;

procedure TSvgImportFrame.BtnOpenImageClick(Sender: TObject);
begin
  if not FImageDialog.Execute then Exit;
  FImageFile := FImageDialog.FileName;
  LblImageFile.Caption := ExtractFileName(FImageFile);
  SetStatus('', False);
end;

procedure TSvgImportFrame.BtnGenerateShapesClick(Sender: TObject);
var
  err: string;
begin
  if FSvgFile = '' then
  begin
    SetStatus(T('Nothing to run'), True);
    Exit;
  end;
  if not LoadSvgShapes(FSvgFile, FSvgShapes, err) then
  begin
    SetStatus(err, True);
    Exit;
  end;
  if Assigned(FOnGenerated) then
    FOnGenerated(ShapesToGCode(FSvgShapes));
  SetStatus(Format('%d shapes', [Length(FSvgShapes)]), False);
end;

procedure TSvgImportFrame.BtnVectorizeClick(Sender: TObject);
var
  img: TGrayscaleImage;
  err: string;
begin
  if FImageFile = '' then
  begin
    SetStatus(T('Nothing to run'), True);
    Exit;
  end;
  if not LoadGrayscaleImage(FImageFile, img, err) then
  begin
    SetStatus(err, True);
    Exit;
  end;
  FVectorPolys := VectorizeGrayscale(img, EdThreshold.Value);
  SetStatus(Format('%d closed paths', [Length(FVectorPolys)]), False);
end;

procedure TSvgImportFrame.BtnGenerateVectorClick(Sender: TObject);
begin
  if Length(FVectorPolys) = 0 then
  begin
    SetStatus(T('Nothing to run'), True);
    Exit;
  end;
  if Assigned(FOnGenerated) then
    FOnGenerated(PolygonsToGCode(FVectorPolys));
end;

procedure TSvgImportFrame.BtnCenterlineClick(Sender: TObject);
var
  img: TGrayscaleImage;
  err: string;
  shapes: TSvgShapeArray;
begin
  if FImageFile = '' then
  begin
    SetStatus(T('Nothing to run'), True);
    Exit;
  end;
  if not LoadGrayscaleImage(FImageFile, img, err) then
  begin
    SetStatus(err, True);
    Exit;
  end;
  if not RunAutotraceCenterline(img, shapes, err) then
  begin
    SetStatus(err, True);
    Exit;
  end;
  if Assigned(FOnGenerated) then
    FOnGenerated(ShapesToGCode(shapes));
  SetStatus(Format('%d centerline shapes', [Length(shapes)]), False);
end;

end.
