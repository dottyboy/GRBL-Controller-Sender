unit userial;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LazSerial, ugrblemulator, blcksock, utcpdevice;

type
  { TSerialLink wraps TLazSerial for blocking, poll-driven use from a
    dedicated worker thread - mirroring bCNC's Sender.py serialIO(), which
    runs in its own Python thread and calls the blocking pyserial
    `readline()`/`write()` directly (see usender.pas). This is why line
    framing here is a blocking RecvTerminated() call, not TLazSerial's
    async OnRxData event: using both the async event (which Synchronizes
    onto the main thread internally) and a separate worker thread reading
    the same port would race on the same underlying handle. Only ONE
    thread (usender.pas's TSenderThread) may call ReadLine/WriteRaw/
    WriteLine on an open TSerialLink - the main thread only calls
    OpenPort/ClosePort/IsOpen.

    Plan Phase 19: when OpenPort's ADevice is the special
    EMULATOR_DEVICE_NAME sentinel, this class routes every call to an
    owned TGrblEmulator instead of the real TLazSerial - same public API,
    zero changes needed anywhere else in the protocol stack (usender.pas
    only ever talks to TSerialLink, never to TLazSerial directly).

    Plan Phase 21: when OpenPort's ADevice matches the TCP_DEVICE_PREFIX
    convention ("tcp:host:port"), this class instead opens a raw TCP
    socket (Synapse's TTCPBlockSocket - the same library TLazSerial's own
    SynSer already wraps for real serial ports, so this needs no new
    third-party dependency) - a third, equally transparent backend
    alongside the real serial port and the Phase 19 emulator. }
  TSerialLink = class
  private
    FSerial: TLazSerial;
    FEmulator: TGrblEmulator; // non-nil only while "connected" to the emulator
    FTcp: TTCPBlockSocket;    // non-nil only while "connected" via tcp:host:port
  public
    constructor Create(AOwner: TComponent);
    destructor Destroy; override;

    procedure OpenPort(const ADevice: string; ABaud: Integer);
    procedure ClosePort;
    function IsOpen: Boolean;

    // Blocking read of one LF-terminated line (CR, if present, is
    // stripped), with a timeout in milliseconds. Returns '' on timeout -
    // callers distinguish "nothing arrived" from "empty line" the same
    // way bCNC's serialIO() loop does (an empty line is simply skipped).
    function ReadLine(ATimeoutMs: Integer): string;

    // Unbuffered write - for GRBL realtime single-byte commands (?,!,~,^X)
    // which must bypass any line queue (see ugenericcontroller.pas).
    procedure WriteRaw(const AData: string);
    // Appends a trailing LF and writes - for queued g-code lines.
    procedure WriteLine(const ALine: string);

    // Raw byte-level I/O for uxmodem.pas (Phase G: FluidNC config transfer).
    // Like ReadLine/WriteRaw/WriteLine above, these must only be called
    // while no other thread is touching this port - usender.pas pauses its
    // worker thread's own reads for the duration of a transfer (see
    // TSender.BeginFileTransfer/EndFileTransfer) so XMODEM can run
    // synchronously on the caller's thread without racing it.
    function ReadByte(ATimeoutMs: Integer): Integer; // -1 on timeout
    function ReadBytes(var ABuf; ACount, ATimeoutMs: Integer): Integer; // actual count read
    procedure WriteByte(AByte: Byte);
    procedure WriteBytes(const ABuf; ACount: Integer);
  end;

function BaudToEnum(ABaud: Integer): TBaudRate;

implementation

function BaudToEnum(ABaud: Integer): TBaudRate;
begin
  case ABaud of
    1200: Result := br__1200;
    2400: Result := br__2400;
    4800: Result := br__4800;
    9600: Result := br__9600;
    19200: Result := br_19200;
    38400: Result := br_38400;
    57600: Result := br_57600;
    115200: Result := br115200;
    230400: Result := br230400;
  else
    Result := br115200;
  end;
end;

constructor TSerialLink.Create(AOwner: TComponent);
begin
  inherited Create;
  FSerial := TLazSerial.Create(AOwner);
end;

destructor TSerialLink.Destroy;
begin
  ClosePort;
  FSerial.Free;
  inherited Destroy;
end;

procedure TSerialLink.OpenPort(const ADevice: string; ABaud: Integer);
var
  host: string;
  port: Integer;
begin
  if ADevice = EMULATOR_DEVICE_NAME then
  begin
    FreeAndNil(FEmulator);
    FEmulator := TGrblEmulator.Create;
    Exit;
  end;
  if TryParseTcpDevice(ADevice, host, port) then
  begin
    FreeAndNil(FTcp);
    FTcp := TTCPBlockSocket.Create;
    FTcp.Connect(host, IntToStr(port));
    if FTcp.LastError <> 0 then
      FreeAndNil(FTcp); // connect failed - IsOpen correctly reports False
    Exit;
  end;
  FSerial.Device := ADevice;
  FSerial.BaudRate := BaudToEnum(ABaud);
  FSerial.Active := True;
end;

procedure TSerialLink.ClosePort;
begin
  FreeAndNil(FEmulator);
  if FTcp <> nil then
  begin
    FTcp.CloseSocket;
    FreeAndNil(FTcp);
  end;
  if FSerial.Active then
    FSerial.Active := False;
end;

function TSerialLink.IsOpen: Boolean;
begin
  Result := (FEmulator <> nil) or (FTcp <> nil) or FSerial.Active;
end;

function TSerialLink.ReadLine(ATimeoutMs: Integer): string;
begin
  if FEmulator <> nil then
  begin
    Result := FEmulator.ReadLine;
    // Mirrors a real blocking-with-timeout serial read: if nothing is
    // pending right now, wait out the same timeout a real board's silence
    // would cost before giving up - without this, TSenderThread's own
    // loop (which has no other pacing between reads) would busy-spin one
    // CPU core as fast as possible against an emulator that never blocks.
    if Result = '' then
      Sleep(ATimeoutMs);
    Exit;
  end;
  if FTcp <> nil then
  begin
    Result := TrimRight(FTcp.RecvTerminated(ATimeoutMs, #10));
    Exit;
  end;
  if not FSerial.Active then
  begin
    Result := '';
    Exit;
  end;
  Result := TrimRight(FSerial.SynSer.RecvTerminated(ATimeoutMs, #10));
end;

procedure TSerialLink.WriteRaw(const AData: string);
begin
  if FEmulator <> nil then
  begin
    FEmulator.WriteRaw(AData);
    Exit;
  end;
  if FTcp <> nil then
  begin
    FTcp.SendString(AData);
    Exit;
  end;
  if FSerial.Active then
    FSerial.SynSer.SendString(AData);
end;

procedure TSerialLink.WriteLine(const ALine: string);
begin
  if FEmulator <> nil then
  begin
    // Deliberately NOT routed through WriteRaw: the emulator's WriteRaw is
    // a per-BYTE realtime-command dispatcher ('?', '!', '~', Ctrl-X) with
    // no case arm for ordinary g-code characters or the trailing LF - a
    // queued line needs the emulator's own line-oriented WriteLine/
    // HandleLine path instead.
    FEmulator.WriteLine(ALine);
    Exit;
  end;
  WriteRaw(ALine + #10);
end;

function TSerialLink.ReadByte(ATimeoutMs: Integer): Integer;
var
  b: Byte;
begin
  if not FSerial.Active then
  begin
    Result := -1;
    Exit;
  end;
  b := FSerial.SynSer.RecvByte(ATimeoutMs);
  if FSerial.SynSer.LastError <> 0 then
    Result := -1
  else
    Result := b;
end;

function TSerialLink.ReadBytes(var ABuf; ACount, ATimeoutMs: Integer): Integer;
begin
  if not FSerial.Active then
  begin
    Result := 0;
    Exit;
  end;
  Result := FSerial.SynSer.RecvBufferEx(@ABuf, ACount, ATimeoutMs);
end;

procedure TSerialLink.WriteByte(AByte: Byte);
begin
  if FSerial.Active then
    FSerial.SynSer.SendByte(AByte);
end;

procedure TSerialLink.WriteBytes(const ABuf; ACount: Integer);
begin
  if FSerial.Active then
    FSerial.SynSer.SendBuffer(@ABuf, ACount);
end;

end.
