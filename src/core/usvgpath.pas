unit usvgpath;

{ usvgpath: parses an SVG path `d` attribute string into flattened
  polylines (plan Phase 12). Pure/LCL-free (no BGRA dependency at all,
  unlike usvgimport.pas which needs BGRA's SVG DOM to even find `d`
  strings in the first place) - handles the actual path-data GRAMMAR,
  which is plain text parsing, testable standalone.

  Supports M/m, L/l, H/h, V/v, C/c, Q/q, Z/z (absolute and relative) -
  covers hand-authored SVGs and autotrace's own real output (confirmed
  via its documented output style: straight lines and cubic Beziers,
  no arcs). Deliberately does NOT support A/a (elliptical arc) or the
  S/s,T/t smooth-continuation shorthands - real but less common path
  commands, disclosed as not handled rather than silently mishandled
  (an unsupported command stops parsing at that point and returns what
  was parsed so far, not a crash or garbage output).

  Beziers are flattened into line segments at a fixed subdivision count
  - not adaptive/error-bound (a real simplification for a first version,
  disclosed) - good enough for laser-engraving resolution at typical
  scales, not curvature-adaptive. }

{$mode objfpc}{$H+}

interface

type
  TFloatPoint = record
    X, Y: Double;
  end;

  TPolyline = array of TFloatPoint;
  TPolylineArray = array of TPolyline;

const
  BEZIER_SUBDIVISIONS = 16; // line segments per Bezier curve

// Parses ASvgPathData (the raw `d="..."` attribute content) into one or
// more polylines - a new polyline starts at each 'M'/'m' (moveto) command,
// 'Z'/'z' closes the current polyline back to its own start point.
function ParseSvgPath(const ASvgPathData: string): TPolylineArray;

implementation

uses
  SysUtils;

var
  InvFS: TFormatSettings;

type
  TPathTokenizer = record
    S: string;
    Pos: Integer;
  end;

procedure SkipSeparators(var ATok: TPathTokenizer);
begin
  while (ATok.Pos <= Length(ATok.S)) and (ATok.S[ATok.Pos] in [' ', #9, #10, #13, ',']) do
    Inc(ATok.Pos);
end;

function TryReadCommand(var ATok: TPathTokenizer; out ACmd: Char): Boolean;
begin
  SkipSeparators(ATok);
  Result := (ATok.Pos <= Length(ATok.S)) and (ATok.S[ATok.Pos] in
    ['M','m','L','l','H','h','V','v','C','c','Q','q','Z','z']);
  if Result then
  begin
    ACmd := ATok.S[ATok.Pos];
    Inc(ATok.Pos);
  end;
end;

function TryReadNumber(var ATok: TPathTokenizer; out AValue: Double): Boolean;
var
  start: Integer;
  s: string;
begin
  SkipSeparators(ATok);
  start := ATok.Pos;
  if (ATok.Pos <= Length(ATok.S)) and (ATok.S[ATok.Pos] in ['+','-']) then Inc(ATok.Pos);
  while (ATok.Pos <= Length(ATok.S)) and (ATok.S[ATok.Pos] in ['0'..'9']) do Inc(ATok.Pos);
  if (ATok.Pos <= Length(ATok.S)) and (ATok.S[ATok.Pos] = '.') then
  begin
    Inc(ATok.Pos);
    while (ATok.Pos <= Length(ATok.S)) and (ATok.S[ATok.Pos] in ['0'..'9']) do Inc(ATok.Pos);
  end;
  if (ATok.Pos <= Length(ATok.S)) and (ATok.S[ATok.Pos] in ['e','E']) then
  begin
    Inc(ATok.Pos);
    if (ATok.Pos <= Length(ATok.S)) and (ATok.S[ATok.Pos] in ['+','-']) then Inc(ATok.Pos);
    while (ATok.Pos <= Length(ATok.S)) and (ATok.S[ATok.Pos] in ['0'..'9']) do Inc(ATok.Pos);
  end;
  s := Copy(ATok.S, start, ATok.Pos - start);
  Result := (s <> '') and (s <> '-') and (s <> '+') and
    TryStrToFloat(s, AValue, InvFS);
  if not Result then ATok.Pos := start;
end;

procedure AddPoint(var APoly: TPolyline; AX, AY: Double);
begin
  SetLength(APoly, Length(APoly) + 1);
  APoly[High(APoly)].X := AX;
  APoly[High(APoly)].Y := AY;
end;

procedure AddCubicBezier(var APoly: TPolyline; x0, y0, x1, y1, x2, y2, x3, y3: Double);
var
  i: Integer;
  t, mt: Double;
  x, y: Double;
begin
  for i := 1 to BEZIER_SUBDIVISIONS do
  begin
    t := i / BEZIER_SUBDIVISIONS;
    mt := 1 - t;
    x := mt*mt*mt*x0 + 3*mt*mt*t*x1 + 3*mt*t*t*x2 + t*t*t*x3;
    y := mt*mt*mt*y0 + 3*mt*mt*t*y1 + 3*mt*t*t*y2 + t*t*t*y3;
    AddPoint(APoly, x, y);
  end;
end;

procedure AddQuadBezier(var APoly: TPolyline; x0, y0, x1, y1, x2, y2: Double);
var
  i: Integer;
  t, mt: Double;
  x, y: Double;
begin
  for i := 1 to BEZIER_SUBDIVISIONS do
  begin
    t := i / BEZIER_SUBDIVISIONS;
    mt := 1 - t;
    x := mt*mt*x0 + 2*mt*t*x1 + t*t*x2;
    y := mt*mt*y0 + 2*mt*t*y1 + t*t*y2;
    AddPoint(APoly, x, y);
  end;
end;

function ParseSvgPath(const ASvgPathData: string): TPolylineArray;
var
  tok: TPathTokenizer;
  cmd: Char;
  cur: TPolyline;
  curCount: Integer;
  x, y, startX, startY: Double;
  nx, ny, x1, y1, x2, y2: Double;
  relative: Boolean;

  procedure FlushCurrent;
  begin
    if curCount > 0 then
    begin
      SetLength(Result, Length(Result) + 1);
      SetLength(cur, curCount);
      Result[High(Result)] := cur;
    end;
    SetLength(cur, 0);
    curCount := 0;
  end;

  procedure AddCur(px, py: Double);
  begin
    if curCount >= Length(cur) then SetLength(cur, Length(cur) * 2 + 8);
    cur[curCount].X := px;
    cur[curCount].Y := py;
    Inc(curCount);
  end;

begin
  SetLength(Result, 0);
  tok.S := ASvgPathData;
  tok.Pos := 1;
  x := 0; y := 0; startX := 0; startY := 0;
  curCount := 0;

  while TryReadCommand(tok, cmd) do
  begin
    relative := cmd in ['m','l','h','v','c','q','z'];
    case UpCase(cmd) of
      'M':
        begin
          FlushCurrent;
          if not TryReadNumber(tok, nx) then Break;
          if not TryReadNumber(tok, ny) then Break;
          if relative then begin nx := x + nx; ny := y + ny; end;
          x := nx; y := ny; startX := x; startY := y;
          AddCur(x, y);
          // extra coordinate pairs after M are implicit L commands (SVG spec)
          while TryReadNumber(tok, nx) do
          begin
            if not TryReadNumber(tok, ny) then Break;
            if relative then begin nx := x + nx; ny := y + ny; end;
            x := nx; y := ny;
            AddCur(x, y);
          end;
        end;
      'L':
        begin
          while TryReadNumber(tok, nx) do
          begin
            if not TryReadNumber(tok, ny) then Break;
            if relative then begin nx := x + nx; ny := y + ny; end;
            x := nx; y := ny;
            AddCur(x, y);
          end;
        end;
      'H':
        while TryReadNumber(tok, nx) do
        begin
          if relative then nx := x + nx;
          x := nx;
          AddCur(x, y);
        end;
      'V':
        while TryReadNumber(tok, ny) do
        begin
          if relative then ny := y + ny;
          y := ny;
          AddCur(x, y);
        end;
      'C':
        begin
          while TryReadNumber(tok, x1) do
          begin
            if not TryReadNumber(tok, y1) then Break;
            if not TryReadNumber(tok, x2) then Break;
            if not TryReadNumber(tok, y2) then Break;
            if not TryReadNumber(tok, nx) then Break;
            if not TryReadNumber(tok, ny) then Break;
            if relative then
            begin
              x1 := x + x1; y1 := y + y1;
              x2 := x + x2; y2 := y + y2;
              nx := x + nx; ny := y + ny;
            end;
            // AddCubicBezier grows `cur` via exact-length SetLength calls
            // (AddPoint), which conflicts with AddCur's own doubling
            // growth strategy unless `cur`'s allocated length is first
            // truncated down to the real curCount - otherwise AddPoint
            // would append after leftover over-allocated slack instead of
            // at the real end, corrupting the polyline.
            SetLength(cur, curCount);
            AddCubicBezier(cur, x, y, x1, y1, x2, y2, nx, ny);
            curCount := Length(cur);
            x := nx; y := ny;
          end;
        end;
      'Q':
        begin
          while TryReadNumber(tok, x1) do
          begin
            if not TryReadNumber(tok, y1) then Break;
            if not TryReadNumber(tok, nx) then Break;
            if not TryReadNumber(tok, ny) then Break;
            if relative then
            begin
              x1 := x + x1; y1 := y + y1;
              nx := x + nx; ny := y + ny;
            end;
            SetLength(cur, curCount); // see the AddCubicBezier call's own comment above
            AddQuadBezier(cur, x, y, x1, y1, nx, ny);
            curCount := Length(cur);
            x := nx; y := ny;
          end;
        end;
      'Z':
        begin
          AddCur(startX, startY);
          x := startX; y := startY;
          FlushCurrent;
        end;
    else
      Break; // unsupported command (A/a, S/s, T/t) - stop, keep what's parsed
    end;
  end;

  FlushCurrent;
end;

initialization
  InvFS := DefaultFormatSettings;
  InvFS.DecimalSeparator := '.';
  InvFS.ThousandSeparator := #0;

end.
