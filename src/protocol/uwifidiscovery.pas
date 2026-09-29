unit uwifidiscovery;

{ uwifidiscovery: local-subnet scan for an already-WiFi-connected grblHAL
  board (plan Phase 21's "UDP scan" - a name carried over from the plan's
  own original guess; LaserGRBL's real implementation, read directly from
  WiFiDiscovery/IPAddressHelper.cs before writing any of this, is
  actually a full local-SUBNET SCAN, not a UDP broadcast-discovery
  protocol: enumerate every host address in the local /prefix range, ping
  each one, and for responders check whether the board's own port (23 for
  Telnet-style grblHAL boards, matching this project's own Phase 21 TCP
  direct-connect) is open, plus a reverse-DNS hostname lookup).

  Scope reductions, disclosed (both are Windows-only or privilege-
  requiring in the real source, not portable to this project's Linux
  target without real added complexity/risk):
  - No ARP-based MAC-address lookup (the real source's own SendARP is a
    literal `[DllImport("iphlpapi.dll")]` - Windows-only).
  - No ICMP ping pre-filter (raw ICMP sockets need root/CAP_NET_RAW on
    Linux) - this scanner instead goes straight to the real, portable
    signal that actually matters here anyway: a TCP connect-probe on the
    target port (exactly what the real source's own Telnet() helper does
    for its "deep scan" confirmation step, just promoted to the ONLY
    probe here instead of a ping-then-probe two-step). Slower against a
    full /24 with nothing listening (no fast ping pre-filter to skip
    obviously-dead hosts) but correct and portable, and still keeps a
    real reverse-DNS hostname lookup per responder.

  Pure network-address math (HostsInSubnet) is LCL-free and standalone-
  testable; ProbeHost/ScanSubnet need Synapse's blcksock (already a
  Phase 21 dependency via userial.pas's TCP direct-connect support). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, blcksock, synsock;

type
  TDiscoveryResult = record
    IP: string;
    Port: Integer;
    HostName: string; // '' if reverse-DNS lookup failed or found nothing
  end;

  TDiscoveryFoundEvent = procedure(const AResult: TDiscoveryResult) of object;
  TDiscoveryProgressEvent = procedure(ADone, ATotal: Integer) of object;
  TDiscoveryCancelFunc = function: Boolean of object;

// HostsInSubnet: every usable host address strictly between the network
// and broadcast address of ABaseIP/ASubnetMask (both real dotted-quad
// IPv4 strings) - the network/broadcast math itself mirrors the real
// source's own IPSegment exactly (network = ip AND mask, broadcast =
// network OR (NOT mask)), just addressed as plain 32-bit arithmetic
// instead of C#'s byte-array-of-4 approach.
function HostsInSubnet(const ABaseIP, ASubnetMask: string): TStringArray;

// ProbeHost: True if a TCP connect to AIP:APort succeeds within
// ATimeoutMs - the portable equivalent of the real source's own Telnet()
// probe (connect-and-immediately-close, no data exchanged).
function ProbeHost(const AIP: string; APort, ATimeoutMs: Integer): Boolean;

// ReverseLookupHostName: best-effort reverse-DNS hostname for AIP - ''
// if none resolves (most LAN devices won't have one, matching the real
// source's own GetHostName's own silent-failure convention).
function ReverseLookupHostName(const AIP: string): string;

// ScanSubnet: synchronous/blocking - probes every host in
// HostsInSubnet(ABaseIP, ASubnetMask) at APort, calling AOnFound for each
// real responder (with HostName already filled in) and AOnProgress after
// every attempt (responder or not). The caller runs this on a worker
// thread, same as the real source's own background Task - this unit
// itself has no threading of its own. AOnCancel, if given, is checked
// before each host and stops the scan early (returning normally, not an
// error) the first time it returns True - mirrors the real source's own
// CancellationToken, just as a plain polled function instead.
procedure ScanSubnet(const ABaseIP, ASubnetMask: string; APort, ATimeoutMs: Integer;
  AOnFound: TDiscoveryFoundEvent; AOnProgress: TDiscoveryProgressEvent;
  AOnCancel: TDiscoveryCancelFunc = nil);

implementation

function IPToUInt32(const AIP: string): UInt32;
var
  parts: TStringArray;
begin
  parts := AIP.Split('.');
  Result := 0;
  if Length(parts) <> 4 then Exit;
  Result := (UInt32(StrToIntDef(parts[0], 0)) shl 24) or
            (UInt32(StrToIntDef(parts[1], 0)) shl 16) or
            (UInt32(StrToIntDef(parts[2], 0)) shl 8) or
             UInt32(StrToIntDef(parts[3], 0));
end;

function UInt32ToIP(AValue: UInt32): string;
begin
  Result := Format('%d.%d.%d.%d', [(AValue shr 24) and $FF, (AValue shr 16) and $FF,
    (AValue shr 8) and $FF, AValue and $FF]);
end;

function HostsInSubnet(const ABaseIP, ASubnetMask: string): TStringArray;
var
  ip, mask, network, broadcast, host: UInt32;
  n, i: Integer;
begin
  SetLength(Result, 0);
  ip := IPToUInt32(ABaseIP);
  mask := IPToUInt32(ASubnetMask);
  network := ip and mask;
  broadcast := network or (not mask);
  if broadcast <= network + 1 then Exit; // degenerate/point-to-point range, no usable hosts
  n := broadcast - network - 1;
  SetLength(Result, n);
  i := 0;
  host := network + 1;
  while host < broadcast do
  begin
    Result[i] := UInt32ToIP(host);
    Inc(i);
    Inc(host);
  end;
end;

function ProbeHost(const AIP: string; APort, ATimeoutMs: Integer): Boolean;
var
  sock: TTCPBlockSocket;
begin
  sock := TTCPBlockSocket.Create;
  try
    sock.ConnectionTimeout := ATimeoutMs;
    sock.Connect(AIP, IntToStr(APort));
    // A real, empirically-confirmed Synapse quirk (found by live-testing
    // against a real local listener before trusting this): with
    // ConnectionTimeout set, Connect() performs a non-blocking connect
    // and only actually waits for the OS to confirm success via
    // CanWrite() - a REFUSED connection (closed port, no real risk) also
    // makes the socket "writable" at the select()/poll() level, so
    // LastError stays 0 right after Connect() either way. The refusal
    // only actually surfaces on the NEXT real socket operation - so a
    // single harmless NUL-byte probe write is sent and ITS LastError is
    // what's actually checked. A real GRBL/grblHAL board's line-buffered
    // parser silently absorbs one stray non-newline byte, so this is
    // safe against a genuine board too, not just a test listener.
    if sock.LastError = 0 then
      sock.SendByte(0);
    Result := sock.LastError = 0;
    if Result then
      sock.CloseSocket;
  finally
    sock.Free;
  end;
end;

function ReverseLookupHostName(const AIP: string): string;
var
  sock: TTCPBlockSocket;
begin
  sock := TTCPBlockSocket.Create;
  try
    Result := sock.ResolveIPToName(AIP);
    if Result = AIP then
      Result := ''; // Synapse's own convention: falls back to echoing the
                     // input IP when no reverse record resolves - not a
                     // real hostname, so normalize that to "none found".
  finally
    sock.Free;
  end;
end;

procedure ScanSubnet(const ABaseIP, ASubnetMask: string; APort, ATimeoutMs: Integer;
  AOnFound: TDiscoveryFoundEvent; AOnProgress: TDiscoveryProgressEvent;
  AOnCancel: TDiscoveryCancelFunc = nil);
var
  hosts: TStringArray;
  i: Integer;
  res: TDiscoveryResult;
begin
  hosts := HostsInSubnet(ABaseIP, ASubnetMask);
  for i := 0 to High(hosts) do
  begin
    if Assigned(AOnCancel) and AOnCancel() then Exit;
    if ProbeHost(hosts[i], APort, ATimeoutMs) then
    begin
      res.IP := hosts[i];
      res.Port := APort;
      res.HostName := ReverseLookupHostName(hosts[i]);
      if Assigned(AOnFound) then AOnFound(res);
    end;
    if Assigned(AOnProgress) then AOnProgress(i + 1, Length(hosts));
  end;
end;

end.
