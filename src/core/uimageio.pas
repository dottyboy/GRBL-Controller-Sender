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

function LoadGrayscaleImage(const AFileName: string; out AImage: TGrayscaleImage;
  out AError: string): Boolean;
function GrayscaleAt(const AImage: TGrayscaleImage; AX, AY: Integer): Byte; inline;

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

end.
