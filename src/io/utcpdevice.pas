unit utcpdevice;

{ utcpdevice: parses the "tcp:host:port" device-string convention (plan
  Phase 21) userial.pas's TSerialLink recognizes as "open a raw TCP socket
  instead of a real serial port". Deliberately its own tiny, LCL-free unit
  - not folded directly into userial.pas - since userial.pas depends on
  the registered LCL component TLazSerial (needs the full Lazarus/
  Interfaces search path to even link a throwaway test program against,
  a documented gotcha from this project's own Firmware Builder work), while
  this parsing logic is pure string handling with no such dependency and
  is worth standalone-testing on its own. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

const
  // A "tcp:host:port" device string (typed directly into the existing
  // Port field, or built by uwificonfigform.pas's simple connect dialog
  // / discovery scan results) means "open a raw TCP socket instead of a
  // real serial port" - the cheap, high-value path the plan's own 2nd-
  // wave scope note calls out (a plain host:port connect for an ESP32/
  // grblHAL-over-WiFi board that's already configured and running its
  // own Telnet-style raw-passthrough server, same wire protocol as USB
  // serial, just over a socket).
  TCP_DEVICE_PREFIX = 'tcp:';

function TryParseTcpDevice(const ADevice: string; out AHost: string; out APort: Integer): Boolean;

implementation

function TryParseTcpDevice(const ADevice: string; out AHost: string; out APort: Integer): Boolean;
var
  rest: string;
  colonPos: Integer;
begin
  Result := False;
  AHost := ''; APort := 0;
  if Pos(TCP_DEVICE_PREFIX, ADevice) <> 1 then Exit;
  rest := Copy(ADevice, Length(TCP_DEVICE_PREFIX) + 1, Length(ADevice));
  // Split on the LAST ':' (not the first) so a bare IPv4 host:port keeps
  // working exactly as expected while still tolerating (if never really
  // exercised) a host string that happens to contain other colons.
  colonPos := Length(rest);
  while (colonPos > 0) and (rest[colonPos] <> ':') do Dec(colonPos);
  if colonPos = 0 then Exit; // no port given
  AHost := Copy(rest, 1, colonPos - 1);
  APort := StrToIntDef(Copy(rest, colonPos + 1, Length(rest)), 0);
  Result := (AHost <> '') and (APort > 0) and (APort <= 65535);
end;

end.
