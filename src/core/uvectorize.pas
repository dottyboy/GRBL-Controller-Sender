unit uvectorize;

{ uvectorize: traces a bitonal (thresholded) grayscale image into closed
  vector polygons (plan Phase 12). Wraps BGRABitmap's own real, working
  `VectorizeMonochrome` (bgravectorize.pas) rather than porting Potrace
  from scratch - a real, deliberate scope reduction found by reading the
  actual BGRA source before assuming a from-scratch port was needed (the
  same "check what's really available before building it yourself"
  discipline as uditherers.pas's own check of BGRA's dithering unit).

  Third and last unit in this project allowed to touch BGRABitmap
  directly (after uimageio.pas and usvgimport.pas), isolated the same way.

  Deliberately NOT included in this phase: Clipper-based polygon-fill
  hatching (filling a closed shape's INTERIOR with parallel scan lines,
  rather than just tracing its outline) and Bezier-to-biarc smoothing
  (G2/G3 arc output instead of polygon-approximated G1 segments) - both
  real, separate pieces of work, disclosed as deferred rather than
  attempted under this phase's time budget; this unit's own output
  (closed outline polygons) is exactly what the plan's Phase 12 "Done"
  bar asks for ("Vectorize on a Phase 10 test image produces a closed
  path"), just without interior fill-hatching on top of it yet. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, BGRABitmap, BGRABitmapTypes, BGRAVectorize, uimageio;

type
  TFloatPoint = record
    X, Y: Double;
  end;
  TPolygon = array of TFloatPoint;
  TPolygonArray = array of TPolygon;

// AThreshold: a pixel darker than this is treated as "foreground" (traced)
// - same 0..255 convention as uditherers.pas.
function VectorizeGrayscale(const AImage: TGrayscaleImage; AThreshold: Byte = 128): TPolygonArray;

implementation

function VectorizeGrayscale(const AImage: TGrayscaleImage; AThreshold: Byte): TPolygonArray;
var
  bmp: TBGRABitmap;
  x, y: Integer;
  raw: ArrayOfTPointF;
  i, polyStart, n: Integer;

  procedure FlushPoly(AFrom, AToExcl: Integer);
  var
    j, len: Integer;
  begin
    len := AToExcl - AFrom;
    if len < 3 then Exit; // not a real closed shape
    n := Length(Result);
    SetLength(Result, n + 1);
    SetLength(Result[n], len);
    for j := 0 to len - 1 do
    begin
      Result[n][j].X := raw[AFrom + j].X;
      Result[n][j].Y := raw[AFrom + j].Y;
    end;
  end;

begin
  SetLength(Result, 0);
  if (AImage.Width <= 0) or (AImage.Height <= 0) then Exit;

  bmp := TBGRABitmap.Create(AImage.Width, AImage.Height);
  try
    // VectorizeMonochrome reads the GREEN channel (per its own doc comment)
    // with AWhiteBackground=True meaning light green = background - paint
    // foreground (darker-than-threshold) pixels black, background white,
    // matching that convention directly rather than guessing at it.
    for y := 0 to AImage.Height - 1 do
      for x := 0 to AImage.Width - 1 do
        if GrayscaleAt(AImage, x, y) < AThreshold then
          bmp.SetPixel(x, y, BGRA(0, 0, 0))
        else
          bmp.SetPixel(x, y, BGRA(255, 255, 255));

    raw := VectorizeMonochrome(bmp, 1.0, False, True);

    polyStart := 0;
    for i := 0 to High(raw) do
    begin
      if isEmptyPointF(raw[i]) then
      begin
        FlushPoly(polyStart, i);
        polyStart := i + 1;
      end;
    end;
    FlushPoly(polyStart, Length(raw));
  finally
    bmp.Free;
  end;
end;

end.
