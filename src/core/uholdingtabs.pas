unit uholdingtabs;

{ uholdingtabs: pure geometry (plan Phase 36) - splits a closed cutout
  polygon's perimeter into alternating "cut" and "tab" sub-segments, so a
  CNC cutout job can retract to a shallow tab-clearance Z at each tab
  instead of cutting all the way through - the real, standard CNC
  technique ("holding tabs"/"tabs and bridges") every real CAM tool
  (FlatCAM, Vectric, Fusion360) implements, so a freed cutout piece
  doesn't come loose (and fly off / bind the bit) before the job
  finishes; the last few tabs are cut through by hand afterward.

  Algorithm: walk the path's own cumulative arc length, place ATabCount
  tabs evenly around the total perimeter, each spanning ATabWidth of arc
  length centered on its own position; insert an exact interpolated
  point at every tab boundary crossing (not just splitting at the
  nearest existing vertex) so tab width is geometrically accurate
  regardless of how coarsely the input polygon happens to be
  tessellated. Pure/LCL-free, standalone-testable like every other core
  unit in this app. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Math;

type
  TTabPoint = record
    X, Y: Double;
  end;
  TTabPath = array of TTabPoint;

  TTabSegment = record
    Points: TTabPath;
    IsTab: Boolean;
  end;
  TTabSegmentArray = array of TTabSegment;

{ SplitPathWithTabs: APath is a closed polygon (its own last point may or
  may not repeat the first - both are handled). ATabCount must be >= 1;
  ATabWidth is the arc-length (mm) each tab spans, centered on its own
  evenly-spaced position around the perimeter. Returns the alternating
  cut/tab sub-segments in path order, starting from APath's own first
  point. If ATabWidth*ATabCount >= the path's own total perimeter (tabs
  would overlap or cover the whole path), returns the whole path as one
  single tab segment - a real degenerate case, not a crash. }
function SplitPathWithTabs(const APath: TTabPath; ATabCount: Integer;
  ATabWidth: Double): TTabSegmentArray;

function PathPerimeter(const APath: TTabPath): Double;

implementation

function PathPerimeter(const APath: TTabPath): Double;
var
  i, n: Integer;
begin
  Result := 0;
  n := Length(APath);
  if n < 2 then Exit;
  for i := 0 to n - 2 do
    Result := Result + Hypot(APath[i + 1].X - APath[i].X, APath[i + 1].Y - APath[i].Y);
  // Close the loop back to the first point, unless the caller already
  // repeated it as the last point (common convention, both handled).
  if (Abs(APath[n - 1].X - APath[0].X) > 1e-9) or (Abs(APath[n - 1].Y - APath[0].Y) > 1e-9) then
    Result := Result + Hypot(APath[0].X - APath[n - 1].X, APath[0].Y - APath[n - 1].Y);
end;

function InterpolateAt(const A, B: TTabPoint; AFrac: Double): TTabPoint;
begin
  Result.X := A.X + (B.X - A.X) * AFrac;
  Result.Y := A.Y + (B.Y - A.Y) * AFrac;
end;

// WrapArcLength: wraps a possibly-negative/possibly-overshot arc-length
// position into [0, APerimeter) - a plain manual wrap rather than FMod
// (not reliably available across FPC RTL versions), safe here since the
// caller only ever passes values within one APerimeter of the valid range.
function WrapArcLength(AValue, APerimeter: Double): Double;
begin
  Result := AValue;
  while Result < 0 do Result := Result + APerimeter;
  while Result >= APerimeter do Result := Result - APerimeter;
end;

function SplitPathWithTabs(const APath: TTabPath; ATabCount: Integer;
  ATabWidth: Double): TTabSegmentArray;
var
  closedPath: TTabPath;
  n, i, t: Integer;
  perimeter: Double;
  tabCenters: array of Double;
  tabStarts, tabEnds: array of Double;
  boundaries: array of Double; // every tab start/end, sorted, arc-length positions
  boundaryIsTabStart: array of Boolean;
  segStart: Double;
  segIsTab: Boolean;
  cur: Double;
  seg: TTabSegment;
  segPoints: TTabPath;
  bi: Integer;

  procedure AppendPoint(var APts: TTabPath; const APt: TTabPoint);
  begin
    SetLength(APts, Length(APts) + 1);
    APts[High(APts)] := APt;
  end;

  procedure FlushSegment(const AEndPt: TTabPoint);
  begin
    AppendPoint(segPoints, AEndPt);
    if Length(segPoints) >= 2 then
    begin
      seg.Points := segPoints;
      seg.IsTab := segIsTab;
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := seg;
    end;
    SetLength(segPoints, 0);
    AppendPoint(segPoints, AEndPt);
  end;

var
  segLen, ptFrac: Double;
  a, b: TTabPoint;
  nextBoundary: Double;
begin
  SetLength(Result, 0);
  n := Length(APath);
  if n < 2 then Exit;
  if ATabCount < 1 then ATabCount := 1;

  // Normalize to an explicitly-closed path (last point == first point) so
  // the walking loop below never needs a special wrap-around case.
  closedPath := Copy(APath, 0, n);
  if (Abs(closedPath[n - 1].X - closedPath[0].X) > 1e-9) or
     (Abs(closedPath[n - 1].Y - closedPath[0].Y) > 1e-9) then
  begin
    SetLength(closedPath, n + 1);
    closedPath[n] := closedPath[0];
    n := n + 1;
  end;

  perimeter := PathPerimeter(APath);
  if perimeter <= 1e-9 then Exit;

  if ATabWidth * ATabCount >= perimeter then
  begin
    // Degenerate: tabs would cover the whole path - the whole thing is one tab.
    SetLength(Result, 1);
    Result[0].Points := closedPath;
    Result[0].IsTab := True;
    Exit;
  end;

  SetLength(tabCenters, ATabCount);
  SetLength(tabStarts, ATabCount);
  SetLength(tabEnds, ATabCount);
  for t := 0 to ATabCount - 1 do
  begin
    tabCenters[t] := perimeter * t / ATabCount;
    tabStarts[t] := tabCenters[t] - ATabWidth / 2;
    tabEnds[t] := tabCenters[t] + ATabWidth / 2;
  end;

  // Flatten to a sorted boundary list (arc-length positions, wrapped into
  // [0, perimeter)), each tagged whether it starts or ends a tab.
  SetLength(boundaries, ATabCount * 2);
  SetLength(boundaryIsTabStart, ATabCount * 2);
  for t := 0 to ATabCount - 1 do
  begin
    boundaries[t * 2] := WrapArcLength(tabStarts[t], perimeter);
    boundaryIsTabStart[t * 2] := True;
    boundaries[t * 2 + 1] := WrapArcLength(tabEnds[t], perimeter);
    boundaryIsTabStart[t * 2 + 1] := False;
  end;
  // Simple insertion sort - ATabCount is always small (a handful of tabs).
  for i := 1 to High(boundaries) do
  begin
    segLen := boundaries[i];
    segIsTab := boundaryIsTabStart[i];
    bi := i - 1;
    while (bi >= 0) and (boundaries[bi] > segLen) do
    begin
      boundaries[bi + 1] := boundaries[bi];
      boundaryIsTabStart[bi + 1] := boundaryIsTabStart[bi];
      Dec(bi);
    end;
    boundaries[bi + 1] := segLen;
    boundaryIsTabStart[bi + 1] := segIsTab;
  end;

  // Is arc-length 0 (the path's own start point) inside a tab? If so the
  // very first segment we walk is itself a tab.
  segIsTab := False;
  for t := 0 to ATabCount - 1 do
    if (tabStarts[t] < 0) and (tabEnds[t] > 0) then
      segIsTab := True;

  SetLength(segPoints, 0);
  AppendPoint(segPoints, closedPath[0]);
  cur := 0;
  bi := 0;

  for i := 0 to n - 2 do
  begin
    a := closedPath[i];
    b := closedPath[i + 1];
    segLen := Hypot(b.X - a.X, b.Y - a.Y);
    if segLen < 1e-12 then Continue;

    while (bi < Length(boundaries)) and (boundaries[bi] <= cur + segLen + 1e-9) do
    begin
      nextBoundary := boundaries[bi];
      if nextBoundary > cur + 1e-9 then
      begin
        ptFrac := (nextBoundary - cur) / segLen;
        FlushSegment(InterpolateAt(a, b, ptFrac));
        segIsTab := boundaryIsTabStart[bi];
      end;
      Inc(bi);
    end;

    // Preserve this edge's own real endpoint - a real bug found via
    // standalone testing: without this, any segment spanning MULTIPLE
    // polygon edges (e.g. a tab centered on/near a corner) silently
    // lost every intermediate polygon vertex, replacing the actual
    // corner-following path with a straight chord cutting across it -
    // wrong both for the reported tab arc-length (shorter than
    // requested), the actual toolpath the tool would extract from
    // TAB segments (which should hug the polygon exactly, matching
    // the FULL cut segments' own path), and CUT segments too, which
    // would equally have chorded across any corner they spanned.
    AppendPoint(segPoints, b);

    cur := cur + segLen;
  end;

  FlushSegment(closedPath[n - 1]);
end;

end.
