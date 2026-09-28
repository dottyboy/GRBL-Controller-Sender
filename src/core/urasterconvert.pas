unit urasterconvert;

{ urasterconvert: orchestrates image -> grayscale -> tool mode -> dither/
  scan -> S-value g-code (plan Phase 10). Pure/LCL-free except for
  TGrayscaleImage's definition (uimageio.pas) - still isolates the actual
  BGRABitmap dependency to uimageio.pas alone, since this unit only reads
  the already-decoded TGrayscaleImage record, never touches BGRABitmap
  itself.

  Two tool modes, mirroring LaserGRBL's real distinction (RasterConverter/
  ImageProcessor.cs's Tool.Dithering vs Tool.Line2Line): Dithering fixes
  laser power at MaxPower and varies apparent darkness via on/off dot
  density (uditherers.pas); Line-to-line keeps the laser continuously on
  and varies S proportionally to each pixel's grayscale value instead -
  no dithering pattern, a smoother gradient look but no true halftone.

  Every scan-path pixel is checked for physical 8-adjacency to the
  previous one (not just "was the laser already on") - both Horizontal
  (row-wrap: end of one row to the start of the next is NOT adjacent) and
  Diagonal (anti-diagonal boundaries are NOT adjacent) directions have
  real discontinuities that must break the laser (M5 + G0 + M3), not just
  the "off" pixels a naive per-pixel on/off check alone would catch. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uimageio, uditherers, uscandirections;

type
  TRasterToolMode = (rtmDithering, rtmLineToLine);

  TRasterConvertOptions = record
    ToolMode: TRasterToolMode;
    DitherAlgorithm: TDitherAlgorithm; // rtmDithering only
    Threshold: Byte;                  // rtmDithering only, 0..255, default 128
    Direction: TScanDirection;
    MinPower, MaxPower: Double;       // S-value range (rtmDithering only uses MaxPower)
    FeedRate: Double;                 // mm/min
    PixelSizeMM: Double;              // real-world size of one image pixel
    Invert: Boolean;                  // True: lighter pixels burn harder (photo negative)
  end;

function DefaultRasterOptions: TRasterConvertOptions;
function GenerateRasterProgram(const AImage: TGrayscaleImage;
  const AOptions: TRasterConvertOptions): TStringList;

implementation

var
  InvFS: TFormatSettings;

function FmtNum(AValue: Double): string;
begin
  Result := FormatFloat('0.###', AValue, InvFS);
  if Result = '-0' then Result := '0';
end;

function DefaultRasterOptions: TRasterConvertOptions;
begin
  Result.ToolMode := rtmDithering;
  Result.DitherAlgorithm := daFloydSteinberg;
  Result.Threshold := 128;
  Result.Direction := sdHorizontal;
  Result.MinPower := 0;
  Result.MaxPower := 255;
  Result.FeedRate := 1500;
  Result.PixelSizeMM := 0.1;
  Result.Invert := False;
end;

function GenerateRasterProgram(const AImage: TGrayscaleImage;
  const AOptions: TRasterConvertOptions): TStringList;
var
  bitonal: TBitonalImage;
  path: TPixelPath;
  i: Integer;
  px, py, prevX, prevY: Integer;
  wx, wy: Double;
  wantOn, adjacent, laserArmed: Boolean;
  power: Double;
  gray: Byte;
begin
  Result := TStringList.Create;
  Result.Add('G21');
  Result.Add('G90');

  if (AImage.Width <= 0) or (AImage.Height <= 0) then Exit;

  if AOptions.ToolMode = rtmDithering then
    bitonal := DitherImage(AImage.Pixels, AImage.Width, AImage.Height,
      AOptions.DitherAlgorithm, AOptions.Threshold)
  else
    SetLength(bitonal, 0);

  path := BuildScanPath(AImage.Width, AImage.Height, AOptions.Direction);
  laserArmed := False;
  prevX := -999;
  prevY := -999;

  for i := 0 to High(path) do
  begin
    px := path[i].X;
    py := path[i].Y;
    wx := px * AOptions.PixelSizeMM;
    wy := (AImage.Height - 1 - py) * AOptions.PixelSizeMM; // flip: image row 0 (top) -> max Y

    if AOptions.ToolMode = rtmDithering then
    begin
      wantOn := bitonal[py * AImage.Width + px];
      if AOptions.Invert then wantOn := not wantOn;
      power := AOptions.MaxPower;
    end
    else
    begin
      wantOn := True;
      gray := GrayscaleAt(AImage, px, py);
      if AOptions.Invert then
        power := AOptions.MinPower + (gray / 255.0) * (AOptions.MaxPower - AOptions.MinPower)
      else
        power := AOptions.MinPower + (1.0 - gray / 255.0) * (AOptions.MaxPower - AOptions.MinPower);
    end;

    adjacent := laserArmed and (Abs(px - prevX) <= 1) and (Abs(py - prevY) <= 1);

    if wantOn then
    begin
      if not adjacent then
      begin
        if laserArmed then Result.Add('M5');
        Result.Add(Format('G0 X%s Y%s', [FmtNum(wx), FmtNum(wy)]));
        Result.Add(Format('M3 S%s', [FmtNum(power)]));
        laserArmed := True;
      end
      else
        Result.Add(Format('G1 X%s Y%s F%s S%s', [FmtNum(wx), FmtNum(wy), FmtNum(AOptions.FeedRate), FmtNum(power)]));
    end
    else if laserArmed then
    begin
      Result.Add('M5');
      laserArmed := False;
    end;

    prevX := px;
    prevY := py;
  end;

  if laserArmed then Result.Add('M5');
end;

initialization
  InvFS := DefaultFormatSettings;
  InvFS.DecimalSeparator := '.';
  InvFS.ThousandSeparator := #0;

end.
