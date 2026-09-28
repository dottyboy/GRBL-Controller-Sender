unit ugenericcontroller;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ucncstate, uvendorsniff;

// Recognizes a bare "$N=value" settings-dump line (as sent in response to
// $$, one per setting) - distinct from the "[TAG:...]" bracket lines
// ParseBracketSquare already handles. Verified this format is identical
// across grblHAL, uCNC (proto_gcode_setting_line_int/flt in
// grbl_protocol.c) and vanilla GRBL0/GRBL1, so one parser here covers all
// of them (Phase F - see the plan file's "universal $$ settings grid").
// Exported (not local to the implementation section) so it can be
// unit-tested standalone against literal $$ dump text.
function TryParseSettingLine(const ALine: string; out AID, AValue: string): Boolean;

type
  { TLineFifo mirrors bCNC Sender.py's parallel cline (lengths, "bytes in
    flight") / sline (actual line strings) lists (Sender.py serialIO(),
    ~line 725). Must stay in strict FIFO lockstep with what the controller
    has actually acknowledged - see usender.pas. }
  TLineFifo = class
  private
    FLengths: array of Integer;
    FLines: array of string;
    FCount: Integer;
  public
    procedure Push(const ALine: string);
    procedure PopFront;
    procedure Clear;
    function Count: Integer;
    function SumLengths: Integer;
    function FrontLine: string;
  end;

  { IControllerHost decouples controller protocol units from usender.pas
    (which owns the serial connection and the TThread), avoiding a circular
    unit dependency: usender.pas uses the controller units, and controllers
    call back into the host through this interface instead of depending on
    TSender directly. }
  IControllerHost = interface
    ['{6D1E2E2E-6B0A-4E86-9B0F-5E2E2F1E4A11}']
    // Queue a line of g-code for buffered/counted streaming (goes through
    // the RX_BUFFER_SIZE accounting in usender.pas).
    procedure SendGCode(const ALine: string);
    // Write raw bytes directly to the serial port, unbuffered/uncounted -
    // for GRBL realtime single-byte commands (?, !, ~, Ctrl-X) and status
    // polling, which bypass the line queue entirely (Sender.py: `?` sent
    // via serial_write, not queued).
    procedure SerialWriteRaw(const AData: string);
    function State: TCNCState;
    procedure LogReceived(const ALine: string);
    procedure LogError(const ALine: string);
    // Called when the controller detects the machine finished its queued
    // work (Idle/buffer empty) so a WAIT queue-item can be released.
    procedure NotifyIdleBufferEmpty;
    // sio_status: True right after a '?' status query was sent, so the next
    // '<...>' line is treated as the status reply rather than raw chatter
    // (Sender.py/GRBL0.py: master.sio_status).
    procedure SetSioStatus(AValue: Boolean);
    function SioStatus: Boolean;
    // sio_wait: True while waiting for the machine to go Idle with an empty
    // buffer (a queued WAIT item) - see NotifyIdleBufferEmpty.
    function SioWait: Boolean;
    // Called by a controller's ParseBracketSquare when it parses a [PRB:...]
    // probe-result report, so a probing wizard (uprobe.pas) can record the
    // point without protocol units needing to know about probing at all.
    procedure NotifyProbeResult(AX, AY, AZ: Double);
  end;

  { TGenericController mirrors _GenericController.py + _GenericGRBL.py:
    default (mostly no-op) implementations of controller commands, and the
    parseLine() dispatcher that all concrete controllers share. }
  TGenericController = class
  protected
    FHost: IControllerHost;
    FGCodeCase: Integer;   // 0 = as-is, 1 = uppercase, -1 = lowercase
    FHasOverride: Boolean; // GRBL1 has native realtime override commands
  public
    constructor Create(AHost: IControllerHost);

    property GCodeCase: Integer read FGCodeCase;
    property HasOverride: Boolean read FHasOverride;

    // Commands (_GenericController.py)
    procedure Jog(const ADirection: string); virtual;
    procedure GotoXYZ(HasX, HasY, HasZ: Boolean; X, Y, Z: Double); virtual;
    procedure FeedHold; virtual;
    procedure Resume; virtual;
    procedure SoftReset(ClearAlarm: Boolean = True); virtual;
    procedure Unlock(ClearAlarm: Boolean = True); virtual;
    procedure Home; virtual;
    procedure ViewStatusReport; virtual;
    procedure ViewParameters; virtual;
    procedure ViewState; virtual;
    procedure OverrideSet; virtual; // no-op unless HasOverride

    // Status text -> CNC.vars['state'], with alarm-suppression logic
    // (_GenericController.py displayState()).
    procedure DisplayState(AState: string); virtual;

    // Error/alarm code -> human description (_GenericGRBL.py ERROR_CODES).
    function ErrorDescription(const ACode: string): string; virtual;

    // Dispatch one received line, mirrors _GenericController.py parseLine().
    // Returns True if the line was recognized/handled (either applied to
    // state, or intentionally ignored), False if the caller should just
    // log it raw. AQueue is the in-flight FIFO to pop on ok/error - a
    // single TLineFifo doing the job of bCNC's parallel cline (lengths)
    // and sline (line text) lists, since each entry here already carries
    // both.
    function ParseLine(const ALine: string; AQueue: TLineFifo): Boolean; virtual;

    // Controller-specific status/parameter report parsers.
    procedure ParseBracketAngle(const ALine: string; ACLine: TLineFifo); virtual; abstract;
    procedure ParseBracketSquare(const ALine: string); virtual; abstract;
  end;

implementation

function TryParseSettingLine(const ALine: string; out AID, AValue: string): Boolean;
var
  eqPos, i: Integer;
begin
  Result := False;
  if (Length(ALine) < 3) or (ALine[1] <> '$') then Exit;
  eqPos := Pos('=', ALine);
  if eqPos < 3 then Exit; // need at least "$N="
  AID := Copy(ALine, 2, eqPos - 2);
  for i := 1 to Length(AID) do
    if not (AID[i] in ['0'..'9']) then Exit; // setting IDs are purely numeric
  AValue := Copy(ALine, eqPos + 1, Length(ALine) - eqPos);
  Result := True;
end;

{ TLineFifo }

procedure TLineFifo.Push(const ALine: string);
begin
  SetLength(FLengths, FCount + 1);
  SetLength(FLines, FCount + 1);
  FLengths[FCount] := Length(ALine);
  FLines[FCount] := ALine;
  Inc(FCount);
end;

procedure TLineFifo.PopFront;
var
  i: Integer;
begin
  if FCount = 0 then Exit;
  for i := 0 to FCount - 2 do
  begin
    FLengths[i] := FLengths[i + 1];
    FLines[i] := FLines[i + 1];
  end;
  Dec(FCount);
  SetLength(FLengths, FCount);
  SetLength(FLines, FCount);
end;

procedure TLineFifo.Clear;
begin
  FCount := 0;
  SetLength(FLengths, 0);
  SetLength(FLines, 0);
end;

function TLineFifo.Count: Integer;
begin
  Result := FCount;
end;

function TLineFifo.SumLengths: Integer;
var
  i, s: Integer;
begin
  s := 0;
  for i := 0 to FCount - 1 do
    s := s + FLengths[i];
  Result := s;
end;

function TLineFifo.FrontLine: string;
begin
  if FCount = 0 then
    Result := ''
  else
    Result := FLines[0];
end;

{ TGenericController }

constructor TGenericController.Create(AHost: IControllerHost);
begin
  inherited Create;
  FHost := AHost;
  FGCodeCase := 0;
  FHasOverride := False;
end;

procedure TGenericController.Jog(const ADirection: string);
begin
  // _GenericController.py jog(): G91 G0<dir> then back to G90
  FHost.SendGCode('G91G0' + ADirection);
  FHost.SendGCode('G90');
end;

procedure TGenericController.GotoXYZ(HasX, HasY, HasZ: Boolean; X, Y, Z: Double);
var
  cmd: string;
begin
  cmd := 'G90G0';
  if HasX then cmd := cmd + 'X' + FloatToStr(X);
  if HasY then cmd := cmd + 'Y' + FloatToStr(Y);
  if HasZ then cmd := cmd + 'Z' + FloatToStr(Z);
  FHost.SendGCode(cmd);
end;

procedure TGenericController.FeedHold;
begin
  FHost.SerialWriteRaw('!');
end;

procedure TGenericController.Resume;
begin
  FHost.SerialWriteRaw('~');
  FHost.State.Msg := '';
end;

procedure TGenericController.SoftReset(ClearAlarm: Boolean);
begin
  FHost.SerialWriteRaw(#$18); // Ctrl-X
  FHost.State.OvChanged := True; // force a feed override resync if any
end;

procedure TGenericController.Unlock(ClearAlarm: Boolean);
begin
  FHost.SendGCode('$X');
end;

procedure TGenericController.Home;
begin
  FHost.SendGCode('$H');
end;

procedure TGenericController.ViewStatusReport;
begin
  FHost.SerialWriteRaw('?');
  FHost.SetSioStatus(True);
end;

procedure TGenericController.ViewParameters;
begin
  FHost.SendGCode('$#');
end;

procedure TGenericController.ViewState;
begin
  FHost.SendGCode('$G');
end;

procedure TGenericController.OverrideSet;
begin
  // no-op by default; GRBL1 overrides this (see ugrbl1.pas)
end;

procedure TGenericController.DisplayState(AState: string);
begin
  AState := Trim(AState);

  // Do not show g-code errors when machine is already in alarm state
  if (Pos('ALARM:', FHost.State.StateStr) = 1) and (Pos('error:', AState) = 1) then
    Exit;

  // Do not show alarm without number when we already display alarm w/ number
  if (AState = 'Alarm') and (Pos('ALARM:', FHost.State.StateStr) = 1) then
    Exit;

  FHost.State.StateStr := AState;
end;

function TGenericController.ErrorDescription(const ACode: string): string;
begin
  Result := ACode; // overridden with the full table in ugenericgrbl.pas
end;

function TGenericController.ParseLine(const ALine: string; AQueue: TLineFifo): Boolean;
var
  parts: TStringArray;
  settingId, settingVal: string;
  vendor: TLaserVendorKind;
begin
  Result := True;
  if ALine = '' then Exit;

  // Laser-fork vendor sniffing (plan Phase 4): purely additive - checked
  // on every line regardless of which branch below actually handles it,
  // so it never changes what the rest of ParseLine does with the line.
  // Most lines naturally aren't a vendor welcome/model message, so
  // lvGeneric (no match) is the common case and is deliberately ignored
  // rather than resetting BoardInfo.LaserVendor back to generic.
  vendor := SniffVendor(ALine);
  if vendor <> lvGeneric then
    FHost.State.BoardInfo.LaserVendor := vendor;

  if ALine[1] = '<' then
  begin
    if not FHost.SioStatus then
      FHost.LogReceived(ALine)
    else
      ParseBracketAngle(ALine, AQueue);
  end
  else if ALine[1] = '[' then
  begin
    FHost.LogReceived(ALine);
    ParseBracketSquare(ALine);
  end
  else if (Pos('error:', ALine) > 0) or (Pos('ALARM:', ALine) > 0) then
  begin
    FHost.LogError(ALine);
    if AQueue.Count > 0 then
    begin
      FHost.State.ErrLine := AQueue.FrontLine;
      AQueue.PopFront;
    end;
    DisplayState(ALine);
    if FHost.State.Running then
      FHost.State.Running := False; // caller (usender) also sets its own _stop
  end
  else if Pos('ok', ALine) > 0 then
  begin
    if AQueue.Count > 0 then AQueue.PopFront;
  end
  else if ALine[1] = '$' then
  begin
    FHost.LogReceived(ALine);
    if TryParseSettingLine(ALine, settingId, settingVal) then
    begin
      FHost.State.Settings.Values[settingId] := settingVal;
      // $32=1 is grbl's own laser-mode setting - the real, authoritative
      // signal (not a guess) that this specific board currently has laser
      // mode enabled, only known once the $$ grid has actually been
      // fetched (see plan Phase 4 / uappconfig's existing $$ flow).
      if settingId = '32' then
        FHost.State.BoardInfo.SupportLaserMode := (settingVal = '1');
    end;
  end
  else if (Copy(ALine, 1, 4) = 'Grbl') or (Copy(ALine, 1, 13) = 'CarbideMotion') then
  begin
    FHost.LogReceived(ALine);
    AQueue.Clear;
    parts := ALine.Split(' ');
    if Length(parts) > 1 then
      FHost.State.Version := parts[1];
    // Fresh connection/reset - stale board info (from a possibly different
    // board on a prior connection) no longer applies; re-detect via $I.
    FHost.State.BoardInfo.Reset;
    FHost.SendGCode('$I');
  end
  else
    Result := False;
end;

end.
