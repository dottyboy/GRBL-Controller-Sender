unit ulaserusage;

{ ulaserusage: laser module usage/lifetime tracking (plan Phase 20) - a
  pure record + accumulator functions, ported from LaserGRBL's real
  `LaserLifeHandler`/`LaserLifeCounter` (Core/GrblCore.cs) rather than
  invented: this app supports multiple named laser modules (a machine's
  laser gets swapped over its lifetime), each accumulating two distinct
  real metrics LaserGRBL itself tracks -

  - TimeInRunSeconds: total wall-clock time the machine spent in the
    grbl 'Run' state (mirrors `ComputeLaserTime`'s own `AddRunTime` -
    counts ALL running time, laser on or not, e.g. framing moves).
  - TimeUsageNormalizedPowerSeconds: elapsed laser-on time scaled by
    commanded power fraction (mirrors `ComputeLaserTrueTime`'s own
    `AddTrueLaserTimePower` - a burn at 50% power for 10s counts as 5s of
    "true" usage) - plus a 10-bucket power-decile histogram
    (`TimeClasses`), matching the real source's exact thresholds (skip
    tracking under 3% power - "framing etc", per its own comment; skip
    the histogram bucket under 1%) and bucket math
    (`Floor((powerperc*100-1)/10)`, clamped 0-9).

  Deliberately NOT ported: LaserGRBL's own binary/JSON multi-target sync
  (SendAndSave/telemetry upload) - this app's own ini-based
  ulaserusagestore.pas persists locally only, matching this project's
  established store-unit convention instead of a literal storage-format
  port. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math;

const
  DEF_NAME = 'Default';
  DEF_BRAND = 'Unknown';
  DEF_MODEL = 'Unknown';
  // Real thresholds from LaserGRBL's own AddTrueLaserTimePower - not
  // guessed: "do not track any usage under 3% (framing etc)" for the
  // normalized-power/non-zero accumulators, and a looser 1% floor before
  // a power sample counts toward the decile histogram at all.
  NORMALIZED_POWER_THRESHOLD = 0.03;
  HISTOGRAM_POWER_THRESHOLD = 0.01;

type
  TLaserUsageCounter = record
    Guid: string;
    Name, Brand, Model: string;
    HasOpticalPower: Boolean;
    OpticalPower: Double;
    HasPurchaseDate: Boolean;
    PurchaseDate: TDateTime;
    HasMonitoringDate: Boolean;
    MonitoringDate: TDateTime;
    HasDeathDate: Boolean;
    DeathDate: TDateTime;
    HasLastUsage: Boolean;
    LastUsage: TDateTime;
    TimeInRunSeconds: Double;
    TimeUsageNormalizedPowerSeconds: Double;
    TimeUsageNonZeroSeconds: Double;
    // TimeClasses[i] = seconds spent with commanded power in decile i
    // (0 = 1-10%, ..., 9 = 91-100%) - TimeClasses[9] is LaserGRBL's own
    // real "StressTime" (heaviest-use bracket).
    TimeClasses: array[0..9] of Double;
  end;

  TLaserUsageCounterArray = array of TLaserUsageCounter;

function NewGuid: string;
function CreateNewCounter: TLaserUsageCounter;
function CreateDefaultCounter: TLaserUsageCounter;

// AddRunTime: mirrors ComputeLaserTime's own AddRunTime - call with the
// elapsed time since the last tick whenever the machine is in the 'Run'
// state (the caller gates on run-state; this function just accumulates).
procedure AddRunTime(var ACounter: TLaserUsageCounter; AElapsedSeconds: Double);

// AddTrueLaserTimePower: mirrors AddTrueLaserTimePower exactly, including
// its own two independent thresholds and decile-bucketing math.
// APowerFrac is commanded-power/max-power, 0..1 (matches the real
// `power/Configuration.MaxPWM` division at the real call site).
procedure AddTrueLaserTimePower(var ACounter: TLaserUsageCounter; AElapsedSeconds, APowerFrac: Double);

function AveragePowerFactor(const ACounter: TLaserUsageCounter): Double;
function StressTimeSeconds(const ACounter: TLaserUsageCounter): Double;
function HasWorked(const ACounter: TLaserUsageCounter): Boolean;

implementation

function NewGuid: string;
var
  g: TGuid;
begin
  if CreateGUID(g) = 0 then
    Result := GUIDToString(g)
  else
    Result := FormatDateTime('yyyymmddhhnnsszzz', Now); // extremely unlikely fallback
end;

function CreateNewCounter: TLaserUsageCounter;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Guid := NewGuid;
  Result.HasMonitoringDate := True;
  Result.MonitoringDate := Date;
end;

function CreateDefaultCounter: TLaserUsageCounter;
begin
  Result := CreateNewCounter;
  Result.Name := DEF_NAME;
end;

procedure AddRunTime(var ACounter: TLaserUsageCounter; AElapsedSeconds: Double);
begin
  ACounter.TimeInRunSeconds := ACounter.TimeInRunSeconds + AElapsedSeconds;
  ACounter.HasLastUsage := True;
  ACounter.LastUsage := Date;
end;

procedure AddTrueLaserTimePower(var ACounter: TLaserUsageCounter; AElapsedSeconds, APowerFrac: Double);
var
  normalized: Double;
  clx: Integer;
begin
  if APowerFrac > NORMALIZED_POWER_THRESHOLD then
  begin
    normalized := AElapsedSeconds * APowerFrac;
    ACounter.TimeUsageNormalizedPowerSeconds := ACounter.TimeUsageNormalizedPowerSeconds + normalized;
    ACounter.TimeUsageNonZeroSeconds := ACounter.TimeUsageNonZeroSeconds + AElapsedSeconds;
  end;

  if APowerFrac > HISTOGRAM_POWER_THRESHOLD then
  begin
    clx := Floor((APowerFrac * 100 - 1) / 10); // 1-10%=0, 11-20%=1, ..., 91-100%=9
    if clx < 0 then clx := 0;
    if clx > 9 then clx := 9;
    ACounter.TimeClasses[clx] := ACounter.TimeClasses[clx] + AElapsedSeconds;
  end;

  ACounter.HasLastUsage := True;
  ACounter.LastUsage := Date;
end;

function AveragePowerFactor(const ACounter: TLaserUsageCounter): Double;
begin
  if ACounter.TimeUsageNonZeroSeconds = 0 then
    Result := 0
  else
    Result := ACounter.TimeUsageNormalizedPowerSeconds / ACounter.TimeUsageNonZeroSeconds;
end;

function StressTimeSeconds(const ACounter: TLaserUsageCounter): Double;
begin
  Result := ACounter.TimeClasses[9];
end;

function HasWorked(const ACounter: TLaserUsageCounter): Boolean;
begin
  Result := ACounter.TimeInRunSeconds > 3600; // real source's own ">1 hour" rule
end;

end.
