unit uvendorsniff;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  // Laser-fork vendors LaserGRBL itself distinguishes at the protocol
  // level (welcome-banner/model-message text). lvGrblHAL is included
  // since its banner needs its own recognition (starts "GrblHAL ", not
  // caught by this app's existing 'Grbl'-prefix banner branch the same
  // way - see the caller in ugenericcontroller.pas).
  TLaserVendorKind = (lvGeneric, lvOrtur, lvAufero, lvLonger, lvGrblHAL,
    lvSimpleLaser, lvVigotec);

// Classifies ONE received line by vendor, using the exact prefix/suffix
// rules read directly from LaserGRBL's real source (Core/GrblCore.cs:
// IsGrblHalWelcomeMessage/IsOrturModelMessage/IsAuferoModelMessage/
// IsOrturFirmwareMessage/IsLongerModelMessage/IsLongerFirmwareMessage/
// IsSimpleLaserWelcomeMessage, plus the VendorName property's Vigotec
// substring check) - not guessed. Returns lvGeneric for any line that
// doesn't match a known vendor pattern (including perfectly ordinary
// "Grbl 1.1f [...]" banners - those ARE grbl, just not one of these
// forks). A caller should ignore an lvGeneric result rather than treat
// it as "reset to generic", since most lines naturally aren't a welcome
// banner at all.
function SniffVendor(const ALine: string): TLaserVendorKind;

implementation

function StartsWithStr(const APrefix, AStr: string): Boolean;
begin
  Result := Copy(AStr, 1, Length(APrefix)) = APrefix;
end;

function EndsWithStr(const ASuffix, AStr: string): Boolean;
begin
  Result := (Length(AStr) >= Length(ASuffix)) and
    (Copy(AStr, Length(AStr) - Length(ASuffix) + 1, Length(ASuffix)) = ASuffix);
end;

function SniffVendor(const ALine: string): TLaserVendorKind;
var
  lower: string;
begin
  Result := lvGeneric;
  if ALine = '' then Exit;
  lower := LowerCase(ALine);

  // Vigotec clones report themselves through the Ortur/Aufero-style model
  // message but with "Vigotec" somewhere in the machine-name text - check
  // this BEFORE the plain Ortur/Aufero classification (mirrors
  // GrblVersionInfo.VendorName's own precedence: Ortur/Vigotec are
  // distinguished by substring, not by a separate top-level message type).
  if (StartsWithStr('Ortur ', ALine) or StartsWithStr('Aufero ', ALine)) and
     (Pos('vigotec', lower) > 0) then
  begin
    Result := lvVigotec;
    Exit;
  end;

  if StartsWithStr('GrblHAL ', ALine) then
    Result := lvGrblHAL
  else if StartsWithStr('Ortur ', ALine) then
    Result := lvOrtur
  else if StartsWithStr('Aufero ', ALine) then
    Result := lvAufero
  else if StartsWithStr('OLF', ALine) then
    Result := lvOrtur // Ortur Laser Firmware banner variant
  else if StartsWithStr('SimpleLaser ', ALine) then
    Result := lvSimpleLaser
  else if StartsWithStr('[Machine:', ALine) and EndsWithStr(']', ALine) then
    Result := lvLonger
  else if StartsWithStr('[Software:', ALine) and EndsWithStr(']', ALine) then
    Result := lvLonger;
end;

end.
