unit ugrbl1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ugenericcontroller, ugenericgrbl, uboardinfo, usettingsmeta;

const
  // Extended realtime override commands (GRBL1.py)
  OV_FEED_100    = #$90;
  OV_FEED_INC10  = #$91;
  OV_FEED_DEC10  = #$92;
  OV_FEED_INC1   = #$93;
  OV_FEED_DEC1   = #$94;
  OV_RAPID_100   = #$95;
  OV_RAPID_50    = #$96;
  OV_RAPID_25    = #$97;
  OV_SPINDLE_100 = #$99;
  OV_SPINDLE_INC10 = #$9A;
  OV_SPINDLE_DEC10 = #$9B;
  OV_SPINDLE_INC1  = #$9C;
  OV_SPINDLE_DEC1  = #$9D;

type
  { TGRBL1Controller ports controllers/GRBL1.py: pipe-delimited status
    reports (<State|MPos:x,y,z|FS:f,s|...>) and native realtime overrides. }
  TGRBL1Controller = class(TGenericGRBLController)
  public
    constructor Create(AHost: IControllerHost);
    procedure Jog(const ADirection: string); override;
    procedure OverrideSet; override;
    procedure ParseBracketAngle(const ALine: string; ACLine: TLineFifo); override;
    procedure ParseBracketSquare(const ALine: string); override;
  end;

implementation

// Mirrors controllers/_GenericController.py SPLITPAT = re.compile(r"[:,]")
function SplitFields(const S: string): TStringArray;
var
  parts: TStringList;
  i, start: Integer;
begin
  parts := TStringList.Create;
  try
    start := 1;
    for i := 1 to Length(S) do
      if (S[i] = ':') or (S[i] = ',') then
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

constructor TGRBL1Controller.Create(AHost: IControllerHost);
begin
  inherited Create(AHost);
  FGCodeCase := 0;
  FHasOverride := True;
end;

procedure TGRBL1Controller.Jog(const ADirection: string);
begin
  // GRBL1.py jog(): uses $J= realtime jog command instead of G91/G0/G90
  FHost.SendGCode('$J=G91 ' + ADirection + ' F100000');
end;

procedure TGRBL1Controller.OverrideSet;
var
  diff: Integer;
begin
  with FHost.State do
  begin
    OvChanged := False;

    diff := TargetOvFeed - OvFeed;
    if diff = 0 then
      // no change
    else if TargetOvFeed = 100 then
      FHost.SerialWriteRaw(OV_FEED_100)
    else if diff >= 10 then
    begin
      FHost.SerialWriteRaw(OV_FEED_INC10);
      OvChanged := diff > 10;
    end
    else if diff <= -10 then
    begin
      FHost.SerialWriteRaw(OV_FEED_DEC10);
      OvChanged := diff < -10;
    end
    else if diff >= 1 then
    begin
      FHost.SerialWriteRaw(OV_FEED_INC1);
      OvChanged := diff > 1;
    end
    else if diff <= -1 then
    begin
      FHost.SerialWriteRaw(OV_FEED_DEC1);
      OvChanged := diff < -1;
    end;

    if TargetOvRapid <> OvRapid then
    begin
      if TargetOvRapid = 100 then FHost.SerialWriteRaw(OV_RAPID_100)
      else if TargetOvRapid = 50 then FHost.SerialWriteRaw(OV_RAPID_50)
      else if TargetOvRapid = 25 then FHost.SerialWriteRaw(OV_RAPID_25);
    end;

    diff := TargetOvSpindle - OvSpindle;
    if diff = 0 then
      // no change
    else if TargetOvSpindle = 100 then
      FHost.SerialWriteRaw(OV_SPINDLE_100)
    else if diff >= 10 then
    begin
      FHost.SerialWriteRaw(OV_SPINDLE_INC10);
      OvChanged := OvChanged or (diff > 10);
    end
    else if diff <= -10 then
    begin
      FHost.SerialWriteRaw(OV_SPINDLE_DEC10);
      OvChanged := OvChanged or (diff < -10);
    end
    else if diff >= 1 then
    begin
      FHost.SerialWriteRaw(OV_SPINDLE_INC1);
      OvChanged := OvChanged or (diff > 1);
    end
    else if diff <= -1 then
    begin
      FHost.SerialWriteRaw(OV_SPINDLE_DEC1);
      OvChanged := OvChanged or (diff < -1);
    end;
  end;
end;

procedure TGRBL1Controller.ParseBracketAngle(const ALine: string; ACLine: TLineFifo);
var
  inner: string;
  fields: TStringArray;
  word: TStringArray;
  i: Integer;
  st, mainState: string;
begin
  FHost.SetSioStatus(False);
  if (Length(ALine) < 2) then Exit;
  inner := Copy(ALine, 2, Length(ALine) - 2); // strip leading '<' and trailing '>'
  fields := inner.Split('|');
  if Length(fields) = 0 then Exit;

  st := fields[0];
  FHost.State.Pins := '';
  DisplayState(st);

  for i := 1 to High(fields) do
  begin
    word := SplitFields(fields[i]);
    if Length(word) = 0 then Continue;

    with FHost.State do
    begin
      if word[0] = 'MPos' then
      begin
        if Length(word) > 3 then
        begin
          MX := StrToFloatDef(word[1], MX);
          MY := StrToFloatDef(word[2], MY);
          MZ := StrToFloatDef(word[3], MZ);
          WX := MX - WCOX;
          WY := MY - WCOY;
          WZ := MZ - WCOZ;
        end;
      end
      else if word[0] = 'F' then
      begin
        if Length(word) > 1 then CurFeed := StrToFloatDef(word[1], CurFeed);
      end
      else if word[0] = 'FS' then
      begin
        if Length(word) > 2 then
        begin
          CurFeed := StrToFloatDef(word[1], CurFeed);
          CurSpindle := StrToFloatDef(word[2], CurSpindle);
        end;
      end
      else if word[0] = 'Bf' then
      begin
        if Length(word) > 2 then
        begin
          Planner := StrToIntDef(word[1], Planner);
          RxBytes := StrToIntDef(word[2], RxBytes);
        end;
      end
      else if word[0] = 'Ov' then
      begin
        if Length(word) > 3 then
        begin
          OvFeed := StrToIntDef(word[1], OvFeed);
          OvRapid := StrToIntDef(word[2], OvRapid);
          OvSpindle := StrToIntDef(word[3], OvSpindle);
        end;
      end
      else if word[0] = 'WCO' then
      begin
        if Length(word) > 3 then
        begin
          WCOX := StrToFloatDef(word[1], WCOX);
          WCOY := StrToFloatDef(word[2], WCOY);
          WCOZ := StrToFloatDef(word[3], WCOZ);
        end;
      end
      else if word[0] = 'Pn' then
      begin
        if Length(word) > 1 then Pins := word[1];
      end;
    end;
  end;

  mainState := st;
  if Pos(':', mainState) > 0 then
    mainState := Copy(mainState, 1, Pos(':', mainState) - 1);
  if FHost.SioWait and (ACLine.Count = 0) and
     (mainState <> 'Run') and (mainState <> 'Jog') and (mainState <> 'Hold') then
    FHost.NotifyIdleBufferEmpty;
end;

procedure TGRBL1Controller.ParseBracketSquare(const ALine: string);
var
  inner, tag, value: string;
  colonPos: Integer;
  word: TStringArray;
  meta: TSettingMeta;
begin
  if Length(ALine) < 2 then Exit;
  inner := Copy(ALine, 2, Length(ALine) - 2);

  // Split on the FIRST ':' only (not SplitFields' comma+colon split) so
  // multi-field values like OPT's "VNMS,15,128,4,2" or a board name with
  // a colon in it survive intact for ParseBuildInfoTag below - PRB/TLO
  // still need their value comma-split, done separately per-tag.
  colonPos := Pos(':', inner);
  if colonPos = 0 then Exit;
  tag := Copy(inner, 1, colonPos - 1);
  value := Copy(inner, colonPos + 1, Length(inner) - colonPos);

  if tag = 'PRB' then
  begin
    word := SplitFields(value);
    if Length(word) > 2 then
    begin
      FHost.State.PRBX := StrToFloatDef(word[0], 0) - FHost.State.WCOX;
      FHost.State.PRBY := StrToFloatDef(word[1], 0) - FHost.State.WCOY;
      FHost.State.PRBZ := StrToFloatDef(word[2], 0) - FHost.State.WCOZ;
      with FHost.State do
        FHost.NotifyProbeResult(PRBX, PRBY, PRBZ);
    end;
  end
  else if tag = 'TLO' then
    FHost.State.TLO := StrToFloatDef(value, FHost.State.TLO)
  else if tag = 'SETTING' then
    // Phase F2: grblHAL's $ES ("enumerate settings") machine-readable
    // response - one [SETTING:...] line per setting, enriches Phase F's
    // bare $$ grid with name/unit/type/range/options. µCNC and vanilla
    // GRBL0/1 don't implement $ES, so this simply never fires for them -
    // no firmware check needed here.
    begin
      if TryParseSettingDetailLine(ALine, meta) then
        FHost.State.SettingsMeta.AddOrReplace(meta);
    end
  else
    // $I build-info tags (VER/OPT/FIRMWARE/AXS/DRIVER/BOARD/...) - see
    // uboardinfo.pas. G92/G28/G30/GC parameter reports still deferred to
    // Phase 2 (ugcode.pas modal state application); they land harmlessly
    // in BoardInfo.RawTags for now via the generic fallback.
    ParseBuildInfoTag(FHost.State.BoardInfo, tag, value);
end;

end.
