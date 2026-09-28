unit ulasercooling;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TCoolingPhase = (cpCutting, cpCooling);

  // No-argument method callback - deliberately NOT coupled to TSender
  // directly (this unit lives in src/protocol alongside usender.pas,
  // which would need to `uses ulasercooling` to own a TCoolingCycle field
  // - depending on TSender here too would create a circular unit
  // dependency, the exact problem IControllerHost already exists to avoid
  // elsewhere in this codebase; see ugenericcontroller.pas's comment).
  // usender.pas passes @FeedHold/@Resume (its own existing public
  // methods) as these callbacks instead.
  TCoolingActionEvent = procedure of object;

  { TCoolingCycle: duty-cycle pulse-cooling for the laser diode during long
    jobs (plan Phase 7 - LaserGRBL's ManageCoolingCycles). Periodically
    invokes AOnFeedHold then AOnResume at a configurable on/off cadence.

    Deliberately timer-driven (elapsed real time via GetTickCount64), NOT
    driven by grbl's reported machine state (TCNCState.StateStr): if this
    were gated on StateStr='Run', the FeedHold WE trigger would itself
    change the reported state to 'Hold', and a StateStr-based check would
    then never see 'Run' again to know when to Resume - a self-defeating
    feedback loop. Tracking our own FPhase avoids that entirely. }
  TCoolingCycle = class
  private
    FOnFeedHold: TCoolingActionEvent;
    FOnResume: TCoolingActionEvent;
    FOnSeconds: Integer;
    FOffSeconds: Integer;
    FPhase: TCoolingPhase;
    FPhaseStartTick: QWord;
    FActive: Boolean; // True only while a cycle is actively tracking a job
  public
    constructor Create(AOnFeedHold, AOnResume: TCoolingActionEvent);
    // Call once per TSenderThread loop iteration. AJobActive should be
    // True only while a laser job is genuinely streaming AND not already
    // paused by the user for an unrelated reason (see usender.pas's call
    // site) - False resets the cycle to a fresh cpCutting start and, if a
    // cooling pause was mid-flight when the job ended, resumes the
    // machine so it's never left sitting in a hold this cycle caused.
    procedure Tick(AJobActive: Boolean);
    property OnSeconds: Integer read FOnSeconds write FOnSeconds;
    property OffSeconds: Integer read FOffSeconds write FOffSeconds;
  end;

implementation

constructor TCoolingCycle.Create(AOnFeedHold, AOnResume: TCoolingActionEvent);
begin
  inherited Create;
  FOnFeedHold := AOnFeedHold;
  FOnResume := AOnResume;
  FOnSeconds := 60;
  FOffSeconds := 10;
  FPhase := cpCutting;
  FActive := False;
end;

procedure TCoolingCycle.Tick(AJobActive: Boolean);
var
  elapsed: QWord;
begin
  if not AJobActive then
  begin
    if FActive and (FPhase = cpCooling) then
      FOnResume;
    FPhase := cpCutting;
    FActive := False;
    Exit;
  end;

  if not FActive then
  begin
    FActive := True;
    FPhase := cpCutting;
    FPhaseStartTick := GetTickCount64;
    Exit;
  end;

  elapsed := GetTickCount64 - FPhaseStartTick;
  case FPhase of
    cpCutting:
      if elapsed >= QWord(FOnSeconds) * 1000 then
      begin
        FOnFeedHold;
        FPhase := cpCooling;
        FPhaseStartTick := GetTickCount64;
      end;
    cpCooling:
      if elapsed >= QWord(FOffSeconds) * 1000 then
      begin
        FOnResume;
        FPhase := cpCutting;
        FPhaseStartTick := GetTickCount64;
      end;
  end;
end;

end.
