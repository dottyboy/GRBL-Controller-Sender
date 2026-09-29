unit usincrostart;

{ usincrostart: multi-instance/external "start the loaded job" trigger
  (plan Phase 22), ported from LaserGRBL's real SincroStart.cs concept but
  onto a genuinely different, Linux-appropriate mechanism - the real
  source uses a Windows-only named `EventWaitHandle` ("LaserGRBL syncro
  event"), a bare, payload-free signal every running instance reacts to
  according to its own current job state:
    if CanSendFile -> RunProgram(null)      (start the already-loaded job)
    elif CanResumeHold -> CycleStartResume  (resume a paused job)
    elif CanFeedHold -> FeedHold            (pause a running job)
  This unit ports that exact 3-way priority (see umain.pas's own
  SincroStartMessageReceived) but replaces the Windows named-event
  mechanism itself with a Unix named FIFO (mkfifo) - the plan's own file
  comment already called for "Unix domain socket/FIFO", and a FIFO is the
  simpler, more portable-across-this-app's-own-Linux-target choice of the
  two (no socket-accept-loop machinery needed).

  Extended scope (plan's own 2nd-wave note, decided before writing any of
  this): unlike the real source's bare/payload-free signal, this FIFO
  carries a small tagged text protocol from the start - "START" (the real
  source's only real behavior), plus "IMPORT_SVG:<path>" and
  "IMPORT_RASTER:<path>" - specifically so the still-unbuilt Phase 27
  (Inkscape extension bridge) and Phase 28 (GIMP plugin bridge) can reuse
  this exact listener as their own delivery mechanism later, instead of
  each inventing a second one. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, BaseUnix, Unix;

const
  SINCROSTART_TAG_START = 'START';
  SINCROSTART_TAG_IMPORT_SVG = 'IMPORT_SVG:';
  SINCROSTART_TAG_IMPORT_RASTER = 'IMPORT_RASTER:';
  // How often the listener thread wakes to check for a stop request while
  // otherwise blocked waiting for a message - keeps StopListening
  // responsive without needing a hacky "open the fifo myself to unblock
  // the reader" trick.
  SINCROSTART_POLL_MS = 200;

type
  TSincroStartKind = (sskStart, sskImportSvg, sskImportRaster);

  TSincroStartMessage = record
    Kind: TSincroStartKind;
    Path: string; // only meaningful for sskImportSvg/sskImportRaster
  end;

  TSincroStartEvent = procedure(const AMsg: TSincroStartMessage) of object;

// TryParseSincroStartMessage: recognizes one line of the tagged protocol.
// Pure/LCL-free, standalone-testable independent of the FIFO plumbing.
function TryParseSincroStartMessage(const ALine: string; out AMsg: TSincroStartMessage): Boolean;

// SendSincroStartMessage: opens AFifoPath for writing and writes ALine
// terminated with a newline - what an external trigger (a shell script,
// `echo "START" > path`, or a future Phase 27/28 bridge plugin) needs to
// do. Returns False if the fifo doesn't exist or nothing is listening
// (a non-blocking open of a reader-less fifo fails immediately with
// ENXIO on Linux, rather than hanging forever).
function SendSincroStartMessage(const AFifoPath, ALine: string): Boolean;

type
  { TSincroStartListener: owns a background thread blocking (with a short
    poll interval, not truly forever, so Stop is responsive) on the given
    FIFO path, Synchronizing each parsed message back to the caller. }
  TSincroStartListener = class
  private
    FThread: TThread;
    FRunning: Boolean;
    FListenerReady: Boolean;
    procedure MarkReady;
  public
    destructor Destroy; override;
    // Creates the FIFO at AFifoPath if it doesn't already exist, and
    // starts listening on it. AOnMessage is called on the MAIN thread
    // (via Synchronize) for every real, successfully-parsed message -
    // an unparseable line is silently ignored (logged nowhere - this
    // mirrors the real source's own total absence of error handling for
    // "somebody signaled something we don't understand").
    procedure StartListening(const AFifoPath: string; AOnMessage: TSincroStartEvent);
    procedure StopListening;
    function Running: Boolean;
  end;

implementation

function TryParseSincroStartMessage(const ALine: string; out AMsg: TSincroStartMessage): Boolean;
var
  line: string;
begin
  Result := False;
  FillChar(AMsg, SizeOf(AMsg), 0);
  line := Trim(ALine);
  if line = '' then Exit;

  if line = SINCROSTART_TAG_START then
  begin
    AMsg.Kind := sskStart;
    Result := True;
    Exit;
  end;
  if Pos(SINCROSTART_TAG_IMPORT_SVG, line) = 1 then
  begin
    AMsg.Kind := sskImportSvg;
    AMsg.Path := Copy(line, Length(SINCROSTART_TAG_IMPORT_SVG) + 1, Length(line));
    Result := AMsg.Path <> '';
    Exit;
  end;
  if Pos(SINCROSTART_TAG_IMPORT_RASTER, line) = 1 then
  begin
    AMsg.Kind := sskImportRaster;
    AMsg.Path := Copy(line, Length(SINCROSTART_TAG_IMPORT_RASTER) + 1, Length(line));
    Result := AMsg.Path <> '';
    Exit;
  end;
end;

function SendSincroStartMessage(const AFifoPath, ALine: string): Boolean;
var
  fd: cInt;
  data: string;
  written: LongInt;
begin
  Result := False;
  fd := FpOpen(AFifoPath, O_WRONLY or O_NONBLOCK);
  if fd < 0 then Exit; // ENXIO (no reader) or ENOENT (no fifo) - either way, no listener
  try
    data := ALine + LineEnding;
    written := FpWrite(fd, data[1], Length(data));
    Result := written = Length(data);
  finally
    FpClose(fd);
  end;
end;

{ TSincroStartThread }

type
  TSincroStartThread = class(TThread)
  private
    FFifoPath: string;
    FOnMessage: TSincroStartEvent;
    FOnReady: TThreadMethod;
    FPendingMsg: TSincroStartMessage;
    FFd: cInt;
    procedure SyncDeliver;
  protected
    procedure Execute; override;
  public
    constructor Create(const AFifoPath: string; AOnMessage: TSincroStartEvent; AOnReady: TThreadMethod);
  end;

constructor TSincroStartThread.Create(const AFifoPath: string; AOnMessage: TSincroStartEvent; AOnReady: TThreadMethod);
begin
  FFifoPath := AFifoPath;
  FOnMessage := AOnMessage;
  FOnReady := AOnReady;
  FFd := -1;
  inherited Create(False);
end;

procedure TSincroStartThread.SyncDeliver;
begin
  if Assigned(FOnMessage) then FOnMessage(FPendingMsg);
end;

procedure TSincroStartThread.Execute;
var
  fds: TFDSet;
  tv: TTimeVal;
  selRes: cInt;
  buf: array[0..1023] of Char;
  n: LongInt;
  lineBuf: string;
  i: Integer;
  msg: TSincroStartMessage;
begin
  // Opened O_RDWR (not O_RDONLY): a FIFO opened purely for reading blocks
  // until some OTHER process opens it for writing, which would make
  // every idle poll-cycle re-block on open itself. O_RDWR is a standard
  // POSIX trick - the fd is simultaneously "the" reader and a permanent
  // (if unused) writer, so opening never blocks and later real writers
  // (SendSincroStartMessage, or anything else) can still send it data.
  FFd := FpOpen(FFifoPath, O_RDWR or O_NONBLOCK);
  if FFd < 0 then Exit; // couldn't open/create - caller's StartListening already ensured the path exists via FpMkFifo, so this is a real, rare failure (permissions etc), nothing more to do
  // StartListening waits (briefly) on this callback - a real race was
  // found and fixed here: a writer's own O_NONBLOCK open fails
  // immediately with ENXIO if no reader has opened the fifo YET, so a
  // caller sending a message right after StartListening returns (before
  // the FpOpen above ever ran) could genuinely lose that first message -
  // caught via a real end-to-end standalone test, not by inspection.
  if Assigned(FOnReady) then FOnReady();

  lineBuf := '';
  while not Terminated do
  begin
    fpFD_ZERO(fds);
    fpFD_SET(FFd, fds);
    tv.tv_sec := 0;
    tv.tv_usec := SINCROSTART_POLL_MS * 1000;
    selRes := fpSelect(FFd + 1, @fds, nil, nil, @tv);
    if Terminated then Break;
    if selRes > 0 then
    begin
      n := FpRead(FFd, buf[0], SizeOf(buf));
      if n > 0 then
      begin
        for i := 0 to n - 1 do
        begin
          if buf[i] in [#10, #13] then
          begin
            if lineBuf <> '' then
            begin
              if TryParseSincroStartMessage(lineBuf, msg) then
              begin
                FPendingMsg := msg;
                Synchronize(@SyncDeliver);
              end;
              lineBuf := '';
            end;
          end
          else
            lineBuf := lineBuf + buf[i];
        end;
      end;
    end;
  end;
  FpClose(FFd);
end;

{ TSincroStartListener }

destructor TSincroStartListener.Destroy;
begin
  StopListening;
  inherited Destroy;
end;

procedure TSincroStartListener.MarkReady;
begin
  FListenerReady := True; // set from the listener thread, polled (not
                           // Synchronize-waited) from here - see
                           // StartListening's own comment on why
end;

procedure TSincroStartListener.StartListening(const AFifoPath: string; AOnMessage: TSincroStartEvent);
var
  waitedMs: Integer;
begin
  if FRunning then Exit;
  ForceDirectories(ExtractFileDir(AFifoPath));
  if not FileExists(AFifoPath) then
    FpMkFifo(AFifoPath, S_IRUSR or S_IWUSR); // owner-only rw - a local trigger channel, not meant to be world-writable
  FListenerReady := False;
  FThread := TSincroStartThread.Create(AFifoPath, AOnMessage, @MarkReady);
  FRunning := True;
  // Wait for the thread to actually finish its own FpOpen before
  // returning - NOT via TThread.Synchronize (this call itself commonly
  // runs ON the main thread, e.g. from FormCreate, which isn't pumping
  // its own message loop yet at that point - Synchronize would deadlock
  // waiting for a pump that can't happen); a short plain poll is safe
  // and correct here since MarkReady only ever flips one Boolean once.
  waitedMs := 0;
  while (not FListenerReady) and (waitedMs < 1000) do
  begin
    Sleep(10);
    Inc(waitedMs, 10);
  end;
end;

procedure TSincroStartListener.StopListening;
begin
  if not FRunning then Exit;
  FThread.Terminate;
  FThread.WaitFor;
  FreeAndNil(FThread);
  FRunning := False;
end;

function TSincroStartListener.Running: Boolean;
begin
  Result := FRunning;
end;

end.
