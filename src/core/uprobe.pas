unit uprobe;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math;

type
  { TProbeGrid ports bCNC's CNC.py Probe class: a rectangular grid of
    probed Z heights over the work area, used to (a) generate the g-code
    that drives the probing sequence and (b) bilinearly interpolate a Z
    correction for any (x,y) once the grid is filled - the standard
    "autolevel" technique for a work surface that isn't perfectly flat. }
  TProbeGrid = class
  private
    FXMin, FXMax, FYMin, FYMax, FZMin, FZMax: Double;
    FXN, FYN: Integer;
    FXStep, FYStep: Double;
    FMatrix: array of array of Double; // [row(y)][col(x)]
    FPointCount: Integer; // how many of XN*YN cells have been filled
    FStarted: Boolean;
    procedure RecalcSteps;
  public
    ProbeFeed: Double;
    ProbeCommand: string; // e.g. 'G38.2'
    SafeZ: Double;

    constructor Create;
    procedure Configure(AXMin, AXMax, AYMin, AYMax, AZMin, AZMax: Double; AXN, AYN: Integer);
    procedure Clear;
    procedure MakeMatrix;
    function IsEmpty: Boolean;
    function IsComplete: Boolean;

    // Generates the G0/probe-command sequence to scan the whole grid,
    // mirrors CNC.py Probe.scan() including the "%wait" sentinels between
    // each rapid-to-point and probe-command (usender.pas's TSenderThread
    // special-cases that literal string - see GCODE_WAIT_MARKER).
    procedure GenerateScanGCode(AResult: TStrings);

    // Record one probed point (already in work coordinates) into the
    // matrix at its nearest grid cell - mirrors Probe.add(). Call this
    // from a TSender.OnProbeResult handler while a scan is in progress.
    procedure AddPoint(AX, AY, AZ: Double);

    // Bilinear Z interpolation at an arbitrary (x,y) - mirrors
    // Probe.interpolate(). Returns 0 if the grid is empty.
    function Interpolate(AX, AY: Double): Double;

    // Rebase the whole matrix so Z=0 at (x,y) - mirrors Probe.setZero():
    // useful when the current tool position is the desired reference
    // point (e.g. after a separate single-point Z-zero probe).
    procedure SetZero(AX, AY: Double);

    procedure SaveToFile(const AFileName: string);
    procedure LoadFromFile(const AFileName: string);

    property XMin: Double read FXMin;
    property XMax: Double read FXMax;
    property YMin: Double read FYMin;
    property YMax: Double read FYMax;
    property ZMin: Double read FZMin;
    property ZMax: Double read FZMax;
    property XN: Integer read FXN;
    property YN: Integer read FYN;
    property PointCount: Integer read FPointCount;
    property Started: Boolean read FStarted write FStarted;
    function MatrixValue(ARow, ACol: Integer): Double;
  end;

  TTouchProbeAxis = (paX, paY);
  TTouchProbeStage = (tsIdle, tsZ, tsCornerA1, tsCornerA2, tsCornerB1,
    tsCornerB2, tsEdge);

  { TTouchProbe ports bCNC's ProbeFrame.probeCenter() and the Z touch-off half
    of ToolFrame's tool-length-probe workflow: single-touch and paired-touch
    probing for setting work zero on general stock (wood/acrylic/etc), as
    opposed to TProbeGrid's PCB-style height-map scan. Diameter is entered by
    the operator (bCNC: self.diameter) as the approximate feature size (bore/
    boss diameter, or an edge-finder tip's ball diameter) - not auto-detected.

    Unlike TProbeGrid.GenerateScanGCode (which can be generated all at once
    since every waypoint is independent), a corner/edge probe's later moves
    depend on where the earlier touch actually landed, so this is a small
    state machine driven by repeated calls to HandleProbeResult - mirrors
    TSender.OnProbeResult already being used exactly this way by
    uprobeframe.pas for the grid workflow. bCNC does the equivalent
    sequencing by having the controller evaluate g-code bracket expressions
    ("g53 g0 x[prbx+...]") and %global variables at runtime; this port has no
    such expression evaluator, so the same math is done here in Pascal
    against each PRB result (already in work coordinates - see
    TGRBL1Controller.ParseBracketSquare) and the next literal move is emitted. }
  TTouchProbe = class
  private
    FStage: TTouchProbeStage;
    FDiameter: Double;
    FZOffset: Double;
    FRetract: Double;
    FSearchDist: Double;
    FProbeFeed: Double;
    FProbeCmd: string;
    FAxis: TTouchProbeAxis;
    FDir: Integer;
    FTouch1: Double;
    function AxisLetter: Char;
  public
    constructor Create;
    property Diameter: Double read FDiameter write FDiameter;
    property ZOffset: Double read FZOffset write FZOffset;
    property Retract: Double read FRetract write FRetract;
    property SearchDist: Double read FSearchDist write FSearchDist;
    property ProbeFeed: Double read FProbeFeed write FProbeFeed;
    property ProbeCmd: string read FProbeCmd write FProbeCmd;
    property Stage: TTouchProbeStage read FStage;
    function IsActive: Boolean;

    // Single-axis touch: sets the active WCS Z so the contact point reads
    // as ZOffset (plate thickness, or 0 to zero directly on the stock).
    procedure StartZOnly(AResult: TStrings);

    // Two-axis bore/boss/outside-corner center-find: probes X-/X+ then
    // Y-/Y+ (mirrors bCNC probeCenter()), moves to the computed center and
    // zeros WCS X/Y there. Diameter is the approximate feature size, used
    // both as search distance and as the small backoff between the two
    // touches of each axis pair.
    procedure StartCornerCenter(AResult: TStrings);

    // Single-edge touch with radius compensation (a ball/disc-tip edge
    // finder): probes toward the edge along AAxis in direction ADir (+1/-1),
    // then moves the remaining Diameter/2 to the true edge and zeros that
    // axis there.
    procedure StartEdgeFinder(AAxis: TTouchProbeAxis; ADir: Integer; AResult: TStrings);

    // Feed each PRB result (already in work coordinates) here, e.g. from a
    // TSender.OnProbeResult handler. Fills AResult with the next g-code
    // lines to enqueue and returns True while the sequence continues, or
    // False once it has finished (IsActive becomes False).
    function HandleProbeResult(AX, AY, AZ: Double; AResult: TStrings): Boolean;
  end;

implementation

var
  GInvFS: TFormatSettings; // '.' decimal separator, regardless of locale

constructor TProbeGrid.Create;
begin
  inherited Create;
  FXMin := 0; FXMax := 10; FYMin := 0; FYMax := 10;
  FZMin := -10; FZMax := 3;
  FXN := 5; FYN := 5;
  ProbeFeed := 10.0;
  ProbeCommand := 'G38.2';
  SafeZ := 3.0;
  RecalcSteps;
end;

procedure TProbeGrid.RecalcSteps;
begin
  if FXN > 1 then FXStep := (FXMax - FXMin) / (FXN - 1) else FXStep := 1;
  if FYN > 1 then FYStep := (FYMax - FYMin) / (FYN - 1) else FYStep := 1;
end;

procedure TProbeGrid.Configure(AXMin, AXMax, AYMin, AYMax, AZMin, AZMax: Double;
  AXN, AYN: Integer);
begin
  FXMin := AXMin; FXMax := AXMax;
  FYMin := AYMin; FYMax := AYMax;
  FZMin := AZMin; FZMax := AZMax;
  FXN := Max(2, AXN);
  FYN := Max(2, AYN);
  RecalcSteps;
end;

procedure TProbeGrid.Clear;
begin
  SetLength(FMatrix, 0);
  FPointCount := 0;
  FStarted := False;
end;

procedure TProbeGrid.MakeMatrix;
var
  j: Integer;
begin
  SetLength(FMatrix, FYN, FXN);
  for j := 0 to FYN - 1 do
    FillChar(FMatrix[j][0], FXN * SizeOf(Double), 0);
  FPointCount := 0;
end;

function TProbeGrid.IsEmpty: Boolean;
begin
  Result := Length(FMatrix) = 0;
end;

function TProbeGrid.IsComplete: Boolean;
begin
  Result := (not IsEmpty) and (FPointCount >= FXN * FYN);
end;

procedure TProbeGrid.GenerateScanGCode(AResult: TStrings);
var
  x, xstep: Double;
  i, j: Integer;
  y: Double;
begin
  Clear;
  FStarted := True;
  MakeMatrix;

  x := FXMin;
  xstep := FXStep;
  AResult.Add(Format('G0Z%.4f', [SafeZ], GInvFS));
  AResult.Add(Format('G0X%.4fY%.4f', [FXMin, FYMin], GInvFS));

  for j := 0 to FYN - 1 do
  begin
    y := FYMin + FYStep * j;
    for i := 0 to FXN - 1 do
    begin
      AResult.Add(Format('G0Z%.4f', [FZMax], GInvFS));
      AResult.Add(Format('G0X%.4fY%.4f', [x, y], GInvFS));
      AResult.Add('%wait');
      AResult.Add(Format('%sZ%.4fF%g', [ProbeCommand, FZMin, ProbeFeed], GInvFS));
      AResult.Add('%wait');
      x := x + xstep;
    end;
    x := x - xstep;
    xstep := -xstep;
  end;

  AResult.Add(Format('G0Z%.4f', [FZMax], GInvFS));
  AResult.Add(Format('G0X%.4fY%.4f', [FXMin, FYMin], GInvFS));
end;

procedure TProbeGrid.AddPoint(AX, AY, AZ: Double);
var
  i, j: Integer;
  rem: Double;
begin
  if not FStarted then Exit;
  if IsEmpty then Exit;

  i := Round((AX - FXMin) / FXStep);
  if (i < 0) or (i > FXN) then Exit;

  j := Round((AY - FYMin) / FYStep);
  if (j < 0) or (j > FYN) then Exit;

  rem := Abs(AX - (i * FXStep + FXMin));
  if rem > FXStep / 10.0 then Exit;

  rem := Abs(AY - (j * FYStep + FYMin));
  if rem > FYStep / 10.0 then Exit;

  if (j >= 0) and (j < FYN) and (i >= 0) and (i < FXN) then
  begin
    FMatrix[j][i] := AZ;
    Inc(FPointCount);
  end;

  if FPointCount >= FXN * FYN then
    FStarted := False;
end;

function TProbeGrid.Interpolate(AX, AY: Double): Double;
var
  ix, jy: Double;
  i, j: Integer;
  a, b, a1, b1: Double;
begin
  if IsEmpty then
  begin
    Result := 0;
    Exit;
  end;

  ix := (AX - FXMin) / FXStep;
  jy := (AY - FYMin) / FYStep;
  i := Floor(ix);
  j := Floor(jy);

  if i < 0 then i := 0
  else if i >= FXN - 1 then i := FXN - 2;

  if j < 0 then j := 0
  else if j >= FYN - 1 then j := FYN - 2;

  a := ix - i; b := jy - j;
  a1 := 1.0 - a; b1 := 1.0 - b;

  Result := a1 * b1 * FMatrix[j][i] +
            a1 * b * FMatrix[j + 1][i] +
            a * b1 * FMatrix[j][i + 1] +
            a * b * FMatrix[j + 1][i + 1];
end;

procedure TProbeGrid.SetZero(AX, AY: Double);
var
  zero: Double;
  i, j: Integer;
begin
  if IsEmpty then Exit;
  zero := Interpolate(AX, AY);
  for j := 0 to FYN - 1 do
    for i := 0 to FXN - 1 do
      FMatrix[j][i] := FMatrix[j][i] - zero;
end;

function TProbeGrid.MatrixValue(ARow, ACol: Integer): Double;
begin
  if (ARow >= 0) and (ARow < Length(FMatrix)) and
     (ACol >= 0) and (ACol < Length(FMatrix[ARow])) then
    Result := FMatrix[ARow][ACol]
  else
    Result := 0;
end;

procedure TProbeGrid.SaveToFile(const AFileName: string);
var
  f: TextFile;
  i, j: Integer;
  x, y: Double;
  fs: TFormatSettings;
begin
  fs := GInvFS;
  AssignFile(f, AFileName);
  Rewrite(f);
  try
    WriteLn(f, Format('%g %g %d', [FXMin, FXMax, FXN], fs));
    WriteLn(f, Format('%g %g %d', [FYMin, FYMax, FYN], fs));
    WriteLn(f, Format('%g %g %g', [FZMin, FZMax, ProbeFeed], fs));
    WriteLn(f);
    for j := 0 to FYN - 1 do
    begin
      y := FYMin + FYStep * j;
      for i := 0 to FXN - 1 do
      begin
        x := FXMin + FXStep * i;
        WriteLn(f, Format('%g %g %g', [x, y, FMatrix[j][i]], fs));
      end;
      WriteLn(f);
    end;
  finally
    CloseFile(f);
  end;
end;

procedure TProbeGrid.LoadFromFile(const AFileName: string);
var
  f: TextFile;
  line: string;
  parts: TStringArray;
  i, j: Integer;
  fs: TFormatSettings;

  function ReadNonEmptyLine: string;
  begin
    repeat
      ReadLn(f, Result);
      Result := Trim(Result);
    until (Result <> '') or Eof(f);
  end;

begin
  fs := GInvFS;
  AssignFile(f, AFileName);
  Reset(f);
  try
    line := ReadNonEmptyLine;
    parts := line.Split(' ');
    FXMin := StrToFloatDef(parts[0], FXMin, fs);
    FXMax := StrToFloatDef(parts[1], FXMax, fs);
    FXN := Max(2, StrToIntDef(parts[2], FXN));

    line := ReadNonEmptyLine;
    parts := line.Split(' ');
    FYMin := StrToFloatDef(parts[0], FYMin, fs);
    FYMax := StrToFloatDef(parts[1], FYMax, fs);
    FYN := Max(2, StrToIntDef(parts[2], FYN));

    line := ReadNonEmptyLine;
    parts := line.Split(' ');
    FZMin := StrToFloatDef(parts[0], FZMin, fs);
    FZMax := StrToFloatDef(parts[1], FZMax, fs);
    ProbeFeed := StrToFloatDef(parts[2], ProbeFeed, fs);

    RecalcSteps;
    MakeMatrix;

    for j := 0 to FYN - 1 do
      for i := 0 to FXN - 1 do
      begin
        line := ReadNonEmptyLine;
        parts := line.Split(' ');
        if Length(parts) >= 3 then
          FMatrix[j][i] := StrToFloatDef(parts[2], 0, fs);
      end;
    FPointCount := FXN * FYN;
    FStarted := False;
  finally
    CloseFile(f);
  end;
end;

{ TTouchProbe }

constructor TTouchProbe.Create;
begin
  inherited Create;
  FStage := tsIdle;
  FDiameter := 6.0;
  FZOffset := 0.0;
  FRetract := 2.0;
  FSearchDist := 25.0;
  FProbeFeed := 10.0;
  FProbeCmd := 'G38.2';
end;

function TTouchProbe.AxisLetter: Char;
begin
  if FAxis = paX then Result := 'X' else Result := 'Y';
end;

function TTouchProbe.IsActive: Boolean;
begin
  Result := FStage <> tsIdle;
end;

procedure TTouchProbe.StartZOnly(AResult: TStrings);
begin
  FStage := tsZ;
  AResult.Add(Format('G91 %s F%.3f Z-%.4f', [FProbeCmd, FProbeFeed, FSearchDist], GInvFS));
  AResult.Add('%wait');
end;

procedure TTouchProbe.StartCornerCenter(AResult: TStrings);
begin
  FStage := tsCornerA1;
  FAxis := paX;
  AResult.Add(Format('G91 %s F%.3f X-%.4f', [FProbeCmd, FProbeFeed, FDiameter], GInvFS));
  AResult.Add('%wait');
end;

procedure TTouchProbe.StartEdgeFinder(AAxis: TTouchProbeAxis; ADir: Integer; AResult: TStrings);
begin
  FStage := tsEdge;
  FAxis := AAxis;
  FDir := ADir;
  AResult.Add(Format('G91 %s F%.3f %s%.4f',
    [FProbeCmd, FProbeFeed, AxisLetter, FSearchDist * FDir], GInvFS));
  AResult.Add('%wait');
end;

function TTouchProbe.HandleProbeResult(AX, AY, AZ: Double; AResult: TStrings): Boolean;
var
  center, delta: Double;
begin
  Result := True;
  case FStage of
    tsZ:
      begin
        AResult.Add(Format('G10 L20 P1 Z%.4f', [FZOffset], GInvFS));
        AResult.Add(Format('G91 G0 Z%.4f', [FRetract], GInvFS));
        AResult.Add('G90');
        FStage := tsIdle;
        Result := False;
      end;

    tsCornerA1:
      begin
        FTouch1 := AX;
        AResult.Add(Format('G91 G0 X%.4f', [FDiameter / 10.0], GInvFS));
        AResult.Add('%wait');
        AResult.Add(Format('G91 %s F%.3f X%.4f', [FProbeCmd, FProbeFeed, FDiameter], GInvFS));
        AResult.Add('%wait');
        FStage := tsCornerA2;
      end;
    tsCornerA2:
      begin
        center := 0.5 * (FTouch1 + AX);
        AResult.Add('G90');
        AResult.Add(Format('G0 X%.4f', [center], GInvFS));
        AResult.Add('%wait');
        AResult.Add(Format('G91 %s F%.3f Y-%.4f', [FProbeCmd, FProbeFeed, FDiameter], GInvFS));
        AResult.Add('%wait');
        FStage := tsCornerB1;
      end;
    tsCornerB1:
      begin
        FTouch1 := AY;
        AResult.Add(Format('G91 G0 Y%.4f', [FDiameter / 10.0], GInvFS));
        AResult.Add('%wait');
        AResult.Add(Format('G91 %s F%.3f Y%.4f', [FProbeCmd, FProbeFeed, FDiameter], GInvFS));
        AResult.Add('%wait');
        FStage := tsCornerB2;
      end;
    tsCornerB2:
      begin
        center := 0.5 * (FTouch1 + AY);
        AResult.Add('G90');
        AResult.Add(Format('G0 Y%.4f', [center], GInvFS));
        AResult.Add('%wait');
        AResult.Add('G10 L20 P1 X0 Y0');
        FStage := tsIdle;
        Result := False;
      end;

    tsEdge:
      begin
        // Contact lands Diameter/2 short of the true edge (the ball/disc
        // surface touched, not its center) - move the remaining distance in
        // the same direction of travel, zero that axis there, then retract.
        delta := (FDiameter / 2.0) * FDir;
        AResult.Add(Format('G91 G0 %s%.4f', [AxisLetter, delta], GInvFS));
        AResult.Add('%wait');
        AResult.Add('G90');
        AResult.Add(Format('G10 L20 P1 %s0', [AxisLetter]));
        AResult.Add(Format('G91 G0 %s%.4f', [AxisLetter, -FRetract * FDir], GInvFS));
        AResult.Add('G90');
        FStage := tsIdle;
        Result := False;
      end;
  else
    Result := False;
  end;
end;

initialization
  GInvFS := DefaultFormatSettings;
  GInvFS.DecimalSeparator := '.';

end.
