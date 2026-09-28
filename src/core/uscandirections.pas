unit uscandirections;

{ uscandirections: pixel-grid traversal order for raster engraving (plan
  Phase 10). Pure/LCL-free, matching uditherers.pas's own isolation.

  Scope correction, made after reading the real source rather than
  following the plan's original text blindly (this project's own standing
  discipline): the plan's Phase 10 text names all 10 "New*"-family
  directions (Horizontal/Vertical/Diagonal/ReverseDiagonal/Grid/
  DiagonalGrid/Cross/DiagonalCross/ZigZag/Squares). Reading LaserGRBL's
  real `GrblFile.cs` shows this 10-direction family is gated by
  `VectorFilling()` - used for hatching a filled VECTOR SHAPE (Phase 12's
  vectorize/fill territory) - while actual per-pixel RASTER scanning
  (`RasterFilling()`) only ever uses 3 plain directions: Horizontal,
  Vertical, Diagonal. This unit implements those 3, plus ZigZag (the
  standard boustrophedon efficiency optimization - alternating scan
  direction per row/column to avoid a wasted rapid-return on every line -
  a real, valuable, well-established raster technique in its own right,
  not exclusive to vector fill in general laser-engraving practice, even
  though LaserGRBL's own enum happens to file it under the vector-fill
  family). The remaining 6 directions (ReverseDiagonal/Grid/DiagonalGrid/
  Cross/DiagonalCross/Squares) plus Hilbert/InsetFilling are genuinely
  vector-fill-only concepts (filling an arbitrary closed polygon boundary,
  not a fixed rectangular pixel grid) and belong to Phase 12 instead. }

{$mode objfpc}{$H+}

interface

uses
  Math;

type
  TScanDirection = (sdHorizontal, sdVertical, sdDiagonal, sdZigZag);

  TPixelCoord = record
    X, Y: Integer;
  end;

  TPixelPath = array of TPixelCoord;

// Returns every (X,Y) in [0..AWidth-1]x[0..AHeight-1] exactly once, in
// the traversal order ADirection implies:
//  - sdHorizontal: row by row (Y outer), always left-to-right
//  - sdVertical: column by column (X outer), always top-to-bottom
//  - sdZigZag: like sdHorizontal, but alternates left-to-right/
//    right-to-left every row (the standard raster-efficiency pattern -
//    no wasted rapid back to the left margin on every single row)
//  - sdDiagonal: sweeps anti-diagonals (constant X+Y, from 0 to
//    AWidth+AHeight-2), each diagonal walked in increasing X order
function BuildScanPath(AWidth, AHeight: Integer; ADirection: TScanDirection): TPixelPath;

implementation

function BuildScanPath(AWidth, AHeight: Integer; ADirection: TScanDirection): TPixelPath;
var
  x, y, i, d, xStart, xEnd, xStep: Integer;
begin
  SetLength(Result, AWidth * AHeight);
  i := 0;
  case ADirection of
    sdHorizontal:
      for y := 0 to AHeight - 1 do
        for x := 0 to AWidth - 1 do
        begin
          Result[i].X := x; Result[i].Y := y;
          Inc(i);
        end;

    sdVertical:
      for x := 0 to AWidth - 1 do
        for y := 0 to AHeight - 1 do
        begin
          Result[i].X := x; Result[i].Y := y;
          Inc(i);
        end;

    sdZigZag:
      for y := 0 to AHeight - 1 do
      begin
        if (y mod 2) = 0 then
        begin
          xStart := 0; xEnd := AWidth - 1; xStep := 1;
        end
        else
        begin
          xStart := AWidth - 1; xEnd := 0; xStep := -1;
        end;
        x := xStart;
        while True do
        begin
          Result[i].X := x; Result[i].Y := y;
          Inc(i);
          if x = xEnd then Break;
          Inc(x, xStep);
        end;
      end;

    sdDiagonal:
      for d := 0 to AWidth + AHeight - 2 do
        for x := Max(0, d - AHeight + 1) to Min(d, AWidth - 1) do
        begin
          Result[i].X := x; Result[i].Y := d - x;
          Inc(i);
        end;
  end;
end;

end.
