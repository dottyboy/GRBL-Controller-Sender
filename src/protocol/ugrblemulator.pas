unit ugrblemulator;

{ ugrblemulator: fake GRBL 1.1 serial backend (plan Phase 19) - the standing
  regression harness for Phases 1-18, letting a full connect / status-poll /
  queued-streaming / laser-job cycle run to completion with no real
  hardware attached.

  Design: usender.pas's TSenderThread issues writes (WriteRaw for realtime
  bytes, WriteLine for queued g-code) and reads (ReadLine) from the SAME
  thread, sequentially, once per loop iteration - so this emulator models a
  real serial link's asynchronous replies with one internal FIFO of pending
  reply lines: every Write call enqueues whatever a real board would
  eventually send back, and ReadLine just pops the oldest one. This is
  deliberately NOT a byte-timing-accurate simulation (out of scope for a
  [medium]-tier phase, and the plan's own "Done" bar is just "a laser job
  runs to completion against it") - it is a protocol-shape-accurate fake,
  faithful enough that the REAL TGRBL1Controller/TGenericController parsing
  code (ugrbl1.pas/ugenericcontroller.pas) exercises its real branches
  end-to-end: welcome-banner detection, $I build-info, ok/error FIFO
  bookkeeping, and pipe-delimited <State|MPos:..|FS:..|Bf:..> status
  reports.

  Only matches GRBL1's own wire dialect (pipe-delimited status, "[VER:..]"
  build-info tags) - disclosed, deliberate: GRBL0/Smoothie/G2Core each have
  their own different real status-line formats in this codebase's other
  controller units, and faking all four would be needless duplication for
  a regression harness whose whole point is exercising the send/ack/parse
  pipeline, not re-proving every controller's own already-tested parser. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

const
  // Sentinel "device name" uconnectframe.pas/userial.pas recognize to mean
  // "use the emulator, not a real TLazSerial port".
  EMULATOR_DEVICE_NAME = 'Emulator';
  EMULATOR_RX_BUFFER_SIZE = 128; // mirrors usender.pas's own RX_BUFFER_SIZE

type
  { TGrblEmulator }
  TGrblEmulator = class
  private
    FReplies: TStringList;      // pending reply lines, FIFO order
    FState: string;             // 'Idle' | 'Run' | 'Hold'
    FMX, FMY, FMZ: Double;      // fake machine position - not a real g-code
                                 // interpreter, just tracks the last X/Y/Z
                                 // word seen on any line, enough to make
                                 // status reports look plausible.
    FIdleCountdown: Integer;    // status polls left before Run settles to Idle
    FDropNextAck: Boolean;      // SimulateDroppedAck's one-shot flag
    // RX-buffer-usage bookkeeping (real, not cosmetic - see the header
    // comment's "Bf: free bytes" note): FPendingAckLens holds one entry
    // per line whose "ok" has been ENQUEUED into FReplies but not yet
    // actually READ by the caller - i.e. exactly the same "sent but not
    // yet acknowledged from the reader's point of view" quantity as
    // usender.pas's own FQueueInternal.SumLengths. A status report must
    // report free space as EMULATOR_RX_BUFFER_SIZE minus the SUM of this
    // list, not a constant "always fully free" - reporting a constant
    // full-free value here was a real bug found via live testing: it
    // made usender.pas's own buffer-stuck watchdog fire on pure FIFO-
    // ordering coincidences (a status reply reporting "128 free" read
    // before an already-enqueued-but-not-yet-read "ok" for a still-
    // in-flight line), a false positive with no real dropped ok at all.
    FPendingAckLens: array of Integer;
    FBytesReserved: Integer;
    procedure Reply(const ALine: string);
    procedure ReplyOk(ALineLen: Integer);
    procedure HandleLine(const ALine: string);
  public
    constructor Create;
    destructor Destroy; override;

    // Seeds the real Grbl welcome banner, exactly what a real board sends
    // on power-up/reset - TGenericController.ParseLine's own 'Grbl' branch
    // fires on this, triggering the app's real $I build-info flow.
    procedure Reset;

    // Mirrors TSerialLink's own real API shape 1:1 so userial.pas can
    // forward to this with no adaptation layer.
    procedure WriteRaw(const AData: string);
    procedure WriteLine(const ALine: string);
    function ReadLine: string; // '' if nothing pending right now

    // Test hook for this phase's own "incl. buffer behavior for Phase 3
    // testing" note: the NEXT queued g-code line is accepted and applied
    // (fake position updates etc) but its "ok" reply is silently withheld -
    // a real dropped-ok electrical-noise event - so Phase 3's buffer-stuck
    // watchdog recovery path can be exercised against this harness on
    // demand instead of only in theory.
    procedure SimulateDroppedAck;
  end;

implementation

function ExtractCoord(const ALine: string; AAxis: Char; ACurrent: Double): Double;
var
  i, numStart: Integer;
begin
  Result := ACurrent;
  i := 1;
  while i <= Length(ALine) do
  begin
    if UpCase(ALine[i]) = AAxis then
    begin
      numStart := i + 1;
      i := numStart;
      if (i <= Length(ALine)) and (ALine[i] = '-') then Inc(i);
      while (i <= Length(ALine)) and (ALine[i] in ['0'..'9', '.']) do Inc(i);
      if i > numStart then
      begin
        Result := StrToFloatDef(Copy(ALine, numStart, i - numStart), ACurrent);
        Exit;
      end;
    end
    else
      Inc(i);
  end;
end;

{ TGrblEmulator }

constructor TGrblEmulator.Create;
begin
  inherited Create;
  FReplies := TStringList.Create;
  Reset;
end;

destructor TGrblEmulator.Destroy;
begin
  FReplies.Free;
  inherited Destroy;
end;

procedure TGrblEmulator.Reply(const ALine: string);
begin
  FReplies.Add(ALine);
end;

procedure TGrblEmulator.ReplyOk(ALineLen: Integer);
begin
  SetLength(FPendingAckLens, Length(FPendingAckLens) + 1);
  FPendingAckLens[High(FPendingAckLens)] := ALineLen;
  Inc(FBytesReserved, ALineLen);
  Reply('ok');
end;

procedure TGrblEmulator.Reset;
begin
  FReplies.Clear;
  FState := 'Idle';
  FMX := 0; FMY := 0; FMZ := 0;
  FIdleCountdown := 0;
  FDropNextAck := False;
  SetLength(FPendingAckLens, 0);
  FBytesReserved := 0;
  Reply('Grbl 1.1h [''$'' for help]');
end;

procedure TGrblEmulator.SimulateDroppedAck;
begin
  FDropNextAck := True;
end;

procedure TGrblEmulator.HandleLine(const ALine: string);
var
  line: string;
begin
  line := Trim(ALine);
  if line = '' then Exit;

  if line = '$I' then
  begin
    Reply('[VER:1.1h.20190825:]');
    Reply('[OPT:VNMS,15,128]');
    ReplyOk(Length(ALine));
    Exit;
  end;

  if (line = '$X') or (line = '$H') then
  begin
    if line = '$H' then
    begin
      FMX := 0; FMY := 0; FMZ := 0;
    end;
    FState := 'Idle';
    ReplyOk(Length(ALine));
    Exit;
  end;

  if line = '$$' then
  begin
    // A small, plausible subset of real grbl 1.1 settings - not the full
    // ~30-row dump (out of scope for this phase's own Done bar), but
    // real enough to exercise the app's own $$ grid AND, critically,
    // $32=1 (grbl's real laser-mode flag) so a laser job can actually be
    // run against this harness end-to-end via the normal Laser Control
    // tab, not just plain g-code streaming.
    Reply('$0=10');
    Reply('$32=1');
    Reply('$130=200.000');
    Reply('$131=200.000');
    ReplyOk(Length(ALine));
    Exit;
  end;

  if (line = '$#') or (line = '$G') or (line = '$ES') then
  begin
    // Not modeled in detail - just ack cleanly so a caller that happens to
    // send one of these doesn't stall waiting for a reply that will never
    // come.
    ReplyOk(Length(ALine));
    Exit;
  end;

  // Fake motion tracking: no real feed-rate/time simulation - execution is
  // treated as instantaneous, since this phase's Done bar is the send/ack/
  // parse pipeline, not motion-timing fidelity. Any line mentioning an
  // X/Y/Z word (G0/G1/G28/a bare coordinate continuation line) nudges the
  // fake position so status reports look plausible during a real job.
  FMX := ExtractCoord(line, 'X', FMX);
  FMY := ExtractCoord(line, 'Y', FMY);
  FMZ := ExtractCoord(line, 'Z', FMZ);

  if FDropNextAck then
  begin
    FDropNextAck := False;
    Exit; // deliberately no reply at all - simulated dropped ok
  end;

  ReplyOk(Length(ALine));
  // Report 'Run' for the next couple of status polls before settling back
  // to 'Idle' - gives a real, visible Idle->Run->Idle transition during a
  // streamed job (checked live - see this phase's memory writeup) without
  // needing a second thread/timer to simulate real execution time.
  FState := 'Run';
  FIdleCountdown := 2;
end;

procedure TGrblEmulator.WriteRaw(const AData: string);
var
  i: Integer;
begin
  for i := 1 to Length(AData) do
  begin
    case AData[i] of
      '?':
        begin
          if FIdleCountdown > 0 then
          begin
            Dec(FIdleCountdown);
            if FIdleCountdown = 0 then FState := 'Idle';
          end;
          Reply(Format('<%s|MPos:%.3f,%.3f,%.3f|FS:0,0|Bf:15,%d>',
            [FState, FMX, FMY, FMZ, EMULATOR_RX_BUFFER_SIZE - FBytesReserved]));
        end;
      '!': FState := 'Hold';
      '~': if FState = 'Hold' then FState := 'Idle';
      #$18: Reset; // Ctrl-X soft reset
      // Realtime override bytes (0x85 jog-cancel, 0x90-0x9D feed/rapid/
      // spindle overrides) - no visible state change needed for this
      // phase's Done bar (a laser job streaming to completion doesn't
      // depend on override bytes doing anything observable here).
    end;
  end;
end;

procedure TGrblEmulator.WriteLine(const ALine: string);
begin
  HandleLine(ALine);
end;

function TGrblEmulator.ReadLine: string;
var
  i: Integer;
begin
  if FReplies.Count = 0 then
  begin
    Result := '';
    Exit;
  end;
  Result := FReplies[0];
  FReplies.Delete(0);
  if (Result = 'ok') and (Length(FPendingAckLens) > 0) then
  begin
    Dec(FBytesReserved, FPendingAckLens[0]);
    for i := 0 to High(FPendingAckLens) - 1 do
      FPendingAckLens[i] := FPendingAckLens[i + 1];
    SetLength(FPendingAckLens, Length(FPendingAckLens) - 1);
  end;
end;

end.
