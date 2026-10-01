unit ureliefmachining;

{ ureliefmachining: turns a grayscale height map (Phase 23's depth map, or
  any other grayscale image) into a true 3D CNC surfacing toolpath -
  continuous X/Y/Z motion tracing the image's own height, as opposed to
  Phase 10's urasterconvert.pas which keeps Z fixed and modulates LASER
  POWER instead. User's own framing: "depthmap možemo koristiti i u cnc
  modu za reljefe" (we could also use the depth map in CNC mode for
  reliefs).

  Deliberately a drop-cutter approximation, not true ball-nose radius
  compensation: each sample point's Z is read straight from the height
  map with no correction for the cutter's own geometry. This is the same
  simplification most lightweight relief-carving tools make (true radius
  compensation needs a full 3D CAM engine, well beyond a single-tool
  scan-line pass) - acceptable as long as the pixel size (the scan's own
  stepover) is small relative to the tool's radius, same caveat this
  project's spoilboard-facing code leaves to the user's own tool/stepover
  choice rather than trying to enforce it.

  Height convention matches udepthmap.pas's own documented one: byte 255
  is the NEAREST point in the source photo, byte 0 the FARTHEST - so
  without Invert, 255 maps to Z=0 (the work surface, shallowest) and 0
  maps to Z=-MaxDepthMM (the deepest cut), i.e. "closer in the photo" =
  "stands proud of the relief". Invert flips which end is which, same
  vocabulary urasterconvert.pas's own Invert option already uses.

  Unlike laser raster (free, instant "laser off" gaps), a CNC tool is
  physically touching material throughout a scan line, so any path
  discontinuity (a direction's own row/diagonal wrap - see
  uscandirections.pas) must retract to SafeZ before repositioning, not
  just skip ahead - gouging through intervening material otherwise.
  sdZigZag has NO discontinuities at all (every point is 4-adjacent to
  the next), so it never needs a mid-program retract - the natural
  default for this feature, though the other 3 directions are still
  supported (just slower, from the extra retract/plunge pairs). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uimageio, uscandirections;

type
  TReliefConfig = record
    PixelSizeMM: Double; // also the scan's own stepover - one image pixel per step
    MaxDepthMM: Double;  // how far below the work surface the deepest point cuts
    FeedRate: Double;    // mm/min, used for every cutting/plunge move alike
    SafeZ: Double;       // retract height (above Z=0, the work surface) between discontinuities
    Direction: TScanDirection;
    Invert: Boolean;
  end;

function DefaultReliefConfig: TReliefConfig;
function GenerateReliefProgram(const AImage: TGrayscaleImage;
  const AConfig: TReliefConfig): TStringList;

implementation

var
  InvFS: TFormatSettings;

function FmtNum(AValue: Double): string;
begin
  Result := FormatFloat('0.###', AValue, InvFS);
  if Result = '-0' then Result := '0';
end;

function DefaultReliefConfig: TReliefConfig;
begin
  Result.PixelSizeMM := 0.5;
  Result.MaxDepthMM := 5;
  Result.FeedRate := 800;
  Result.SafeZ := 5;
  Result.Direction := sdZigZag;
  Result.Invert := False;
end;

function GenerateReliefProgram(const AImage: TGrayscaleImage;
  const AConfig: TReliefConfig): TStringList;
var
  path: TPixelPath;
  i: Integer;
  px, py, prevX, prevY: Integer;
  wx, wy, wz: Double;
  gray: Byte;
  retracted: Boolean;
begin
  Result := TStringList.Create;
  Result.Add('G21');
  Result.Add('G90');

  if (AImage.Width <= 0) or (AImage.Height <= 0) then Exit;

  path := BuildScanPath(AImage.Width, AImage.Height, AConfig.Direction);
  prevX := -999;
  prevY := -999;
  retracted := True; // forces the very first point to rapid+plunge, not a bare G1

  for i := 0 to High(path) do
  begin
    px := path[i].X;
    py := path[i].Y;
    wx := px * AConfig.PixelSizeMM;
    wy := (AImage.Height - 1 - py) * AConfig.PixelSizeMM; // flip: image row 0 (top) -> max Y

    gray := GrayscaleAt(AImage, px, py);
    if AConfig.Invert then
      wz := -(gray / 255.0) * AConfig.MaxDepthMM
    else
      wz := -((255 - gray) / 255.0) * AConfig.MaxDepthMM;

    if not retracted and (Abs(px - prevX) <= 1) and (Abs(py - prevY) <= 1) then
      Result.Add(Format('G1 X%s Y%s Z%s F%s', [FmtNum(wx), FmtNum(wy), FmtNum(wz), FmtNum(AConfig.FeedRate)]))
    else
    begin
      if not retracted then
        Result.Add(Format('G0 Z%s', [FmtNum(AConfig.SafeZ)]));
      Result.Add(Format('G0 X%s Y%s', [FmtNum(wx), FmtNum(wy)]));
      Result.Add(Format('G1 Z%s F%s', [FmtNum(wz), FmtNum(AConfig.FeedRate)]));
      retracted := False;
    end;

    prevX := px;
    prevY := py;
  end;

  Result.Add(Format('G0 Z%s', [FmtNum(AConfig.SafeZ)]));
end;

initialization
  InvFS := DefaultFormatSettings;
  InvFS.DecimalSeparator := '.';
  InvFS.ThousandSeparator := #0;

end.
