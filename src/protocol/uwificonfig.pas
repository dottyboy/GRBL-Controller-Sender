unit uwificonfig;

{ uwificonfig: writes WiFi station credentials to an Ortur/Longer grblHAL-
  family board (plan Phase 21), and recognizes the board's own reply once
  it has connected and been assigned an IP.

  Scope correction, disclosed (found by reading real source rather than
  trusting the plan's own original guess): the plan's file comment calls
  this "HTTP config POST", but LaserGRBL's own real implementation
  (Core/GrblCore.cs's WriteOrturWiFi/WriteLongerWiFi) does nothing of the
  kind - it sends plain GRBL commands over the board's EXISTING serial
  connection (the same one already used for everything else in this app),
  then watches the normal message stream for one specific `[MSG:...]`
  line containing the assigned IP once the board has joined the network.
  No HTTP client of any kind is involved. Ported here exactly as found:

  - Ortur: `$74=<ssid>`, `$75=<password>`, `$WRS` (grblHAL setting IDs 74/
    75 are the real WiFi SSID/password settings; $WRS = "write, reset,
    save"). Reply to watch for: `[MSG:Get IP <ip>]`.
  - Longer: `$radio/mode=sta`, `$sta/ssid=<ssid>`, `$sta/password=<pwd>`,
    `$wifi/begin`. Reply to watch for: `[MSG:Connected with <ip>]`.

  Pure/LCL-free - the caller (uwificonfigform.pas) pushes the returned
  command list onto the app's own already-existing TSender.EnqueueGCode
  queue, and feeds each received line through TryParseAssignedIP the same
  way the rest of this app already logs received lines - no new transport
  or parsing infrastructure needed. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TWiFiBoardKind = (wbkOrtur, wbkLonger);

// BuildWiFiConfigCommands: appends the real command sequence for the
// given board family to ACommands (does not clear it first, so a caller
// can prepend anything else it wants sent first).
procedure BuildWiFiConfigCommands(AKind: TWiFiBoardKind; const ASSID, APassword: string; ACommands: TStrings);

// TryParseAssignedIP: recognizes the real board reply containing the
// newly-assigned station IP (either board family's own exact message
// shape) and extracts it. Any other line (including a generic [MSG:...]
// that isn't one of these two) returns False - never a partial/garbage
// match.
function TryParseAssignedIP(const ALine: string; out AIP: string): Boolean;

const
  ORTUR_IP_PREFIX = '[MSG:Get IP ';
  LONGER_IP_PREFIX = '[MSG:Connected with ';

implementation

procedure BuildWiFiConfigCommands(AKind: TWiFiBoardKind; const ASSID, APassword: string; ACommands: TStrings);
begin
  case AKind of
    wbkOrtur:
      begin
        ACommands.Add('$74=' + ASSID);
        ACommands.Add('$75=' + APassword);
        ACommands.Add('$WRS');
      end;
    wbkLonger:
      begin
        ACommands.Add('$radio/mode=sta');
        ACommands.Add('$sta/ssid=' + ASSID);
        ACommands.Add('$sta/password=' + APassword);
        ACommands.Add('$wifi/begin');
      end;
  end;
end;

function TryParseAssignedIP(const ALine: string; out AIP: string): Boolean;
begin
  AIP := '';
  if (Pos(ORTUR_IP_PREFIX, ALine) = 1) and (Length(ALine) > 0) and (ALine[Length(ALine)] = ']') then
  begin
    AIP := Copy(ALine, Length(ORTUR_IP_PREFIX) + 1, Length(ALine) - Length(ORTUR_IP_PREFIX) - 1);
    Result := True;
    Exit;
  end;
  if (Pos(LONGER_IP_PREFIX, ALine) = 1) and (Length(ALine) > 0) and (ALine[Length(ALine)] = ']') then
  begin
    AIP := Copy(ALine, Length(LONGER_IP_PREFIX) + 1, Length(ALine) - Length(LONGER_IP_PREFIX) - 1);
    Result := True;
    Exit;
  end;
  Result := False;
end;

end.
