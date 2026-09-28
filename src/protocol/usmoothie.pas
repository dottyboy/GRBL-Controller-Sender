unit usmoothie;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, RegExpr, ugenericcontroller;

type
  { TSmoothieController ports controllers/SMOOTHIE.py. Note it extends the
    plain TGenericController (not the GRBL error-code table), matching
    Python's `class Controller(_GenericController)`. Status format:
    "<Idle|MPos:x,y,z,a|WPos:x,y,z|F:nnn|S:n>" - pipe-delimited but with
    WPos reported directly (unlike GRBL1, no WCO-based computation). }
  TSmoothieController = class(TGenericController)
  private
    FPosRE: TRegExpr;
    FTloRE: TRegExpr;
    FDollarRE: TRegExpr;
  public
    constructor Create(AHost: IControllerHost);
    destructor Destroy; override;
    procedure ParseBracketAngle(const ALine: string; ACLine: TLineFifo); override;
    procedure ParseBracketSquare(const ALine: string); override;
  end;

implementation

function SplitChar(const S: string; Sep: Char): TStringArray;
var
  parts: TStringList;
  i, start: Integer;
begin
  parts := TStringList.Create;
  try
    start := 1;
    for i := 1 to Length(S) do
      if S[i] = Sep then
      begin
        parts.Add(Copy(S, start, i - start));
        start := i + 1;
      end;
    parts.Add(Copy(S, start, Length(S) - start + 1));
    Result := parts.ToStringArray;
  finally
    parts.Free;
  end;
end;

constructor TSmoothieController.Create(AHost: IControllerHost);
begin
  inherited Create(AHost);
  FGCodeCase := 1;   // SMOOTHIE.py: gcode_case = 1 (uppercase)
  FHasOverride := False;

  FPosRE := TRegExpr.Create(
    '^\[(...):([+\-]?\d*\.\d*),([+\-]?\d*\.\d*),([+\-]?\d*\.\d*)' +
    '(?:,[+\-]?\d*\.\d*)?(?:,[+\-]?\d*\.\d*)?(?:,[+\-]?\d*\.\d*)?(:(\d*))?\]$');
  FTloRE := TRegExpr.Create('^\[(...):([+\-]?\d*\.\d*)\]$');
  FDollarRE := TRegExpr.Create('^\[G\d* .*\]$');
end;

destructor TSmoothieController.Destroy;
begin
  FPosRE.Free;
  FTloRE.Free;
  FDollarRE.Free;
  inherited Destroy;
end;

procedure TSmoothieController.ParseBracketAngle(const ALine: string; ACLine: TLineFifo);
var
  inner, st: string;
  lval: TStringArray;
  i: Integer;
  kv: TStringArray;
  vals: TStringArray;
begin
  if Length(ALine) < 2 then Exit;
  inner := Copy(ALine, 2, Length(ALine) - 2);
  lval := inner.Split('|');
  if Length(lval) = 0 then Exit;

  st := lval[0];
  FHost.State.StateStr := st;

  for i := 1 to High(lval) do
  begin
    kv := SplitChar(lval[i], ':');
    if Length(kv) < 2 then Continue;
    vals := kv[1].Split(',');

    with FHost.State do
    begin
      if (kv[0] = 'MPos') and (Length(vals) >= 3) then
      begin
        MX := StrToFloatDef(vals[0], MX);
        MY := StrToFloatDef(vals[1], MY);
        MZ := StrToFloatDef(vals[2], MZ);
      end
      else if (kv[0] = 'WPos') and (Length(vals) >= 3) then
      begin
        WX := StrToFloatDef(vals[0], WX);
        WY := StrToFloatDef(vals[1], WY);
        WZ := StrToFloatDef(vals[2], WZ);
      end
      else if (kv[0] = 'F') and (Length(vals) >= 1) then
        CurFeed := StrToFloatDef(vals[0], CurFeed);
    end;
  end;

  with FHost.State do
  begin
    WCOX := MX - WX;
    WCOY := MY - WY;
    WCOZ := MZ - WZ;
  end;

  if FHost.SioWait and (ACLine.Count = 0) and
     (st <> 'Run') and (st <> 'Jog') and (st <> 'Hold') then
    FHost.NotifyIdleBufferEmpty;
end;

procedure TSmoothieController.ParseBracketSquare(const ALine: string);
begin
  if FPosRE.Exec(ALine) then
  begin
    if FPosRE.Match[1] = 'PRB' then
    begin
      FHost.State.PRBX := StrToFloatDef(FPosRE.Match[2], 0);
      FHost.State.PRBY := StrToFloatDef(FPosRE.Match[3], 0);
      FHost.State.PRBZ := StrToFloatDef(FPosRE.Match[4], 0);
      // SMOOTHIE.py: gcode.probe.add(prbx + wx - mx, prby + wy - my, prbz + wz - mz)
      with FHost.State do
        FHost.NotifyProbeResult(PRBX + WX - MX, PRBY + WY - MY, PRBZ + WZ - MZ);
    end;
  end
  else if FTloRE.Exec(ALine) then
  begin
    if FTloRE.Match[1] = 'TLO' then
      FHost.State.TLO := StrToFloatDef(FTloRE.Match[2], 0);
  end
  else if FDollarRE.Exec(ALine) then
  begin
    // $G parser-state report - deferred to Phase 2
  end;
end;

end.
