unit userial;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LazSerial;

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
    OpenPort/ClosePort/IsOpen. }
  TSerialLink = class
  private
    FSerial: TLazSerial;
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
begin
  FSerial.Device := ADevice;
  FSerial.BaudRate := BaudToEnum(ABaud);
  FSerial.Active := True;
end;

procedure TSerialLink.ClosePort;
begin
  if FSerial.Active then
    FSerial.Active := False;
end;

function TSerialLink.IsOpen: Boolean;
begin
  Result := FSerial.Active;
end;

function TSerialLink.ReadLine(ATimeoutMs: Integer): string;
begin
  if not FSerial.Active then
  begin
    Result := '';
    Exit;
  end;
  Result := TrimRight(FSerial.SynSer.RecvTerminated(ATimeoutMs, #10));
end;

procedure TSerialLink.WriteRaw(const AData: string);
begin
  if FSerial.Active then
    FSerial.SynSer.SendString(AData);
end;

procedure TSerialLink.WriteLine(const ALine: string);
begin
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
