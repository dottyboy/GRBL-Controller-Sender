unit ulasertestgen;

{ ulasertestgen: laser test-pattern generators (plan Phase 16) - pure
  g-code generator functions, no BGRA/LCL dependency, same shape as
  uspoilboard.pas. Ported directly from LaserGRBL's real GrblFile.cs
  (GenerateCuttingTest / GenerateGreyscaleTest / GenerateShakeTest +
  GenerateShakeTest2), with axis/title labels drawn via uhershey.pas -
  exactly mirroring the reference's own Hershey.CreateString calls for
  those labels.

  Scope note (disclosed): the real GenerateCuttingTest draws its row labels
  ("Npass") as VERTICAL text (horiz=false, the `ver` Hershey table). This
  codebase's uhershey.pas only ported the `hor` table (see its own header
  comment - a disclosed Phase 16 scope reduction), so here those row labels
  are drawn horizontally instead - still legible text, just not rotated
  like the original layout.

  Coordinate convention: X0 Y0 is the pattern's own origin corner (matches
  the reference's own ox=3/oy=3 origin offset); the caller is responsible
  for actually zeroing the machine there before running the generated
  program - same convention as uspoilboard.pas. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, uhershey;

type
  { TCuttingTestConfig: a grid of cut-quality squares - columns vary feed
    rate, rows vary pass count, power is fixed. Mirrors GenerateCuttingTest's
    own parameters 1:1. }
  TCuttingTestConfig = record
    FeedColumns: Integer;    // f_col
    FeedStart, FeedEnd: Integer;  // f_start, f_end
    PassStart, PassEnd: Integer;  // p_start, p_end (row range, inclusive)
    FixedPower: Integer;     // s_fixed
    TextFeed: Integer;       // f_text - rapid feed used while drawing labels
    TextPower: Integer;      // s_text - power used while drawing labels
    Title: string;
    TurnOnCmd: string;       // ton, e.g. 'M4' (dynamic power) or 'M3'
  end;

  { TGreyscaleTestConfig: a continuous power-vs-speed swatch grid - rows
    vary feed rate, columns vary power, filled with a boustrophedon raster
    at the given line resolution, then outlined with a grid and labeled.
    Mirrors GenerateGreyscaleTest's own parameters 1:1. }
  TGreyscaleTestConfig = record
    FeedRows: Integer;       // f_row
    PowerCols: Integer;      // s_col
    FeedStart, FeedEnd: Integer;
    PowerStart, PowerEnd: Integer;
    SizeX, SizeY: Integer;
    Resolution: Double;      // fill lines per mm
    GridFeed: Integer;       // f_grid - feed used while drawing the outline grid
    GridPower: Integer;      // s_grid - power used while drawing the outline grid
    TextFeed, TextPower: Integer;
    Title: string;
    TurnOnCmd: string;
  end;

  TShakeAxis = (saX, saY);

  { TShakeTestConfig: an axis-resonance/backlash check - draws a small
    crosshair, then several bursts of rapid short back-and-forth moves
    along one axis at increasing amplitude, so ringing/skipped-steps show
    up as a blurred or offset crosshair when re-drawn afterward. Mirrors
    GenerateShakeTest's own parameters 1:1. }
  TShakeTestConfig = record
    Axis: TShakeAxis;
    FeedLimit: Integer;      // flimit - feed for the oscillation bursts
    AxisLength: Integer;     // axislen - usable travel on the tested axis
    CrossPower: Integer;     // cpower
    CrossSpeed: Integer;     // cspeed
  end;

function DefaultCuttingTestConfig: TCuttingTestConfig;
function DefaultGreyscaleTestConfig: TGreyscaleTestConfig;
function DefaultShakeTestConfig: TShakeTestConfig;

procedure GenerateCuttingTest(const ACfg: TCuttingTestConfig; ALines: TStrings);
procedure GenerateGreyscaleTest(const ACfg: TGreyscaleTestConfig; ALines: TStrings);
procedure GenerateShakeTest(const ACfg: TShakeTestConfig; ALines: TStrings);

implementation

var
  GInvFS: TFormatSettings; // '.' decimal separator, regardless of locale

function FN(ANumber: Double): string; // mirrors the real formatnumber(double): "0.###" invariant
begin
  Result := FormatFloat('0.###', ANumber, GInvFS);
end;

function DefaultCuttingTestConfig: TCuttingTestConfig;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.FeedColumns := 5;
  Result.FeedStart := 200;
  Result.FeedEnd := 1000;
  Result.PassStart := 1;
  Result.PassEnd := 5;
  Result.FixedPower := 1000;
  Result.TextFeed := 3000;
  Result.TextPower := 1;
  Result.Title := '';
  Result.TurnOnCmd := 'M4';
end;

function DefaultGreyscaleTestConfig: TGreyscaleTestConfig;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.FeedRows := 5;
  Result.PowerCols := 5;
  Result.FeedStart := 200;
  Result.FeedEnd := 3000;
  Result.PowerStart := 0;
  Result.PowerEnd := 1000;
  Result.SizeX := 100;
  Result.SizeY := 100;
  Result.Resolution := 10;
  Result.GridFeed := 3000;
  Result.GridPower := 1;
  Result.TextFeed := 3000;
  Result.TextPower := 1;
  Result.Title := '';
  Result.TurnOnCmd := 'M4';
end;

function DefaultShakeTestConfig: TShakeTestConfig;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Axis := saX;
  Result.FeedLimit := 6000;
  Result.AxisLength := 100;
  Result.CrossPower := 100;
  Result.CrossSpeed := 1000;
end;

// AddHershey: appends one Hershey-rendered label to ALines, substituting
// its own "M3" placeholder for ATurnOnCmd exactly like every other emitted
// laser-on move in this unit (uhershey.pas already does this substitution
// internally - see HersheyText).
procedure AddHershey(ALines: TStrings; const AText: string; ACenterX, ACenterY: Double;
  const ATurnOnCmd: string);
var
  lines: TStringList;
begin
  lines := HersheyText(AText, ACenterX, ACenterY, ATurnOnCmd);
  try
    ALines.AddStrings(lines);
  finally
    lines.Free;
  end;
end;

procedure GenerateCuttingTest(const ACfg: TCuttingTestConfig; ALines: TStrings);
var
  pRow, x, y, f, p, pass: Integer;
  ox, oy, fDelta, cx, cy: Double;
  xSize, ySize: Integer;
  title, parmessage, srange, frange, prange: string;
begin
  pRow := ACfg.PassEnd - ACfg.PassStart + 1;
  ox := 3; oy := 3;
  xSize := ACfg.FeedColumns * 14 - 4;
  ySize := pRow * 14 - 4;

  if ACfg.FeedColumns > 1 then
    fDelta := (ACfg.FeedEnd - ACfg.FeedStart) / (ACfg.FeedColumns - 1)
  else
    fDelta := 0;

  ALines.Add('(--- Laser cutting test ---)');
  ALines.Add(Format('G0 X%s Y%s S%d', [FN(ox), FN(oy), ACfg.FixedPower]));
  ALines.Add(Format('G1 %s F%s', [ACfg.TurnOnCmd, FN(ACfg.FeedStart)]));

  for p := 0 to pRow - 1 do
  begin
    cy := oy + 14 * p;
    for f := 0 to ACfg.FeedColumns - 1 do
    begin
      cx := ox + 14 * f;
      for pass := 0 to (ACfg.PassStart + p) - 1 do
      begin
        ALines.Add(Format('G0 X%s Y%s', [FN(cx), FN(cy)]));
        ALines.Add(Format('G1 X%s F%s %s', [FN(cx + 10), FN(ACfg.FeedStart + fDelta * f), ACfg.TurnOnCmd]));
        ALines.Add(Format('G1 Y%s', [FN(cy + 10)]));
        ALines.Add(Format('G1 X%s', [FN(cx)]));
        ALines.Add(Format('G1 Y%s', [FN(cy)]));
        ALines.Add('M5');
      end;
    end;
  end;

  ALines.Add(Format('G0 X%s Y%s S0', [FN(ox), FN(oy)]));
  ALines.Add(Format('G1 %s F%s', [ACfg.TurnOnCmd, FN(ACfg.TextFeed)]));

  for x := 0 to ACfg.FeedColumns - 1 do
    AddHershey(ALines, Format('F%d', [Round(ACfg.FeedStart + x * fDelta)]),
      (x * 14) + (10 / 2) + ox, oy / 2, 'M4');
  for y := 0 to pRow - 1 do
    AddHershey(ALines, Format('%dpass', [ACfg.PassStart + y]),
      ox / 2, (y * 14) + (10 / 2) + oy, 'M4');

  if ACfg.PassStart <> ACfg.PassEnd then
    prange := Format('%d - %d pass', [ACfg.PassStart, ACfg.PassEnd])
  else
    prange := Format('%d pass', [ACfg.PassEnd]);
  srange := Format('S%d', [ACfg.FixedPower]);
  if ACfg.FeedStart <> ACfg.FeedEnd then
    frange := Format('F%d - F%d', [ACfg.FeedStart, ACfg.FeedEnd])
  else
    frange := Format('F%d', [ACfg.FeedEnd]);

  if ACfg.Title = '' then
    title := 'LaserGRBL cutting test'
  else
    title := Format('LaserGRBL cutting test [%s]', [ACfg.Title]);
  parmessage := Format('%s, %s, %s, %s', [srange, frange, prange, ACfg.TurnOnCmd]);

  AddHershey(ALines, title, xSize / 2 + ox, ySize + oy + oy + oy / 2, 'M4');
  AddHershey(ALines, parmessage, xSize / 2 + ox, ySize + oy + oy / 2, 'M4');

  ALines.Add('M5');
end;

procedure GenerateGreyscaleTest(const ACfg: TGreyscaleTestConfig; ALines: TStrings);
var
  ox, oy, fDelta, sDelta, xStep, yStep, fillingStep: Double;
  forward: Boolean;
  y: Double;
  yi, xi: Integer;
  prevF, curF: Double;
  havePrevF: Boolean;
  cx, cs: Double;
  title, parmessage, srange, frange: string;
begin
  ox := 3; oy := 3;

  if ACfg.FeedRows > 1 then
    fDelta := (ACfg.FeedEnd - ACfg.FeedStart) / (ACfg.FeedRows - 1)
  else
    fDelta := 0;
  if ACfg.PowerCols > 1 then
    sDelta := (ACfg.PowerEnd - ACfg.PowerStart) / (ACfg.PowerCols - 1)
  else
    sDelta := 0;

  xStep := ACfg.SizeX / ACfg.PowerCols;
  yStep := ACfg.SizeY / ACfg.FeedRows;
  fillingStep := 1 / ACfg.Resolution;

  ALines.Add('(--- Laser power/speed test ---)');
  ALines.Add(Format('G0 X%s Y%s S0', [FN(ox), FN(oy)]));
  ALines.Add(Format('G1 %s F%s', [ACfg.TurnOnCmd, FN(ACfg.FeedStart)]));

  // continuous boustrophedon fill: F changes once per row, S changes at
  // every column crossing within the row (real-time power override, no
  // laser-off between swatches - a genuinely continuous grayscale strip).
  // The real C# uses a NaN sentinel for "no previous F yet" - comparing
  // against NaN there is harmless, but FPC's FPU traps an unordered
  // NaN comparison as EInvalidOp, so a plain "have we set one yet" flag
  // is used here instead.
  havePrevF := False; prevF := 0; curF := 0;
  forward := True;
  y := 0;
  while y <= ACfg.SizeY do
  begin
    curF := ACfg.FeedStart + Floor(y / yStep) * fDelta;
    if (not havePrevF) or (curF <> prevF) then
    begin
      ALines.Add(Format('F%s', [FN(curF)]));
      prevF := curF;
      havePrevF := True;
    end;
    ALines.Add(Format('Y%s S0', [FN(oy + y)]));

    for xi := 0 to ACfg.PowerCols - 1 do
    begin
      if forward then
        cx := (xi + 1) * xStep
      else
        cx := ACfg.SizeX - (xi + 1) * xStep;
      if forward then
        cs := ACfg.PowerStart + xi * sDelta
      else
        cs := ACfg.PowerEnd - xi * sDelta;
      ALines.Add(Format('X%s S%s', [FN(ox + cx), FN(cs)]));
    end;

    forward := not forward;
    y := y + fillingStep;
  end;

  // grid X
  ALines.Add(Format('G0 X%s Y%s S0', [FN(ox), FN(oy)]));
  ALines.Add(Format('G1 %s F%s', [ACfg.TurnOnCmd, FN(ACfg.GridFeed)]));
  forward := True;
  for yi := 0 to ACfg.FeedRows do
  begin
    ALines.Add(Format('Y%s S0', [FN(oy + yi * yStep)]));
    for xi := 0 to ACfg.PowerCols do
    begin
      if forward then cx := xi * xStep else cx := ACfg.SizeX - xi * xStep;
      ALines.Add(Format('X%s S%s', [FN(ox + cx), FN(ACfg.GridPower)]));
    end;
    forward := not forward;
  end;

  // grid Y
  ALines.Add(Format('G0 X%s Y%s S0', [FN(ox), FN(oy)]));
  ALines.Add(Format('G1 %s F%s', [ACfg.TurnOnCmd, FN(ACfg.GridFeed)]));
  forward := True;
  for xi := 0 to ACfg.PowerCols do
  begin
    ALines.Add(Format('X%s S0', [FN(ox + xi * xStep)]));
    for yi := 0 to ACfg.FeedRows do
    begin
      if forward then cx := yi * yStep else cx := ACfg.SizeY - yi * yStep;
      ALines.Add(Format('Y%s S%s', [FN(oy + cx), FN(ACfg.GridPower)]));
    end;
    forward := not forward;
  end;

  for xi := 0 to ACfg.PowerCols - 1 do
    AddHershey(ALines, Format('S%d', [Round(ACfg.PowerStart + xi * sDelta)]),
      (xi * xStep) + (xStep / 2) + ox, oy / 2, 'M4');
  for yi := 0 to ACfg.FeedRows - 1 do
    AddHershey(ALines, Format('F%d', [Round(ACfg.FeedStart + yi * fDelta)]),
      ox / 2, (yi * yStep) + (yStep / 2) + oy, 'M4');

  if ACfg.PowerStart <> ACfg.PowerEnd then
    srange := Format('S%d - S%d', [ACfg.PowerStart, ACfg.PowerEnd])
  else
    srange := Format('S%d', [ACfg.PowerEnd]);
  if ACfg.FeedStart <> ACfg.FeedEnd then
    frange := Format('F%d - F%d', [ACfg.FeedStart, ACfg.FeedEnd])
  else
    frange := Format('F%d', [ACfg.FeedEnd]);

  if ACfg.Title = '' then
    title := 'LaserGRBL power/speed test'
  else
    title := Format('LaserGRBL power/speed test [%s]', [ACfg.Title]);
  parmessage := Format('%s, %s, %s,  %s line/mm', [srange, frange, ACfg.TurnOnCmd, FN(ACfg.Resolution)]);

  AddHershey(ALines, title, ACfg.SizeX / 2 + ox, ACfg.SizeY + oy + oy + oy / 2, 'M4');
  AddHershey(ALines, parmessage, ACfg.SizeX / 2 + ox, ACfg.SizeY + oy + oy / 2, 'M4');

  ALines.Add('M5');
end;

// EmitShakeBurst: mirrors the real GenerateShakeTest2 - repeated short
// back-and-forth rapid moves around a series of centers spaced `ATrip`
// apart along the tested axis, amplitude growing with each burst call
// (ATrip/2, then further out) so resonance/skipped-steps show up as an
// increasingly blurred crosshair at higher speed/amplitude combinations.
procedure EmitShakeBurst(ALines: TStrings; AAxis: Char; AFeedLimit, AAxisLen,
  AOrigin, ATrip: Integer; AStep: Double);
var
  c: Integer;
  i: Double;
begin
  c := ATrip div 2;
  while c < AAxisLen - ATrip div 2 do
  begin
    i := 0;
    while i < ATrip / 3 do
    begin
      ALines.Add(Format('G1 F%d %s%s', [AFeedLimit, AAxis, FN(AOrigin + c + i)]));
      ALines.Add(Format('G1 F%d %s%s', [AFeedLimit, AAxis, FN(AOrigin + c - i)]));
      i := i + AStep;
    end;
    c := c + ATrip;
  end;
end;

procedure GenerateShakeTest(const ACfg: TShakeTestConfig; ALines: TStrings);
var
  axisChar: Char;
begin
  if ACfg.Axis = saX then axisChar := 'X' else axisChar := 'Y';

  ALines.Add(Format('(--- Shake test %s ---)', [axisChar]));
  ALines.Add('M5');
  ALines.Add('G1 F1000 X0 Y0 S0');
  ALines.Add(Format('G1 F%d X7 Y10', [ACfg.CrossSpeed]));
  ALines.Add('M4');
  ALines.Add(Format('G1 F%d S%d X13 Y10', [ACfg.CrossSpeed, ACfg.CrossPower]));
  ALines.Add('M5');
  ALines.Add(Format('G1 F%d X10 Y7', [ACfg.CrossSpeed]));
  ALines.Add('M4');
  ALines.Add(Format('G1 F%d S%d X10 Y13', [ACfg.CrossSpeed, ACfg.CrossPower]));
  ALines.Add('M5');
  ALines.Add('G1 F1000 X10 Y10 S0');

  EmitShakeBurst(ALines, axisChar, ACfg.FeedLimit, ACfg.AxisLength, 10, 50, 0.5);
  EmitShakeBurst(ALines, axisChar, ACfg.FeedLimit, ACfg.AxisLength, 10, 100, 2);
  EmitShakeBurst(ALines, axisChar, ACfg.FeedLimit, ACfg.AxisLength, 10, 200, 4);
  EmitShakeBurst(ALines, axisChar, ACfg.FeedLimit, ACfg.AxisLength, 10, 400, 8);

  ALines.Add(Format('G1 F%d X10 Y10 S0', [ACfg.CrossSpeed]));

  ALines.Add(Format('G1 F%d X7 Y10', [ACfg.CrossSpeed]));
  ALines.Add('M4');
  ALines.Add(Format('G1 F%d S%d X13 Y10', [ACfg.CrossSpeed, ACfg.CrossPower]));
  ALines.Add('M5');
  ALines.Add(Format('G1 F%d X10 Y7', [ACfg.CrossSpeed]));
  ALines.Add('M4');
  ALines.Add(Format('G1 F%d S%d X10 Y13', [ACfg.CrossSpeed, ACfg.CrossPower]));
  ALines.Add('M5');
  ALines.Add('G1 F1000 X0 Y0 S0');
end;

initialization
  GInvFS := DefaultFormatSettings;
  GInvFS.DecimalSeparator := '.';

end.
