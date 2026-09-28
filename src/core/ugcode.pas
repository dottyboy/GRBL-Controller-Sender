unit ugcode;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math;

type
  { TSegment: one drawable move, in mm, already in the machine's XY(Z)
    coordinate frame. Rapid=True for G0 (typically drawn dashed/dim),
    False for feed moves G1/G2/G3. Arcs (G2/G3) are pre-expanded into a
    short run of these, mirroring bCNC's CNC.py motionPath(). }
  TSegment = record
    X1, Y1, Z1: Double;
    X2, Y2, Z2: Double;
    Rapid: Boolean;
  end;

  TSegmentArray = array of TSegment;

  TXY = record
    X, Y: Double;
  end;

  { TGCodeParser mirrors the path-generation subset of bCNC's CNC.py
    (parseLine/motionStart/motionCenter/motionPath/motionEnd): a minimal,
    pure-logic g-code walker whose only job is to turn a text program into
    a flat list of line segments for visualization. It is NOT the full
    interpreter (no canned cycles, no XZ/YZ arc planes, no work-offset
    handling) - see the class comment in usender.pas's plan notes for what
    a fuller port would still need. Shared by both the 2D and 3D preview
    so they never disagree about the toolpath. }
  TGCodeParser = class
  private
    FX, FY, FZ: Double;           // current (start-of-move) position
    FXVal, FYVal, FZVal: Double;  // target position for the move in progress
    FHasX, FHasY, FHasZ: Boolean;
    FIVal, FJVal, FKVal: Double;
    FHasIJK: Boolean;
    FRVal: Double;
    FHasR: Boolean;
    FAbsolute: Boolean;
    FUnitScale: Double;           // 1.0 = mm, 25.4 = inch -> mm
    FGCode: Integer;              // modal motion mode: 0,1,2,3, or -1 = none
    FSegments: TSegmentArray;
    FCount: Integer;
    FMinX, FMinY, FMinZ, FMaxX, FMaxY, FMaxZ: Double;
    procedure AddSegment(x1, y1, z1, x2, y2, z2: Double; Rapid: Boolean);
    procedure UpdateBounds(x, y, z: Double);
    procedure ProcessLine(const ALine: string);
    procedure MotionPath;
    function MotionCenter: TXY;
  public
    constructor Create;
    procedure Reset;
    procedure ParseLines(ALines: TStrings);
    property Segments: TSegmentArray read FSegments;
    property Count: Integer read FCount;
    property MinX: Double read FMinX;
    property MinY: Double read FMinY;
    property MinZ: Double read FMinZ;
    property MaxX: Double read FMaxX;
    property MaxY: Double read FMaxY;
    property MaxZ: Double read FMaxZ;
  end;

// Tokenize one g-code line: strip () and ; comments, split into words
// like ['G1','X10','Y20','F500'] - mirrors CNC.py's static parseLine().
function TokenizeGCodeLine(const ALine: string): TStringArray;

implementation

function TokenizeGCodeLine(const ALine: string): TStringArray;
var
  s: string;
  i, depth: Integer;
  cleaned: string;
  tokens: TStringList;
  cur: string;
  c: Char;
begin
  s := ALine;

  // Strip ( ... ) comments, possibly unbalanced-safe (depth-counted).
  cleaned := '';
  depth := 0;
  for i := 1 to Length(s) do
  begin
    c := s[i];
    if c = '(' then Inc(depth)
    else if c = ')' then
    begin
      if depth > 0 then Dec(depth);
    end
    else if depth = 0 then
    begin
      if c = ';' then Break; // rest of line is a comment
      cleaned := cleaned + c;
    end;
  end;

  // Remove spaces, then split before each letter to get discrete words.
  tokens := TStringList.Create;
  try
    cur := '';
    for i := 1 to Length(cleaned) do
    begin
      c := cleaned[i];
      if c = ' ' then Continue;
      if (c in ['A'..'Z', 'a'..'z']) and (cur <> '') then
      begin
        tokens.Add(cur);
        cur := '';
      end;
      cur := cur + UpCase(c);
    end;
    if cur <> '' then tokens.Add(cur);
    Result := tokens.ToStringArray;
  finally
    tokens.Free;
  end;
end;

{ TGCodeParser }

constructor TGCodeParser.Create;
begin
  inherited Create;
  Reset;
end;

procedure TGCodeParser.Reset;
begin
  FX := 0; FY := 0; FZ := 0;
  FAbsolute := True;
  FUnitScale := 1.0;
  FGCode := -1;
  FCount := 0;
  SetLength(FSegments, 0);
  FMinX := 1.0e30; FMinY := 1.0e30; FMinZ := 1.0e30;
  FMaxX := -1.0e30; FMaxY := -1.0e30; FMaxZ := -1.0e30;
end;

procedure TGCodeParser.UpdateBounds(x, y, z: Double);
begin
  if x < FMinX then FMinX := x;
  if y < FMinY then FMinY := y;
  if z < FMinZ then FMinZ := z;
  if x > FMaxX then FMaxX := x;
  if y > FMaxY then FMaxY := y;
  if z > FMaxZ then FMaxZ := z;
end;

procedure TGCodeParser.AddSegment(x1, y1, z1, x2, y2, z2: Double; Rapid: Boolean);
begin
  if FCount >= Length(FSegments) then
    SetLength(FSegments, Length(FSegments) * 2 + 64);
  FSegments[FCount].X1 := x1; FSegments[FCount].Y1 := y1; FSegments[FCount].Z1 := z1;
  FSegments[FCount].X2 := x2; FSegments[FCount].Y2 := y2; FSegments[FCount].Z2 := z2;
  FSegments[FCount].Rapid := Rapid;
  Inc(FCount);
  UpdateBounds(x1, y1, z1);
  UpdateBounds(x2, y2, z2);
end;

// Center of a G2/G3 arc from either R (radius) or I/J (offset), XY plane
// only - mirrors CNC.py motionCenter() for the plane==XY case.
function TGCodeParser.MotionCenter: TXY;
var
  ABx, ABy, Cx, Cy, AB, OC: Double;
begin
  if FHasR then
  begin
    ABx := FXVal - FX;
    ABy := FYVal - FY;
    Cx := 0.5 * (FX + FXVal);
    Cy := 0.5 * (FY + FYVal);
    AB := Sqrt(ABx * ABx + ABy * ABy);
    if Sqr(FRVal) - (AB * AB / 4.0) > 0 then
      OC := Sqrt(Sqr(FRVal) - (AB * AB / 4.0))
    else
      OC := 0.0;
    if FGCode = 2 then OC := -OC; // CW
    if AB <> 0.0 then
    begin
      Result.X := Cx - OC * ABy / AB;
      Result.Y := Cy + OC * ABx / AB;
    end
    else
    begin
      Result.X := FX;
      Result.Y := FY;
    end;
  end
  else
  begin
    Result.X := FX + FIVal;
    Result.Y := FY + FJVal;
    FRVal := Sqrt(FIVal * FIVal + FJVal * FJVal);
  end;
end;

// Generates the segment(s) for the motion currently pending (FGCode +
// FXVal/FYVal/FZVal target), mirrors CNC.py motionPath() for G0/G1/G2/G3.
// Arc planes other than XY (G18/G19) are not supported - deferred, see
// class comment.
procedure TGCodeParser.MotionPath;
var
  center: TXY;
  phi0, phi1, df, sagitta, phi, ws, w0, w1: Double;
  u, v, w: Double;
  px, py, pz: Double;
  rapid: Boolean;
const
  ACCURACY = 0.01; // mm sagitta error, matches CNC.py CNC.accuracy default
begin
  if (FGCode = 0) or (FGCode = 1) then
  begin
    if (FXVal <> FX) or (FYVal <> FY) or (FZVal <> FZ) then
      AddSegment(FX, FY, FZ, FXVal, FYVal, FZVal, FGCode = 0);
  end
  else if (FGCode = 2) or (FGCode = 3) then
  begin
    center := MotionCenter;
    phi0 := ArcTan2(FY - center.Y, FX - center.X);
    phi1 := ArcTan2(FYVal - center.Y, FXVal - center.X);
    w0 := FZ;
    w1 := FZVal;

    if FRVal > 0 then
      sagitta := 1.0 - ACCURACY / FRVal
    else
      sagitta := 0.0;
    if sagitta > 0.0 then
      df := Min(2.0 * ArcCos(sagitta), Pi / 4.0)
    else
      df := Pi / 4.0;

    rapid := False;
    px := FX; py := FY; pz := FZ;

    if FGCode = 2 then // CW
    begin
      if phi1 >= phi0 - 1e-10 then phi1 := phi1 - 2.0 * Pi;
      if (phi1 - phi0) <> 0 then ws := (w1 - w0) / (phi1 - phi0) else ws := 0;
      phi := phi0 - df;
      while phi > phi1 do
      begin
        u := center.X + FRVal * Cos(phi);
        v := center.Y + FRVal * Sin(phi);
        w := w0 + (phi - phi0) * ws;
        AddSegment(px, py, pz, u, v, w, rapid);
        px := u; py := v; pz := w;
        phi := phi - df;
      end;
    end
    else // CCW
    begin
      if phi1 <= phi0 + 1e-10 then phi1 := phi1 + 2.0 * Pi;
      if (phi1 - phi0) <> 0 then ws := (w1 - w0) / (phi1 - phi0) else ws := 0;
      phi := phi0 + df;
      while phi < phi1 do
      begin
        u := center.X + FRVal * Cos(phi);
        v := center.Y + FRVal * Sin(phi);
        w := w0 + (phi - phi0) * ws;
        AddSegment(px, py, pz, u, v, w, rapid);
        px := u; py := v; pz := w;
        phi := phi + df;
      end;
    end;

    AddSegment(px, py, pz, FXVal, FYVal, FZVal, rapid);
  end;
end;

procedure TGCodeParser.ProcessLine(const ALine: string);
var
  tokens: TStringArray;
  i: Integer;
  tok: string;
  c: Char;
  value: Double;
  gcode, decimal: Integer;
begin
  tokens := TokenizeGCodeLine(ALine);
  if Length(tokens) = 0 then Exit;

  FXVal := FX; FYVal := FY; FZVal := FZ;
  FHasX := False; FHasY := False; FHasZ := False;
  FHasIJK := False; FHasR := False;
  FIVal := 0; FJVal := 0; FKVal := 0; FRVal := 0;

  for i := 0 to High(tokens) do
  begin
    tok := tokens[i];
    if tok = '' then Continue;
    c := tok[1];
    value := StrToFloatDef(Copy(tok, 2, Length(tok) - 1), 0);

    case c of
      'X': begin FXVal := value * FUnitScale; if not FAbsolute then FXVal := FXVal + FX; FHasX := True; end;
      'Y': begin FYVal := value * FUnitScale; if not FAbsolute then FYVal := FYVal + FY; FHasY := True; end;
      'Z': begin FZVal := value * FUnitScale; if not FAbsolute then FZVal := FZVal + FZ; FHasZ := True; end;
      'I': begin FIVal := value * FUnitScale; FHasIJK := True; end;
      'J': begin FJVal := value * FUnitScale; FHasIJK := True; end;
      'K': begin FKVal := value * FUnitScale; FHasIJK := True; end;
      'R': begin FRVal := value * FUnitScale; FHasR := True; end;
      'G':
        begin
          gcode := Trunc(value);
          decimal := Round((value - gcode) * 10);
          case gcode of
            20: FUnitScale := 25.4; // inches -> mm
            21: FUnitScale := 1.0;  // mm
            90: if decimal = 0 then FAbsolute := True;
            91: if decimal = 0 then FAbsolute := False;
            0, 1, 2, 3: FGCode := gcode;
            80: FGCode := -1;
          end;
        end;
    end;
  end;

  if (FGCode >= 0) and (FHasX or FHasY or FHasZ or FHasIJK or FHasR) then
  begin
    MotionPath;
    FX := FXVal; FY := FYVal; FZ := FZVal;
  end;
end;

procedure TGCodeParser.ParseLines(ALines: TStrings);
var
  i: Integer;
begin
  Reset;
  for i := 0 to ALines.Count - 1 do
    ProcessLine(ALines[i]);
end;

end.
