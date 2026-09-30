unit uimageio;

{ uimageio: the ONE unit in this project (plan Phase 10) allowed to touch
  BGRABitmap directly - loads a raster image file (PNG/JPEG/BMP/... - real
  format readers BGRABitmap already ships) and converts it to a plain
  grayscale byte matrix. Everything downstream (uditherers.pas,
  uscandirections.pas, urasterconvert.pas) works ONLY with TGrayscaleImage,
  never touches BGRABitmap - keeps the BGRA dependency isolated/auditable,
  per this project's own architecture decision (see the plan file's Phase
  10 note).

  Grayscale uses the standard ITU-R BT.601 luminance weights
  (0.299R+0.587G+0.114B) - NOT BGRABitmap's own GetIntensity (which is
  gamma-expanded HSV "value" = max(r,g,b), a different and less
  appropriate notion for engraving darkness than actual luminance).
  Transparent/semi-transparent pixels are blended toward white (255) by
  alpha - a fully transparent pixel engraves as blank stock, not black. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, BGRABitmap, BGRABitmapTypes;

type
  TGrayscaleImage = record
    Width, Height: Integer;
    Pixels: array of Byte; // row-major (row 0 = top), one byte per pixel
  end;

  TRGBImage = record
    Width, Height: Integer;
    Pixels: array of Byte; // row-major, 3 bytes/pixel (R,G,B), no alpha
  end;

function LoadGrayscaleImage(const AFileName: string; out AImage: TGrayscaleImage;
  out AError: string): Boolean;
function GrayscaleAt(const AImage: TGrayscaleImage; AX, AY: Integer): Byte; inline;

{ Loads AFileName and resamples it to ASize x ASize (square, matching a
  fixed ML model input size - Phase 23's depth-map model wants 518x518),
  also returning the image's original (pre-resample) dimensions in
  AOrigWidth/AOrigHeight so the caller can resize its output back.
  Transparent pixels blend toward white, same convention as
  LoadGrayscaleImage above. }
function LoadRGBImageResized(const AFileName: string; ASize: Integer;
  out AImage: TRGBImage; out AOrigWidth, AOrigHeight: Integer;
  out AError: string): Boolean;

implementation

function GrayscaleAt(const AImage: TGrayscaleImage; AX, AY: Integer): Byte;
begin
  Result := AImage.Pixels[AY * AImage.Width + AX];
end;

function LoadGrayscaleImage(const AFileName: string; out AImage: TGrayscaleImage;
  out AError: string): Boolean;
var
  bmp: TBGRABitmap;
  x, y: Integer;
  p: TBGRAPixel;
  lum, a: Double;
begin
  Result := False;
  AError := '';
  AImage.Width := 0;
  AImage.Height := 0;
  SetLength(AImage.Pixels, 0);

  if not FileExists(AFileName) then
  begin
    AError := 'File not found: ' + AFileName;
    Exit;
  end;

  bmp := nil;
  try
    try
      bmp := TBGRABitmap.Create(AFileName);
    except
      on E: Exception do
      begin
        AError := E.Message;
        Exit;
      end;
    end;

    if (bmp.Width <= 0) or (bmp.Height <= 0) then
    begin
      AError := 'Image has no pixels';
      Exit;
    end;

    AImage.Width := bmp.Width;
    AImage.Height := bmp.Height;
    SetLength(AImage.Pixels, AImage.Width * AImage.Height);

    for y := 0 to AImage.Height - 1 do
      for x := 0 to AImage.Width - 1 do
      begin
        p := bmp.GetPixel(x, y);
        lum := 0.299 * p.red + 0.587 * p.green + 0.114 * p.blue;
        a := p.alpha / 255.0;
        AImage.Pixels[y * AImage.Width + x] := Round(lum * a + 255.0 * (1.0 - a));
      end;

    Result := True;
  finally
    bmp.Free;
  end;
end;

function LoadRGBImageResized(const AFileName: string; ASize: Integer;
  out AImage: TRGBImage; out AOrigWidth, AOrigHeight: Integer;
  out AError: string): Boolean;
var
  bmp, resized: TBGRABitmap;
  x, y: Integer;
  p: TBGRAPixel;
  a: Double;
begin
  Result := False;
  AError := '';
  AOrigWidth := 0;
  AOrigHeight := 0;
  AImage.Width := 0;
  AImage.Height := 0;
  SetLength(AImage.Pixels, 0);

  if not FileExists(AFileName) then
  begin
    AError := 'File not found: ' + AFileName;
    Exit;
  end;

  bmp := nil;
  resized := nil;
  try
    try
      bmp := TBGRABitmap.Create(AFileName);
    except
      on E: Exception do
      begin
        AError := E.Message;
        Exit;
      end;
    end;

    if (bmp.Width <= 0) or (bmp.Height <= 0) then
    begin
      AError := 'Image has no pixels';
      Exit;
    end;

    AOrigWidth := bmp.Width;
    AOrigHeight := bmp.Height;

    resized := bmp.Resample(ASize, ASize, rmFineResample) as TBGRABitmap;

    AImage.Width := ASize;
    AImage.Height := ASize;
    SetLength(AImage.Pixels, ASize * ASize * 3);

    for y := 0 to ASize - 1 do
      for x := 0 to ASize - 1 do
      begin
        p := resized.GetPixel(x, y);
        a := p.alpha / 255.0;
        AImage.Pixels[(y * ASize + x) * 3 + 0] := Round(p.red * a + 255.0 * (1.0 - a));
        AImage.Pixels[(y * ASize + x) * 3 + 1] := Round(p.green * a + 255.0 * (1.0 - a));
        AImage.Pixels[(y * ASize + x) * 3 + 2] := Round(p.blue * a + 255.0 * (1.0 - a));
      end;

    Result := True;
  finally
    resized.Free;
    bmp.Free;
  end;
end;

end.
