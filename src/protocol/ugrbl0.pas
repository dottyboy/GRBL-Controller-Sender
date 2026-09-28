unit ugrbl0;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, RegExpr, ugenericcontroller, ugenericgrbl, uboardinfo;

type
  { TGRBL0Controller ports controllers/GRBL0.py - also used for the
    Smoothieboard-compatible status format (same STATUSPAT). }
  TGRBL0Controller = class(TGenericGRBLController)
  private
    FStatusRE: TRegExpr;
    FPosRE: TRegExpr;
    FTloRE: TRegExpr;
    FDollarRE: TRegExpr;
    procedure ParseSquareBuildInfoTag(const ALine: string);
  public
    constructor Create(AHost: IControllerHost);
    destructor Destroy; override;
    procedure ParseBracketAngle(const ALine: string; ACLine: TLineFifo); override;
    procedure ParseBracketSquare(const ALine: string); override;
  end;

implementation

constructor TGRBL0Controller.Create(AHost: IControllerHost);
begin
  inherited Create(AHost);
  FGCodeCase := 0;
  FHasOverride := False;

  // controllers/_GenericController.py STATUSPAT
  FStatusRE := TRegExpr.Create(
    '^<(\w*?),MPos:([+\-]?\d*\.\d*),([+\-]?\d*\.\d*),([+\-]?\d*\.\d*)' +
    '(?:,[+\-]?\d*\.\d*)?(?:,[+\-]?\d*\.\d*)?(?:,[+\-]?\d*\.\d*)?,WPos:' +
    '([+\-]?\d*\.\d*),([+\-]?\d*\.\d*),([+\-]?\d*\.\d*)' +
    '(?:,[+\-]?\d*\.\d*)?(?:,[+\-]?\d*\.\d*)?(?:,[+\-]?\d*\.\d*)?(?:,.*)?>$');
  // POSPAT
  FPosRE := TRegExpr.Create(
    '^\[(...):([+\-]?\d*\.\d*),([+\-]?\d*\.\d*),([+\-]?\d*\.\d*)' +
    '(?:,[+\-]?\d*\.\d*)?(?:,[+\-]?\d*\.\d*)?(?:,[+\-]?\d*\.\d*)?(:(\d*))?\]$');
  // TLOPAT
  FTloRE := TRegExpr.Create('^\[(...):([+\-]?\d*\.\d*)\]$');
  // DOLLARPAT
  FDollarRE := TRegExpr.Create('^\[G\d* .*\]$');
end;

destructor TGRBL0Controller.Destroy;
begin
  FStatusRE.Free;
  FPosRE.Free;
  FTloRE.Free;
  FDollarRE.Free;
  inherited Destroy;
end;

procedure TGRBL0Controller.ParseBracketAngle(const ALine: string; ACLine: TLineFifo);
var
  st: string;
  mx, my, mz, wx, wy, wz: Double;
begin
  FHost.SetSioStatus(False);
  if not FStatusRE.Exec(ALine) then Exit;

  st := FStatusRE.Match[1];
  if Pos('ALARM:', FHost.State.StateStr) <> 1 then
    FHost.State.StateStr := st;

  mx := StrToFloatDef(FStatusRE.Match[2], 0);
  my := StrToFloatDef(FStatusRE.Match[3], 0);
  mz := StrToFloatDef(FStatusRE.Match[4], 0);
  wx := StrToFloatDef(FStatusRE.Match[5], 0);
  wy := StrToFloatDef(FStatusRE.Match[6], 0);
  wz := StrToFloatDef(FStatusRE.Match[7], 0);

  with FHost.State do
  begin
    MX := mx; MY := my; MZ := mz;
    WX := wx; WY := wy; WZ := wz;
    WCOX := mx - wx;
    WCOY := my - wy;
    WCOZ := mz - wz;
    if (Copy(st, 1, 4) <> 'Hold') and (Msg <> '') then
      Msg := '';
  end;

  // Machine Idle & buffer empty -> stop waiting on a queued WAIT item
  if FHost.SioWait and (ACLine.Count = 0) and
     (st <> 'Run') and (st <> 'Jog') and (st <> 'Hold') then
    FHost.NotifyIdleBufferEmpty
  else
    FHost.LogReceived(ALine);
end;

procedure TGRBL0Controller.ParseBracketSquare(const ALine: string);
begin
  if FPosRE.Exec(ALine) then
  begin
    // PRB / G54 / G92 / TLO etc. bracket reports - PRB position handling
    if FPosRE.Match[1] = 'PRB' then
    begin
      FHost.State.PRBX := StrToFloatDef(FPosRE.Match[2], 0);
      FHost.State.PRBY := StrToFloatDef(FPosRE.Match[3], 0);
      FHost.State.PRBZ := StrToFloatDef(FPosRE.Match[4], 0);
      // GRBL0.py: gcode.probe.add(prbx + wx - mx, prby + wy - my, prbz + wz - mz)
      // - PRB is reported in machine coords, converted to work coords here.
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
    // $G parser-state report, e.g. "[G0 G54 G17 G21 G90 G94 M0 M5 M9 T0 F0 S0]"
    // Modal-state application deferred to ugcode.pas / Phase 2.
  end
  else
  begin
    // None of the numeric-triplet patterns above matched - fall back to a
    // generic first-colon split for $I build-info tags (VER/OPT/FIRMWARE/
    // AXS/DRIVER/BOARD/...), same as ugrbl1.pas. Plain GRBL0's own $I is
    // sparse (often just VER) but grblHAL boards still speaking the older
    // GRBL0 status-report dialect can report the richer tags too.
    ParseSquareBuildInfoTag(ALine);
  end;
end;

procedure TGRBL0Controller.ParseSquareBuildInfoTag(const ALine: string);
var
  inner, tag, value: string;
  colonPos: Integer;
begin
  if Length(ALine) < 2 then Exit;
  inner := Copy(ALine, 2, Length(ALine) - 2);
  colonPos := Pos(':', inner);
  if colonPos = 0 then Exit;
  tag := Copy(inner, 1, colonPos - 1);
  value := Copy(inner, colonPos + 1, Length(inner) - colonPos);
  ParseBuildInfoTag(FHost.State.BoardInfo, tag, value);
end;

end.
