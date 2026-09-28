unit usender;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, Math,
  ucncstate, ugenericcontroller, ugrbl0, ugrbl1, usmoothie, ug2core, userial,
  uxmodem, ulasercooling, ustatebuilder;

type
  // Laser job progress, for the resume-from-position dialog (plan Phase 5).
  // Deliberately tracks the flat BODY line list only (no header/footer,
  // no pass-repeat expansion) - the same unit ulasersender.pas's
  // ContinueLaserProgramFromLine already resumes from (AProgram.Commands),
  // so "Executed" is directly usable as an index into it. Multi-pass jobs
  // (BuildProgram(APassCount > 1)) resume from the start of the pass the
  // failure happened in, not the exact repeat - a disclosed limitation,
  // not solved here (see the plan file's Phase 5 note).
  TLaserJobProgress = record
    // Points at TSender's own internally-OWNED copy (see BeginLaserJob) -
    // callers hand BeginLaserJob a locally-scoped flattened list in both
    // ulasersender.pas call sites, so this must never alias caller-owned
    // memory that might be freed while a job is still Active.
    BodyLines: TStringList;
    HeaderCount: Integer;    // lines enqueued before BodyLines[0] this run
    Target: Integer;         // BodyLines.Count
    Sent: Integer;           // body lines physically written so far
    Executed: Integer;       // body lines acknowledged (ok/error) so far
    Active: Boolean;
  end;

const
  RX_BUFFER_SIZE = 128;   // Sender.py RX_BUFFER_SIZE
  SERIAL_POLL_MS = 125;   // Sender.py SERIAL_POLL = 0.125s
  SERIAL_TIMEOUT_MS = 100; // Sender.py SERIAL_TIMEOUT = 0.10s
  // Buffer-stuck watchdog: number of CONSECUTIVE status replies that must
  // show the "grbl already freed space we're still counting" mismatch
  // before we trust it enough to fabricate a missing ok - see the comment
  // in TSenderThread.Execute. One stale/racy read shouldn't be enough.
  WATCHDOG_MISMATCH_THRESHOLD = 2;

  // Queue sentinel: mirrors bCNC's own literal "%wait" convention (see
  // Probe.scan() in CNC.py) rather than Sender.py's typed (WAIT,) tuple -
  // TSenderThread special-cases this string at dequeue time instead of
  // pushing it onto the wire, so a probing sequence can force "wait until
  // Idle and buffer-empty" between motion and the next probe command.
  GCODE_WAIT_MARKER = '%wait';

type
  TControllerKind = (ckGRBL0, ckGRBL1, ckSmoothie, ckG2Core);

  TSenderLogEvent = procedure(Sender: TObject; const ALine: string; IsError: Boolean) of object;
  TSenderNotifyEvent = procedure(Sender: TObject) of object;
  TProbeResultEvent = procedure(Sender: TObject; AX, AY, AZ: Double) of object;

  { TSafeStringQueue: minimal thread-safe FIFO of pending g-code lines,
    mirrors Sender.py's self.queue (a stdlib Queue). Pushed to from the
    main thread (UI actions), popped from the worker thread. }
  TSafeStringQueue = class
  private
    FList: TStringList;
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Push(const ALine: string);
    function Dequeue(out ALine: string): Boolean;
    procedure Clear;
    function Count: Integer;
  end;

  TSender = class; // fwd

  { TSenderThread mirrors Sender.py's serialIO(): a single dedicated thread
    that owns BOTH reading and writing the serial port and all protocol
    bookkeeping (cline/sline FIFO, status polling), exactly like bCNC's own
    Python thread - see the long comment in userial.pas for why this must
    stay single-threaded rather than mixing in TLazSerial's async
    OnRxData/Synchronize convenience path. }
  TSenderThread = class(TThread)
  private
    FSender: TSender;
  protected
    procedure Execute; override;
  public
    constructor Create(ASender: TSender);
  end;

  { TSender is the "master" from bCNC's Sender.py: owns the serial link, the
    CNC state, the active controller, the pending-line queue, and the
    worker thread. Implements IControllerHost so controller units can call
    back without depending on this unit (breaking what would otherwise be
    a circular dependency). Deliberately NOT reference-counted (manual
    QueryInterface/_AddRef/_Release) so it can be owned/freed explicitly by
    a form, like any normal TObject - see the note above those methods. }
  TSender = class(TObject, IControllerHost)
  private
    FState: TCNCState;
    FSerialLink: TSerialLink;
    FController: TGenericController;
    FThread: TSenderThread;
    FQueue: TSafeStringQueue;
    FQueueInternal: TLineFifo; // worker-thread-owned cline+sline FIFO
    FSioStatusFlag: Boolean;
    FSioWaitFlag: Boolean;
    FPaused: Boolean;
    FStopRequested: Boolean;
    // Laser mode: while True, every abort path (StopStreaming, below, via
    // TSenderThread.Execute's FStopRequested handling) force-enqueues M5
    // right after clearing the queue - guarantees the laser is off no
    // matter which abort path triggered it. Set/cleared by the laser
    // module (ulasersender.pas); False (the default) leaves ordinary
    // milling/routing jobs completely unaffected.
    FIsLaserMode: Boolean;
    // Plan Phase 5: progress counters for the resume-from-position dialog.
    // Reset by BeginLaserJob (called from ulasersender.pas's
    // RunLaserProgram/ContinueLaserProgramFromLine right after enqueueing),
    // advanced additively in TSenderThread.Execute - see the comments
    // there for exactly how "sent"/"executed" are measured without
    // requiring TSafeStringQueue itself to know about laser jobs at all.
    FLaserJob: TLaserJobProgress;
    // Raw counters, mutated only by TSenderThread.Execute (see there for how
    // "sent"/"acked" are measured), read (without a lock, matching this
    // unit's existing convention for FPaused/FSioWaitFlag/FStopRequested)
    // by LaserJobProgress to compute the body-relative Sent/Executed -
    // count everything physically written/acked since BeginLaserJob, which
    // includes the run's header lines, so the body-relative value is this
    // minus HeaderCount, clamped to [0, Target].
    FLaserRawSent: Integer;
    FLaserRawAcked: Integer;
    // Owned copies backing FLaserJob.BodyLines / the resume footer - see
    // BeginLaserJob. Footer is tracked separately (not part of
    // TLaserJobProgress, which the resume dialog only needs Body/Target
    // from) purely so ResumeLaserJob can re-append it without requiring
    // the caller to still have the original TLaserProgram around.
    FLaserBodyLinesOwned: TStringList;
    FLaserFooterLinesOwned: TStringList;
    // Auto-cooling (plan Phase 7): a duty-cycle pulse-cooling timer, only
    // ticked (see TSenderThread.Execute) while FIsLaserMode AND
    // FState.BoardInfo.SupportAutoCooling. Created unconditionally in
    // Create/Destroy - the gating happens at the call site, not here.
    FCoolingCycle: TCoolingCycle;
    // Plan Phase 9: per-job user toggle (the Laser Control tab's "Auto-
    // cooling" checkbox) - the underlying TCoolingCycle always exists
    // (created unconditionally, see Create), this just gates whether
    // TSenderThread.Execute ticks it for real. Defaults True so an
    // untouched checkbox (or any pre-Phase-9 code path) keeps today's
    // existing behavior - a supported board always cooled.
    FCoolingEnabled: Boolean;
    // Phase G: True while uxmodem.pas is doing a synchronous, exclusive
    // XMODEM exchange on the calling thread - TSenderThread.Execute skips
    // its own reads/writes of FSerialLink entirely while this is set, so
    // the two never race on the same underlying port (see the "Only ONE
    // thread may call ReadLine/WriteRaw/..." note in userial.pas).
    FTransferActive: Boolean;
    FGCount: Integer;

    // Worker-thread-owned staging buffer, flushed to the UI via Synchronize
    // in FlushToUI (called from TSenderThread after each processed line).
    FPendingLog: TStringList;
    FPendingLogIsError: TStringList; // parallel booleans as '0'/'1' strings

    FOnLog: TSenderLogEvent;
    FOnStateChanged: TSenderNotifyEvent;
    FOnProbeResult: TProbeResultEvent;
    FPendingProbeX, FPendingProbeY, FPendingProbeZ: Double;
    FHasPendingProbe: Boolean;

    procedure FlushToUI;
  public
    constructor Create;
    destructor Destroy; override;

    // IControllerHost
    procedure SendGCode(const ALine: string);
    procedure SerialWriteRaw(const AData: string);
    function State: TCNCState;
    procedure LogReceived(const ALine: string);
    procedure LogError(const ALine: string);
    procedure NotifyIdleBufferEmpty;
    procedure SetSioStatus(AValue: Boolean);
    function SioStatus: Boolean;
    function SioWait: Boolean;
    procedure NotifyProbeResult(AX, AY, AZ: Double);

    // Non-refcounted interface plumbing (see class comment above). Must
    // match System.IUnknown's calling convention exactly: cdecl on
    // non-Windows platforms, stdcall on Windows (objpash.inc).
    function QueryInterface({$IFDEF FPC_HAS_CONSTREF}constref{$ELSE}const{$ENDIF} IID: TGUID; out Obj): LongInt; {$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
    function _AddRef: LongInt; {$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
    function _Release: LongInt; {$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};

    procedure Connect(const ADevice: string; ABaud: Integer; AKind: TControllerKind);
    procedure Disconnect;
    function Connected: Boolean;

    // High-level actions, delegate to the active controller (Jog/Home/...)
    // or push straight onto the send queue (EnqueueGCode). Safe to call
    // from the main/UI thread.
    procedure EnqueueGCode(const ALine: string);
    procedure EnqueueLines(ALines: TStrings);
    procedure EnqueueWait;
    procedure Jog(const ADirection: string);
    procedure JogCancel;
    procedure Home;
    procedure Unlock;
    procedure FeedHold;
    procedure Resume;
    procedure SoftReset;
    procedure StopStreaming;
    // Phase F: universal $$ settings grid - RequestSettings re-sends $$ (the
    // dump populates FState.Settings line-by-line as it arrives, parsed in
    // ugenericcontroller.pas's ParseLine); WriteSetting sends one $N=value.
    procedure RequestSettings;
    procedure WriteSetting(const AID, AValue: string);
    // Phase F2: grblHAL's $ES ("enumerate settings") - populates
    // FState.SettingsMeta the same way RequestSettings populates
    // FState.Settings. No-op (silently ignored by the board) on firmware
    // that doesn't implement $ES.
    procedure RequestSettingsDetails;

    // Phase G: FluidNC config.yaml transfer. Runs synchronously on the
    // calling thread (blocking the UI for the transfer's duration - fine
    // for a config.yaml-sized file, see the plan file's Phase G note) and
    // pauses the worker thread's own port access for that duration.
    function UploadFile(const ABoardFileName: string; const AData: TBytes): Boolean;
    function DownloadFile(const ABoardFileName: string; out AData: TBytes): Boolean;

    // Plan Phase 5: called right after a laser job's lines have been
    // pushed onto the queue, so progress tracking restarts cleanly for
    // this run. ABodyLines/AFooterLines are COPIED (Assign) - the caller's
    // own list can be freed right after this call returns.
    procedure BeginLaserJob(ABodyLines, AFooterLines: TStringList; AHeaderCount: Integer);
    procedure EndLaserJob;
    function LaserJobProgress: TLaserJobProgress;
    // Resumes the CURRENTLY TRACKED job (FLaserJob, as set up by the last
    // BeginLaserJob call) from AFromLine onward, via ustatebuilder.pas's
    // state replay - the crash-recovery entry point umain.pas's
    // SenderStateChanged hook calls after TResumeJobForm returns, and what
    // ulasersender.pas's ContinueLaserProgramFromLine delegates to for an
    // explicit "resume a loaded file" action. No-op if no job is Active.
    procedure ResumeLaserJob(AFromLine: Integer; const AOpts: TResumeOptions);

    property Controller: TGenericController read FController;
    property IsLaserMode: Boolean read FIsLaserMode write FIsLaserMode;
    property CoolingCycle: TCoolingCycle read FCoolingCycle;
    property CoolingEnabled: Boolean read FCoolingEnabled write FCoolingEnabled;
    property OnLog: TSenderLogEvent read FOnLog write FOnLog;
    property OnStateChanged: TSenderNotifyEvent read FOnStateChanged write FOnStateChanged;
    property OnProbeResult: TProbeResultEvent read FOnProbeResult write FOnProbeResult;
  end;

implementation

{ TSafeStringQueue }

constructor TSafeStringQueue.Create;
begin
  inherited Create;
  FList := TStringList.Create;
  FLock := TCriticalSection.Create;
end;

destructor TSafeStringQueue.Destroy;
begin
  FLock.Free;
  FList.Free;
  inherited Destroy;
end;

procedure TSafeStringQueue.Push(const ALine: string);
begin
  FLock.Enter;
  try
    FList.Add(ALine);
  finally
    FLock.Leave;
  end;
end;

function TSafeStringQueue.Dequeue(out ALine: string): Boolean;
begin
  FLock.Enter;
  try
    Result := FList.Count > 0;
    if Result then
    begin
      ALine := FList[0];
      FList.Delete(0);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TSafeStringQueue.Clear;
begin
  FLock.Enter;
  try
    FList.Clear;
  finally
    FLock.Leave;
  end;
end;

function TSafeStringQueue.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FList.Count;
  finally
    FLock.Leave;
  end;
end;

{ TSenderThread }

constructor TSenderThread.Create(ASender: TSender);
begin
  FSender := ASender;
  inherited Create(False); // start running immediately
end;

procedure TSenderThread.Execute;
var
  tr, t: QWord;
  tosend: string;
  hasTosend: Boolean;
  line: string;
  watchdogMismatch: Integer;
  queueCountBefore, acked: Integer;
begin
  tr := GetTickCount64;
  tosend := '';
  hasTosend := False;
  watchdogMismatch := 0;

  while not Terminated do
  begin
    if FSender.FTransferActive then
    begin
      Sleep(20);
      Continue;
    end;

    t := GetTickCount64;

    // Periodic status poll (Sender.py: `?` + optional override resync)
    if t - tr > SERIAL_POLL_MS then
    begin
      FSender.FController.ViewStatusReport;
      tr := t;
      if FSender.FState.OvChanged then
        FSender.FController.OverrideSet;
    end;

    // Fetch a new line to send, if we don't already have one pending -
    // pre-count it into the FIFO immediately (before it is physically
    // written), matching Sender.py's cline.append(len(tosend)) happening
    // right after dequeue, not right before serial_write().
    if (not hasTosend) and (not FSender.FSioWaitFlag) and (not FSender.FPaused) then
    begin
      if FSender.FQueue.Dequeue(tosend) then
      begin
        if tosend = GCODE_WAIT_MARKER then
        begin
          // Don't queue/send - just start waiting for Idle+empty-buffer,
          // released by NotifyIdleBufferEmpty (see ugrbl0/1.pas). Mirrors
          // bCNC's own "%wait" sentinel (Probe.scan()).
          FSender.FSioWaitFlag := True;
          tosend := '';
        end
        else
        begin
          hasTosend := True;
          FSender.FQueueInternal.Push(tosend);
        end;
      end;
    end;

    // Blocking read with a short timeout - mirrors pyserial readline().
    line := FSender.FSerialLink.ReadLine(SERIAL_TIMEOUT_MS);
    if line <> '' then
    begin
      // Laser job progress (plan Phase 5): every 'ok'/error response pops
      // exactly one entry off FQueueInternal (ugenericcontroller.pas's
      // ParseLine), so a drop in Count here means one more line - whatever
      // it was - just got acknowledged. Purely additive/observational, does
      // not change what ParseLine itself does with the line.
      queueCountBefore := FSender.FQueueInternal.Count;
      if not FSender.FController.ParseLine(line, FSender.FQueueInternal) then
        FSender.LogReceived(line);
      if FSender.FIsLaserMode and FSender.FLaserJob.Active then
      begin
        acked := queueCountBefore - FSender.FQueueInternal.Count;
        if acked > 0 then Inc(FSender.FLaserRawAcked, acked);
      end;
      Synchronize(@FSender.FlushToUI);
    end;

    // Buffer-stuck watchdog (GRBL1 only - other controllers here don't
    // reliably report Bf: free-buffer bytes). Normally, grbl's own
    // reported free RX-buffer bytes (RxBytes, from the last Bf: status
    // field) plus our own in-flight byte count (SumLengths, bytes we've
    // sent but have no "ok" for yet) should never exceed RX_BUFFER_SIZE -
    // together they describe the same 128-byte buffer from two sides. If
    // the sum EXCEEDS it, grbl has already freed room for a line we're
    // still holding onto, meaning it silently dropped that line's "ok"
    // (electrical noise on RX is the usual real-world cause). Only acted
    // on after WATCHDOG_MISMATCH_THRESHOLD consecutive status replies
    // agree, to avoid reacting to one stale/racy read.
    //
    // Deliberately gated on THIS iteration having just read a fresh
    // '<...>' status line - not evaluated on every loop tick regardless
    // (a real, latent bug found via Phase 19's own emulator harness,
    // pre-dating it: evaluating unconditionally compares a STALE RxBytes
    // - left over from a status reply read before some earlier multi-line
    // response, e.g. a "$$" settings dump, even started - against a
    // SumLengths that's merely elevated because that response's own
    // several-lines-then-ok hasn't fully arrived yet, several iterations
    // later. That's not a dropped ok, just a multi-line reply still in
    // flight, but it could hold the mismatch condition true for enough
    // consecutive iterations to cross WATCHDOG_MISMATCH_THRESHOLD on its
    // own - against real hardware too, not just the emulator, since a
    // real "$$" dump is genuinely multiple lines before its own "ok").
    // Recovery mirrors exactly what a real "ok" does
    // (ugenericcontroller.pas ParseLine's 'ok' branch: AQueue.PopFront).
    if (line <> '') and (line[1] = '<') then
    begin
      if (FSender.FState.Controller = 'GRBL1') and (FSender.FQueueInternal.Count > 0) and
         (FSender.FState.RxBytes + FSender.FQueueInternal.SumLengths > RX_BUFFER_SIZE) then
      begin
        Inc(watchdogMismatch);
        if watchdogMismatch >= WATCHDOG_MISMATCH_THRESHOLD then
        begin
          FSender.LogError('[watchdog] recovered a likely dropped ok (buffer mismatch)');
          FSender.FQueueInternal.PopFront;
          Synchronize(@FSender.FlushToUI);
          watchdogMismatch := 0;
        end;
      end
      else
        watchdogMismatch := 0;
    end;

    // Auto-cooling (plan Phase 7): only active while in laser mode AND
    // the connected board is known to support it (BoardInfo.
    // SupportAutoCooling, inferred from controller kind in Connect - see
    // uboardinfo.pas). "Job active" means there's genuinely queued/
    // in-flight g-code and the user hasn't already paused things for an
    // unrelated reason - see ulasercooling.pas's own comment on why this
    // is time-driven rather than StateStr-driven.
    if FSender.FIsLaserMode and FSender.FState.BoardInfo.SupportAutoCooling and
       FSender.FCoolingEnabled then
      FSender.FCoolingCycle.Tick(
        ((FSender.FQueueInternal.Count > 0) or (FSender.FQueue.Count > 0)) and
        not FSender.FPaused)
    else
      FSender.FCoolingCycle.Tick(False);

    if FSender.FStopRequested then
    begin
      FSender.FQueue.Clear;
      hasTosend := False;
      tosend := '';
      FSender.FStopRequested := False;
      // Non-negotiable laser safety property (mirrors LaserGRBL's own
      // AbortProgram): once the queue is cleared, if a laser job was
      // running, M5 is the very next thing sent - regardless of which
      // abort path triggered this (user Stop, a future hang/alarm-driven
      // abort, etc). Pushed onto the same queue rather than written
      // directly so it still goes through normal buffer accounting.
      if FSender.FIsLaserMode then
        FSender.FQueue.Push('M5');
    end;

    // Only physically write once total outstanding bytes (including the
    // line already pre-counted above) stays under GRBL's RX buffer.
    if hasTosend and (FSender.FQueueInternal.SumLengths < RX_BUFFER_SIZE) then
    begin
      FSender.FSerialLink.WriteLine(tosend);
      if FSender.FIsLaserMode and FSender.FLaserJob.Active then
        Inc(FSender.FLaserRawSent);
      hasTosend := False;
      tosend := '';
    end;
  end;
end;

{ TSender }

constructor TSender.Create;
begin
  inherited Create;
  FState := TCNCState.Create;
  FSerialLink := TSerialLink.Create(nil);
  FQueue := TSafeStringQueue.Create;
  FQueueInternal := TLineFifo.Create;
  FPendingLog := TStringList.Create;
  FPendingLogIsError := TStringList.Create;
  FController := TGRBL1Controller.Create(Self as IControllerHost);
  FState.Controller := 'GRBL1';
  FCoolingCycle := TCoolingCycle.Create(@FeedHold, @Resume);
  FCoolingEnabled := True;
  FLaserBodyLinesOwned := TStringList.Create;
  FLaserFooterLinesOwned := TStringList.Create;
end;

destructor TSender.Destroy;
begin
  Disconnect;
  FLaserFooterLinesOwned.Free;
  FLaserBodyLinesOwned.Free;
  FCoolingCycle.Free;
  FController.Free;
  FPendingLogIsError.Free;
  FPendingLog.Free;
  FQueueInternal.Free;
  FQueue.Free;
  FSerialLink.Free;
  FState.Free;
  inherited Destroy;
end;

procedure TSender.FlushToUI;
var
  i: Integer;
begin
  if Assigned(FOnLog) then
    for i := 0 to FPendingLog.Count - 1 do
      FOnLog(Self, FPendingLog[i], FPendingLogIsError[i] = '1');
  FPendingLog.Clear;
  FPendingLogIsError.Clear;

  if FHasPendingProbe then
  begin
    FHasPendingProbe := False;
    if Assigned(FOnProbeResult) then
      FOnProbeResult(Self, FPendingProbeX, FPendingProbeY, FPendingProbeZ);
  end;

  if Assigned(FOnStateChanged) then
    FOnStateChanged(Self);
end;

procedure TSender.SendGCode(const ALine: string);
begin
  FQueue.Push(ALine);
end;

procedure TSender.SerialWriteRaw(const AData: string);
begin
  FSerialLink.WriteRaw(AData);
end;

function TSender.State: TCNCState;
begin
  Result := FState;
end;

procedure TSender.LogReceived(const ALine: string);
begin
  FPendingLog.Add(ALine);
  FPendingLogIsError.Add('0');
end;

procedure TSender.LogError(const ALine: string);
begin
  FPendingLog.Add(ALine);
  FPendingLogIsError.Add('1');
end;

procedure TSender.NotifyIdleBufferEmpty;
begin
  FSioWaitFlag := False;
  Inc(FGCount);
end;

procedure TSender.NotifyProbeResult(AX, AY, AZ: Double);
begin
  // Called from the worker thread (via ParseLine -> ParseBracketSquare);
  // stage it here and let the FlushToUI Synchronize call (already
  // happening once per processed line) deliver it on the main thread.
  FPendingProbeX := AX;
  FPendingProbeY := AY;
  FPendingProbeZ := AZ;
  FHasPendingProbe := True;
end;

procedure TSender.SetSioStatus(AValue: Boolean);
begin
  FSioStatusFlag := AValue;
end;

function TSender.SioStatus: Boolean;
begin
  Result := FSioStatusFlag;
end;

function TSender.SioWait: Boolean;
begin
  Result := FSioWaitFlag;
end;

function TSender.QueryInterface({$IFDEF FPC_HAS_CONSTREF}constref{$ELSE}const{$ENDIF} IID: TGUID; out Obj): LongInt; {$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
begin
  if GetInterface(IID, Obj) then
    Result := 0 // S_OK
  else
    Result := LongInt($80004002); // E_NOINTERFACE
end;

function TSender._AddRef: LongInt; {$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
begin
  Result := -1; // not reference counted - lifetime is owned explicitly
end;

function TSender._Release: LongInt; {$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
begin
  Result := -1;
end;

procedure TSender.Connect(const ADevice: string; ABaud: Integer; AKind: TControllerKind);
begin
  if Connected then Disconnect;

  FreeAndNil(FController);
  case AKind of
    ckGRBL0:    FController := TGRBL0Controller.Create(Self as IControllerHost);
    ckGRBL1:    FController := TGRBL1Controller.Create(Self as IControllerHost);
    ckSmoothie: FController := TSmoothieController.Create(Self as IControllerHost);
    ckG2Core:   FController := TG2CoreController.Create(Self as IControllerHost);
  end;

  FState.Reset;
  case AKind of
    ckGRBL0:    FState.Controller := 'GRBL0';
    ckGRBL1:    FState.Controller := 'GRBL1';
    ckSmoothie: FState.Controller := 'SMOOTHIE';
    ckG2Core:   FState.Controller := 'G2CORE';
  end;
  FState.StateStr := 'Connecting';
  // Laser capability flags inferred from controller kind (plan Phase 4) -
  // this app's GRBL1 controller specifically targets the grbl 1.1
  // protocol (see ugrbl1.pas), the same version line LaserGRBL itself
  // requires for overrides/PWM/auto-cooling; GRBL0 (legacy 0.9x),
  // Smoothie and G2Core don't get them. SupportLaserMode is NOT set here
  // - it depends on the real $32 setting, only known once fetched (see
  // ugenericcontroller.pas's '$' branch).
  FState.BoardInfo.SupportOverride := (AKind = ckGRBL1);
  FState.BoardInfo.SupportPWM := (AKind = ckGRBL1);
  FState.BoardInfo.SupportAutoCooling := (AKind = ckGRBL1);

  FQueueInternal.Clear;
  FQueue.Clear;
  FSioStatusFlag := False;
  FSioWaitFlag := False;
  FPaused := False;
  FStopRequested := False;

  FSerialLink.OpenPort(ADevice, ABaud);
  FThread := TSenderThread.Create(Self);
end;

procedure TSender.Disconnect;
begin
  EndLaserJob; // any in-flight job's progress no longer means anything once
               // the connection (and FQueueInternal's counts) is gone
  if Assigned(FThread) then
  begin
    FThread.Terminate;
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
  FSerialLink.ClosePort;
  FState.StateStr := 'Not connected';
end;

function TSender.Connected: Boolean;
begin
  Result := FSerialLink.IsOpen;
end;

procedure TSender.EnqueueGCode(const ALine: string);
begin
  FQueue.Push(ALine);
end;

procedure TSender.EnqueueLines(ALines: TStrings);
var
  i: Integer;
begin
  for i := 0 to ALines.Count - 1 do
    if Trim(ALines[i]) <> '' then
      FQueue.Push(ALines[i]);
end;

procedure TSender.EnqueueWait;
begin
  FQueue.Push(GCODE_WAIT_MARKER);
end;

procedure TSender.Jog(const ADirection: string);
begin
  FController.Jog(ADirection);
end;

procedure TSender.JogCancel;
begin
  FController.JogCancel;
end;

procedure TSender.Home;
begin
  FController.Home;
end;

procedure TSender.Unlock;
begin
  FController.Unlock;
end;

procedure TSender.FeedHold;
begin
  FController.FeedHold;
  FPaused := True;
end;

procedure TSender.Resume;
begin
  FController.Resume;
  FPaused := False;
end;

procedure TSender.SoftReset;
begin
  FController.SoftReset;
end;

procedure TSender.RequestSettings;
begin
  EnqueueGCode('$$');
end;

procedure TSender.WriteSetting(const AID, AValue: string);
begin
  EnqueueGCode('$' + AID + '=' + AValue);
end;

procedure TSender.RequestSettingsDetails;
begin
  EnqueueGCode('$ES');
end;

function TSender.UploadFile(const ABoardFileName: string; const AData: TBytes): Boolean;
begin
  Result := False;
  if not Connected then Exit;
  FTransferActive := True;
  Sleep(150); // let the worker thread's current blocking read (bounded by
              // SERIAL_TIMEOUT_MS) finish and observe the flag first
  try
    FSerialLink.WriteLine('$XR=' + ABoardFileName);
    Result := XModemSend(FSerialLink, AData);
  finally
    FTransferActive := False;
  end;
end;

function TSender.DownloadFile(const ABoardFileName: string; out AData: TBytes): Boolean;
begin
  Result := False;
  SetLength(AData, 0);
  if not Connected then Exit;
  FTransferActive := True;
  Sleep(150);
  try
    FSerialLink.WriteLine('$XS=' + ABoardFileName);
    Result := XModemReceive(FSerialLink, AData);
  finally
    FTransferActive := False;
  end;
end;

procedure TSender.StopStreaming;
begin
  FStopRequested := True;
end;

procedure TSender.BeginLaserJob(ABodyLines, AFooterLines: TStringList; AHeaderCount: Integer);
begin
  // Assign() copies - safe even if ABodyLines/AFooterLines alias this
  // TSender's OWN owned lists (ResumeLaserJob never does that; see its own
  // comment on why it snapshots the footer first), but is not free to
  // assume otherwise, so the copy happens unconditionally either way.
  FLaserBodyLinesOwned.Assign(ABodyLines);
  FLaserFooterLinesOwned.Assign(AFooterLines);
  FLaserJob.BodyLines := FLaserBodyLinesOwned;
  FLaserJob.HeaderCount := AHeaderCount;
  FLaserJob.Target := FLaserBodyLinesOwned.Count;
  FLaserJob.Sent := 0;
  FLaserJob.Executed := 0;
  FLaserJob.Active := True;
  FLaserRawSent := 0;
  FLaserRawAcked := 0;
end;

procedure TSender.EndLaserJob;
begin
  FLaserJob.Active := False;
  FLaserJob.BodyLines := nil;
  FLaserBodyLinesOwned.Clear;
  FLaserFooterLinesOwned.Clear;
end;

function TSender.LaserJobProgress: TLaserJobProgress;
begin
  Result := FLaserJob;
  if FLaserJob.Active then
  begin
    Result.Sent := EnsureRange(FLaserRawSent - FLaserJob.HeaderCount, 0, FLaserJob.Target);
    Result.Executed := EnsureRange(FLaserRawAcked - FLaserJob.HeaderCount, 0, FLaserJob.Target);
  end;
end;

procedure TSender.ResumeLaserJob(AFromLine: Integer; const AOpts: TResumeOptions);
var
  preambleCount, i, footerCount: Integer;
  resumeLines, newBody, footerCopy: TStringList;
begin
  if not FLaserJob.Active then Exit;

  // Snapshot the footer BEFORE calling BeginLaserJob below (which
  // re-assigns FLaserFooterLinesOwned) - TStrings.Assign(Self) would
  // Clear() the source out from under itself if we passed the live owned
  // list straight through, so a genuinely separate copy is taken first.
  footerCopy := TStringList.Create;
  try
    footerCopy.Assign(FLaserFooterLinesOwned);
    footerCount := footerCopy.Count;

    // FLaserBodyLinesOwned itself is only READ by BuildResumeProgram (never
    // mutated - see ustatebuilder.pas), so it's safe to pass directly here,
    // unlike the footer above.
    resumeLines := BuildResumeProgram(FLaserBodyLinesOwned, AFromLine, AOpts, preambleCount);
    try
      for i := 0 to footerCount - 1 do
        resumeLines.Add(footerCopy[i]);

      // Re-base progress tracking on the TRIMMED remaining body (index 0 =
      // AFromLine of the run that just failed) - mirrors LaserGRBL's own
      // mTP.JobContinue(file, position, ...) re-basing Target at the resume
      // point, not a shortcut.
      newBody := TStringList.Create;
      try
        for i := preambleCount to resumeLines.Count - footerCount - 1 do
          newBody.Add(resumeLines[i]);
        BeginLaserJob(newBody, footerCopy, preambleCount);
      finally
        newBody.Free;
      end;

      IsLaserMode := True;
      EnqueueLines(resumeLines);
    finally
      resumeLines.Free;
    end;
  finally
    footerCopy.Free;
  end;
end;

end.
