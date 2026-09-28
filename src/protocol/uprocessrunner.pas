unit uprocessrunner;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process;

type
  TProcessOutputEvent = procedure(Sender: TObject; const ALine: string) of object;
  TProcessDoneEvent = procedure(Sender: TObject; AExitCode: Integer) of object;

  TProcessRunner = class;

  { TProcessRunnerThread: owns the actual TProcess and does the blocking
    pipe-reading, mirroring usender.pas's TSenderThread pattern (one worker
    thread per run, staged output flushed to the UI via Synchronize) - kept
    fully generic/reusable, no GRBL or serial coupling, so Build and Upload
    (and anything else that needs to shell out and stream output) both go
    through the same one unit. }
  TProcessRunnerThread = class(TThread)
  private
    FRunner: TProcessRunner;
  protected
    procedure Execute; override;
  public
    constructor Create(ARunner: TProcessRunner);
  end;

  { TProcessRunner: runs one external command (e.g. `pio run -e <env> -d
    <dir>`) in a worker thread, streaming its stdout+stderr (merged, one
    line per OnOutput call) back to the caller without blocking the UI.
    Not reference-counted - owned/freed explicitly by whoever creates it,
    same convention as TSender. }
  TProcessRunner = class
  private
    FThread: TProcessRunnerThread;
    FExe: string;
    FParams: TStringList;
    FWorkDir: string;
    FPendingLines: TStringList;
    FPendingExitCode: Integer;
    FHasPendingDone: Boolean;
    FOnOutput: TProcessOutputEvent;
    FOnDone: TProcessDoneEvent;
    procedure FlushToUI;
  public
    constructor Create;
    destructor Destroy; override;

    // Starts AExe with AParams in AWorkDir. Does nothing (silently) if a
    // run is already in progress - callers should check IsRunning first if
    // they want to surface that as a UI message instead.
    procedure Run(const AExe: string; AParams: TStrings; const AWorkDir: string);
    function IsRunning: Boolean;

    property OnOutput: TProcessOutputEvent read FOnOutput write FOnOutput;
    property OnDone: TProcessDoneEvent read FOnDone write FOnDone;
  end;

implementation

{ TProcessRunnerThread }

constructor TProcessRunnerThread.Create(ARunner: TProcessRunner);
begin
  FRunner := ARunner;
  inherited Create(False);
  // Deliberately NOT FreeOnTerminate - TProcessRunner always explicitly
  // waits-and-frees (see Run/Destroy below), same discipline as
  // usender.pas's TSenderThread, so there's exactly one owner of the
  // thread object's lifetime at all times.
end;

procedure TProcessRunnerThread.Execute;
var
  proc: TProcess;
  buf: array[0..4095] of Byte;
  bytesRead, i: Integer;
  lineBuf: string;
  exitCode: Integer;

  procedure StageLine(const ALine: string);
  begin
    FRunner.FPendingLines.Add(ALine);
    if FRunner.FPendingLines.Count > 20 then
      TThread.Synchronize(Self, @FRunner.FlushToUI);
  end;

begin
  proc := TProcess.Create(nil);
  lineBuf := '';
  try
    proc.Executable := FRunner.FExe;
    proc.Parameters.Assign(FRunner.FParams);
    if FRunner.FWorkDir <> '' then
      proc.CurrentDirectory := FRunner.FWorkDir;
    proc.Options := [poUsePipes, poStderrToOutPut];
    try
      proc.Execute;
    except
      on E: Exception do
      begin
        StageLine('Failed to start: ' + E.Message);
        TThread.Synchronize(Self, @FRunner.FlushToUI);
        FRunner.FPendingExitCode := -1;
        FRunner.FHasPendingDone := True;
        TThread.Synchronize(Self, @FRunner.FlushToUI);
        Exit;
      end;
    end;

    while proc.Running or (proc.Output.NumBytesAvailable > 0) do
    begin
      if proc.Output.NumBytesAvailable > 0 then
      begin
        bytesRead := proc.Output.Read(buf, SizeOf(buf));
        for i := 0 to bytesRead - 1 do
        begin
          if buf[i] = 10 then
          begin
            StageLine(TrimRight(lineBuf));
            lineBuf := '';
          end
          else if buf[i] <> 13 then
            lineBuf := lineBuf + Chr(buf[i]);
        end;
      end
      else
        Sleep(20);
    end;
    if lineBuf <> '' then StageLine(lineBuf);

    // proc.ExitStatus returns the raw POSIX wait() status word on this
    // platform/FPC version, not the plain exit code (empirically confirmed:
    // a real `exit 7` came back as 1792 = 7 shl 8) - extract the actual
    // code the same way the WEXITSTATUS() C macro does.
    exitCode := (proc.ExitStatus shr 8) and $FF;
    TThread.Synchronize(Self, @FRunner.FlushToUI); // flush any remaining lines first
    FRunner.FPendingExitCode := exitCode;
    FRunner.FHasPendingDone := True;
    TThread.Synchronize(Self, @FRunner.FlushToUI);
  finally
    proc.Free;
  end;
end;

{ TProcessRunner }

constructor TProcessRunner.Create;
begin
  inherited Create;
  FParams := TStringList.Create;
  FPendingLines := TStringList.Create;
end;

destructor TProcessRunner.Destroy;
begin
  if Assigned(FThread) then
  begin
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
  FPendingLines.Free;
  FParams.Free;
  inherited Destroy;
end;

procedure TProcessRunner.FlushToUI;
var
  i: Integer;
begin
  if Assigned(FOnOutput) then
    for i := 0 to FPendingLines.Count - 1 do
      FOnOutput(Self, FPendingLines[i]);
  FPendingLines.Clear;

  if FHasPendingDone then
  begin
    FHasPendingDone := False;
    if Assigned(FOnDone) then FOnDone(Self, FPendingExitCode);
  end;
end;

procedure TProcessRunner.Run(const AExe: string; AParams: TStrings; const AWorkDir: string);
begin
  if IsRunning then Exit;
  if Assigned(FThread) then
  begin
    // Previous run finished but its thread object was never reaped - do
    // that now before starting the next one.
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
  FExe := AExe;
  FParams.Assign(AParams);
  FWorkDir := AWorkDir;
  FThread := TProcessRunnerThread.Create(Self);
end;

function TProcessRunner.IsRunning: Boolean;
begin
  Result := Assigned(FThread) and not FThread.Finished;
end;

end.
