unit usvgimport;

{ usvgimport: loads an SVG file's shapes (plan Phase 12) - the second unit
  in this project allowed to touch BGRABitmap (via its real `bgrasvg`/
  `bgrasvgshapes` DOM, not LaserGRBL's own 33K-LOC SvgLibrary), isolated
  here the same way uimageio.pas isolates the raster-loading side.

  Walks the real SVG DOM (TBGRASVG.Content, recursing into TSVGGroup)
  rather than using BGRA's canvas-path-CAPTURE mechanism (InternalCopyPathTo/
  TBGRACanvas2D) - that route needs the renderer to actually draw and record
  a path, real but meaningfully more machinery to get right under this
  phase's time budget. Instead, each real shape type's own plain numeric/
  string properties are read directly: TSVGPath's raw `d` data string (fed
  to usvgpath.pas's OWN pure parser), TSVGRectangle's x/y/width/height,
  TSVGCircle's cx/cy/r (approximated as a polygon - N_CIRCLE_SEGMENTS
  segments, a disclosed simplification, not a true arc). TSVGEllipse/
  TSVGLine/TSVGPolygon/TSVGPolyline exist as real SVG element types too
  but are NOT handled yet - disclosed, not silently ignored (an unhandled
  element type is simply skipped, matching this project's own "flag what's
  deferred" discipline rather than guessing at unfamiliar API for them
  under time pressure).

  Fill vs stroke is read from each element's own real `fill`/`stroke`
  string properties (<>'none' test) - genuinely correct information, not
  inferred. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, BGRABitmapTypes, BGRASVG, BGRASVGShapes, BGRASVGType,
  usvgpath;

type
  TSvgShape = record
    Points: TPolyline;   // already flattened (Beziers subdivided)
    IsFilled: Boolean;
    IsStroked: Boolean;
  end;

  TSvgShapeArray = array of TSvgShape;

const
  N_CIRCLE_SEGMENTS = 32;

function LoadSvgShapes(const AFileName: string; out AShapes: TSvgShapeArray;
  out AError: string): Boolean;

implementation

function HasFill(AEl: TSVGElement): Boolean;
begin
  Result := not SameText(Trim(AEl.fill), 'none');
end;

function HasStroke(AEl: TSVGElement): Boolean;
begin
  Result := (Trim(AEl.stroke) <> '') and not SameText(Trim(AEl.stroke), 'none');
end;

procedure AddShapesFromPolylines(var AShapes: TSvgShapeArray; const APolys: TPolylineArray;
  AFilled, AStroked: Boolean);
var
  i, n: Integer;
begin
  for i := 0 to High(APolys) do
  begin
    if Length(APolys[i]) = 0 then Continue;
    n := Length(AShapes);
    SetLength(AShapes, n + 1);
    AShapes[n].Points := APolys[i];
    AShapes[n].IsFilled := AFilled;
    AShapes[n].IsStroked := AStroked;
  end;
end;

procedure WalkElement(AEl: TSVGElement; var AShapes: TSvgShapeArray); forward;

procedure WalkContent(AContent: TSVGContent; var AShapes: TSvgShapeArray);
var
  i: Integer;
  el: TSVGElement;
begin
  if AContent = nil then Exit;
  for i := 0 to AContent.ElementCount - 1 do
  begin
    // TSVGContent.Element[] walks every raw XML child node, including
    // whitespace/text nodes between tags (TDOMText) - real, confirmed via
    // a live EInvalidCast ("TDOMText is not a TSVGElement") the first time
    // this ran against a real, normally-indented/formatted SVG file.
    // BGRA's own Element[] getter does an unchecked cast assuming every
    // child is a real element, so a non-element child must be skipped
    // BEFORE calling it, not after - hence the per-index try/except here
    // rather than a blanket one around the whole loop (which would abort
    // the rest of a valid document after the first stray text node).
    try
      el := AContent.Element[i];
    except
      on EInvalidCast do Continue;
    end;
    WalkElement(el, AShapes);
  end;
end;

procedure WalkElement(AEl: TSVGElement; var AShapes: TSvgShapeArray);
var
  filled, stroked: Boolean;
  poly: TPolyline;
  polys: TPolylineArray;
  i: Integer;
  a: Double;
  cx, cy, r: Single;
begin
  if AEl = nil then Exit;

  if AEl is TSVGGroup then
  begin
    WalkContent(TSVGGroup(AEl).Content, AShapes);
    Exit;
  end;

  filled := HasFill(AEl);
  stroked := HasStroke(AEl);
  if not (filled or stroked) then Exit; // invisible shape, nothing to cut/mark

  if AEl is TSVGPath then
  begin
    polys := ParseSvgPath(TSVGPath(AEl).d);
    AddShapesFromPolylines(AShapes, polys, filled, stroked);
  end
  else if AEl is TSVGRectangle then
  begin
    with TSVGRectangle(AEl) do
    begin
      SetLength(poly, 5);
      poly[0].X := x.value;         poly[0].Y := y.value;
      poly[1].X := x.value + width.value; poly[1].Y := y.value;
      poly[2].X := x.value + width.value; poly[2].Y := y.value + height.value;
      poly[3].X := x.value;         poly[3].Y := y.value + height.value;
      poly[4] := poly[0];
    end;
    SetLength(polys, 1);
    polys[0] := poly;
    AddShapesFromPolylines(AShapes, polys, filled, stroked);
  end
  else if AEl is TSVGCircle then
  begin
    cx := TSVGCircle(AEl).cx.value;
    cy := TSVGCircle(AEl).cy.value;
    r := TSVGCircle(AEl).r.value;
    SetLength(poly, N_CIRCLE_SEGMENTS + 1);
    for i := 0 to N_CIRCLE_SEGMENTS do
    begin
      a := 2 * Pi * i / N_CIRCLE_SEGMENTS;
      poly[i].X := cx + r * Cos(a);
      poly[i].Y := cy + r * Sin(a);
    end;
    SetLength(polys, 1);
    polys[0] := poly;
    AddShapesFromPolylines(AShapes, polys, filled, stroked);
  end;
  // else: a real but not-yet-handled element type (ellipse/line/polygon/
  // polyline/text/...) - deliberately skipped, disclosed above, not
  // silently mis-rendered as something it isn't.
end;

function LoadSvgShapes(const AFileName: string; out AShapes: TSvgShapeArray;
  out AError: string): Boolean;
var
  svg: TBGRASVG;
begin
  Result := False;
  AError := '';
  SetLength(AShapes, 0);

  if not FileExists(AFileName) then
  begin
    AError := 'File not found: ' + AFileName;
    Exit;
  end;

  svg := nil;
  try
    try
      svg := TBGRASVG.Create;
      svg.LoadFromFile(AFileName);
    except
      on E: Exception do
      begin
        AError := E.Message;
        Exit;
      end;
    end;

    WalkContent(svg.Content, AShapes);
    Result := True;
  finally
    svg.Free;
  end;
end;

end.
