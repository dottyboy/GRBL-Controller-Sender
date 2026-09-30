unit ulasercontrolframe;

{ TLaserControlFrame: the "Laser Control" tab (plan Phase 9) - the Start
  button every earlier laser-mode phase built but never had anywhere to
  hang off of. Reads the program body straight from the app's existing
  Editor tab (SynEditor.Lines, via SetEditorLines - same source ordinary
  g-code Send already uses), applies user-edited Header/Footer + pass
  count, runs the Phase 6 safety countdown, then calls ulasersender.pas's
  RunLaserProgram. Pause/Abort/override sliders/cooling toggle/Test Fire
  are thin wrappers around already-built TSender functionality (FeedHold/
  Resume/StopStreaming/TargetOv*/CoolingCycle) - this frame owns none of
  that logic, only the UI for it. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls, ComCtrls,
  Spin, ulasercommand, ulasersender, usender, uappconfig,
  uchecklist, umaterialpreset,
  ucustombutton, ucustombuttonstore, uheaderfooterpreset,
  uheaderfooterpresetstore, ui18n;

type
  TOnSafetyCountdownRequested = procedure(ASeconds: Integer) of object;
  TOnChecklistRequested = procedure(AChecklist: TChecklist) of object;

  { TLaserControlFrame }

  TLaserControlFrame = class(TFrame)
    BtnAbort: TButton;
    BtnEditMacros: TButton;
    BtnLoadHeaderFooterPreset: TButton;
    BtnPauseResume: TButton;
    BtnStart: TButton;
    BtnTestFire: TButton;
    CboHeaderFooterPreset: TComboBox;
    ChkArmTestFire: TCheckBox;
    ChkAutoCooling: TCheckBox;
    EdCoolOff: TSpinEdit;
    EdCoolOn: TSpinEdit;
    EdTestFirePower: TSpinEdit;
    LblCoolOff: TLabel;
    LblCoolOn: TLabel;
    LblFeed: TLabel;
    LblFeedValue: TLabel;
    LblFooter: TLabel;
    LblHeader: TLabel;
    LblMacros: TLabel;
    LblPasses: TLabel;
    LblProgress: TLabel;
    LblRapid: TLabel;
    LblSpindle: TLabel;
    LblSpindleValue: TLabel;
    LblStatus: TLabel;
    LblTestFirePower: TLabel;
    MacroPanel: TPanel;
    MemoFooter: TMemo;
    MemoHeader: TMemo;
    RbRapid100: TRadioButton;
    RbRapid50: TRadioButton;
    RbRapid25: TRadioButton;
    SpinPasses: TSpinEdit;
    TrackFeed: TTrackBar;
    TrackSpindle: TTrackBar;
    procedure BtnAbortClick(Sender: TObject);
    procedure BtnEditMacrosClick(Sender: TObject);
    procedure BtnLoadHeaderFooterPresetClick(Sender: TObject);
    procedure BtnPauseResumeClick(Sender: TObject);
    procedure BtnStartClick(Sender: TObject);
    procedure BtnTestFireClick(Sender: TObject);
    procedure ChkArmTestFireChange(Sender: TObject);
    procedure RbRapidChange(Sender: TObject);
    procedure TrackFeedChange(Sender: TObject);
    procedure TrackSpindleChange(Sender: TObject);
  private
    FSender: TSender;
    FAppConfig: TAppConfig;
    FEditorLines: TStrings;
    FProgram: TLaserProgram;
    FIsPaused: Boolean;
    // Plan Phase 14: macro button strip, dynamically (re)built from the
    // saved library each time it might have changed (frame creation and
    // right after the management dialog closes) - mirrors this app's
    // existing pattern of building controls at runtime (umain.pas's
    // Pages.AddTabSheet calls), just one level lower (buttons, not tabs).
    FButtonStore: TCustomButtonStore;
    FChecklist: TChecklist;
    FButtons: TCustomButtonArray;
    FOnEditMacros: TNotifyEvent;
    FOnSafetyCountdownRequested: TOnSafetyCountdownRequested;
    FOnChecklistRequested: TOnChecklistRequested;
    // Plan Phase 37: FHFPresets[0..BuiltInPresetCount-1] are the built-in
    // set (uheaderfooterpreset.pas), the rest are the user's own saved
    // custom ones (FHFStore) - one combined array so CboHeaderFooterPreset's
    // ItemIndex maps directly, no separate "which list" bookkeeping needed.
    FHFStore: THeaderFooterPresetStore;
    FHFPresets: THeaderFooterPresetArray;
    procedure MacroButtonClick(Sender: TObject);
    procedure SetStatus(const AMsg: string; AIsError: Boolean);
    procedure RefreshHeaderFooterPresets;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetSender(ASender: TSender);
    procedure SetAppConfig(AAppConfig: TAppConfig);
    // ALines is NOT owned/copied - the frame reads it fresh at Start time
    // (usender.pas: TEditorFrame.SynEditor.Lines), so edits made in the
    // Editor tab right before clicking Start are always picked up.
    procedure SetEditorLines(ALines: TStrings);
    // Called from umain.pas's SenderStateChanged (same reactive-refresh
    // pattern DROFrame/ConnectFrame already use) - updates the progress
    // label and Start/Pause/Abort enabled state from TSender.LaserJobProgress.
    procedure RefreshState;
    // Plan Phase 13: applies a saved material preset's Power/Speed/Passes.
    // Sets Passes directly (safe, direct match) and the Test Fire power
    // field (so a quick power check uses the right value), and records
    // Power/Speed as an inert g-code COMMENT in the header - deliberately
    // NOT an active M3/F line, which would arm the laser motionless at the
    // job's start position the instant Start is clicked, before any move -
    // a real safety concern this project takes seriously elsewhere (Phase
    // 2's M5-on-abort guarantee, Phase 6's countdown). The user still sets
    // the real M3 S/F words in their own g-code body, same as always.
    procedure ApplyMaterialPreset(const APreset: TMaterialPreset);
    // Plan Phase 14: reloads the macro button strip from custombuttons.ini -
    // called by umain.pas whenever the Laser Control tab becomes active, so
    // edits made on the separate Macros tab (ucustombuttonframe.pas) show
    // up here without needing a direct dependency between the two frames.
    procedure RefreshMacroButtons;
    // Plan Phase 6, split in a later session when the safety countdown
    // itself stopped being a blocking modal (see usafetycountdownframe.pas's
    // own doc comment - a real X11 ShowModal crash in this environment,
    // not a code regression): BtnStartClick now does everything through
    // the Phase 25 checklist, then either calls this directly (countdown
    // already skipped) or fires OnSafetyCountdownRequested and returns -
    // umain.pas's own wiring calls this from the countdown tab's
    // OnFinished once it really elapses, so the job still only starts
    // after the exact same gates as before.
    procedure ReallyStartJob(ADontShowAgainCountdown: Boolean);
    // The countdown tab's own OnCancelled - matches the old modal's
    // Cancel outcome (persist the checkbox, but never run the job).
    procedure AbortPendingStart(ADontShowAgainCountdown: Boolean);
    // The checklist tab's own OnProceed - continues exactly where the
    // old TChecklistForm.Execute=True branch used to (decide
    // countdown-or-run). Public so umain.pas's wiring can call it.
    procedure ContinueStartAfterChecklist;
    // The checklist tab's own OnCancelled.
    procedure CancelPendingChecklist;
    property OnEditMacros: TNotifyEvent read FOnEditMacros write FOnEditMacros;
    property OnSafetyCountdownRequested: TOnSafetyCountdownRequested
      read FOnSafetyCountdownRequested write FOnSafetyCountdownRequested;
    property OnChecklistRequested: TOnChecklistRequested
      read FOnChecklistRequested write FOnChecklistRequested;
  end;

implementation

{$R *.frm}

{ TLaserControlFrame }

constructor TLaserControlFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FProgram := TLaserProgram.Create;
  // Conservative defaults, not guessed: G21/G90 so a job always starts from
  // known units/distance-mode regardless of what a prior job left modal
  // state at; M5 so the laser is guaranteed off after a job that runs to
  // completion normally (the M5-on-abort guarantee in usender.pas only
  // covers the STOP path, not a clean finish - the footer is what covers
  // that case, so it needs a real default, not an empty one). Set on the
  // visible Memo* controls themselves, NOT FProgram.Header/Footer directly -
  // BtnStartClick always does FProgram.Header.Assign(MemoHeader.Lines) right
  // before running, so anything set only on FProgram here would be silently
  // overwritten the moment Start is first clicked (a real bug caught live -
  // the memos rendered empty despite this constructor "setting a default").
  MemoHeader.Lines.Add('G21');
  MemoHeader.Lines.Add('G90');
  MemoFooter.Lines.Add('M5');

  FButtonStore := TCustomButtonStore.Create(
    IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'custombuttons.ini');
  RefreshMacroButtons;

  FHFStore := THeaderFooterPresetStore.Create(
    IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'headerfooterpresets.ini');
  RefreshHeaderFooterPresets;

  FChecklist := TChecklist.Create(
    IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'checklist.ini');
  FChecklist.Load;
  FChecklist.SeedDefaultsIfEmpty;
end;

destructor TLaserControlFrame.Destroy;
begin
  FChecklist.Free;
  FHFStore.Free;
  FButtonStore.Free;
  FProgram.Free;
  inherited Destroy;
end;

procedure TLaserControlFrame.RefreshHeaderFooterPresets;
var
  custom: THeaderFooterPresetArray;
  i, n: Integer;
begin
  custom := FHFStore.LoadAll;
  SetLength(FHFPresets, BuiltInPresetCount + Length(custom));
  for i := 0 to BuiltInPresetCount - 1 do
    FHFPresets[i] := GetBuiltInPreset(i);
  for i := 0 to High(custom) do
    FHFPresets[BuiltInPresetCount + i] := custom[i];

  CboHeaderFooterPreset.Items.Clear;
  for n := 0 to High(FHFPresets) do
    CboHeaderFooterPreset.Items.Add(Format('%s [%s]',
      [FHFPresets[n].Name, KindName(FHFPresets[n].Kind)]));
  if CboHeaderFooterPreset.Items.Count > 0 then
    CboHeaderFooterPreset.ItemIndex := 0;
end;

procedure TLaserControlFrame.BtnLoadHeaderFooterPresetClick(Sender: TObject);
var
  idx: Integer;
begin
  idx := CboHeaderFooterPreset.ItemIndex;
  if (idx < 0) or (idx > High(FHFPresets)) then Exit;
  if Trim(FHFPresets[idx].Header) <> '' then
    MemoHeader.Lines.Text := FHFPresets[idx].Header
  else
    MemoHeader.Lines.Clear;
  if Trim(FHFPresets[idx].Footer) <> '' then
    MemoFooter.Lines.Text := FHFPresets[idx].Footer
  else
    MemoFooter.Lines.Clear;
end;

procedure TLaserControlFrame.SetSender(ASender: TSender);
begin
  FSender := ASender;
end;

procedure TLaserControlFrame.SetAppConfig(AAppConfig: TAppConfig);
begin
  FAppConfig := AAppConfig;
end;

procedure TLaserControlFrame.SetEditorLines(ALines: TStrings);
begin
  FEditorLines := ALines;
end;

procedure TLaserControlFrame.SetStatus(const AMsg: string; AIsError: Boolean);
begin
  LblStatus.Caption := AMsg;
  if AIsError then
    LblStatus.Font.Color := clRed
  else
    LblStatus.Font.Color := clGreen;
end;

procedure TLaserControlFrame.BtnStartClick(Sender: TObject);
var
  i: Integer;
  hasBody: Boolean;
begin
  if (FSender = nil) or (not FSender.Connected) then
  begin
    SetStatus(T('Not connected'), True);
    Exit;
  end;
  if FEditorLines = nil then
  begin
    SetStatus(T('Nothing to run'), True);
    Exit;
  end;

  hasBody := False;
  for i := 0 to FEditorLines.Count - 1 do
    if Trim(FEditorLines[i]) <> '' then
    begin
      hasBody := True;
      Break;
    end;
  if not hasBody then
  begin
    SetStatus(T('Nothing to run'), True);
    Exit;
  end;

  FProgram.LoadFromLines(FEditorLines);
  FProgram.Header.Assign(MemoHeader.Lines);
  FProgram.Footer.Assign(MemoFooter.Lines);

  // Plan Phase 25: pre-flight checklist, shown BEFORE the Phase 6 safety
  // countdown (confirm the physical setup first, then the final
  // countdown) - alongside it, not replacing it. An empty list never
  // blocks Start (matches the old TChecklistForm.Execute's own
  // contract). Non-empty (the real default - SeedDefaultsIfEmpty means
  // a fresh install already has items) defers to the checklist tab;
  // ContinueStartAfterChecklist below is exactly where control used to
  // land right after the old blocking ShowModal call returned True.
  if FChecklist.Count = 0 then
    ContinueStartAfterChecklist
  else if Assigned(FOnChecklistRequested) then
    FOnChecklistRequested(FChecklist)
  else
    ContinueStartAfterChecklist;
end;

procedure TLaserControlFrame.ContinueStartAfterChecklist;
var
  skipCountdown: Boolean;
begin
  skipCountdown := (not Assigned(FAppConfig)) or FAppConfig.SkipSafetyCountdown;
  if skipCountdown then
    ReallyStartJob(skipCountdown)
  else if Assigned(FOnSafetyCountdownRequested) then
    FOnSafetyCountdownRequested(FAppConfig.SafetyCountdownSeconds)
  else
    // No countdown tab wired up (shouldn't happen once umain.pas sets it
    // up, but fail toward running the job rather than silently doing
    // nothing if it somehow isn't) - matches the old skip-countdown path.
    ReallyStartJob(False);
end;

procedure TLaserControlFrame.CancelPendingChecklist;
begin
  SetStatus(T('Cancelled'), True);
end;

procedure TLaserControlFrame.ReallyStartJob(ADontShowAgainCountdown: Boolean);
var
  StartMacroLines, EndMacroLines: TStringList;
begin
  if Assigned(FAppConfig) then
    FAppConfig.SkipSafetyCountdown := ADontShowAgainCountdown;

  FSender.CoolingEnabled := ChkAutoCooling.Checked;
  if ChkAutoCooling.Checked then
  begin
    FSender.CoolingCycle.OnSeconds := EdCoolOn.Value;
    FSender.CoolingCycle.OffSeconds := EdCoolOff.Value;
  end;

  FIsPaused := False;
  BtnPauseResume.Caption := T('Pause');

  // Plan Phase 37: auto-run macros, fired at enqueue time (matching
  // LaserGRBL's own real ExecuteCustomCode timing) via the shared
  // TSender.BeginJob/EndJob hook - BeginJob's lines land on the queue
  // BEFORE RunLaserProgram's own header/body/footer, EndJob's land
  // after, since the queue is FIFO.
  StartMacroLines := TStringList.Create;
  EndMacroLines := TStringList.Create;
  try
    CombinedAutoRunGCode(FButtons, True, StartMacroLines);
    CombinedAutoRunGCode(FButtons, False, EndMacroLines);
    FSender.BeginJob(StartMacroLines);
    RunLaserProgram(FSender, FProgram, SpinPasses.Value);
    FSender.EndJob(EndMacroLines);
  finally
    StartMacroLines.Free;
    EndMacroLines.Free;
  end;

  SetStatus(T('Running'), False);
  RefreshState;
end;

procedure TLaserControlFrame.AbortPendingStart(ADontShowAgainCountdown: Boolean);
begin
  if Assigned(FAppConfig) then
    FAppConfig.SkipSafetyCountdown := ADontShowAgainCountdown;
  SetStatus(T('Cancelled'), True);
end;

procedure TLaserControlFrame.BtnPauseResumeClick(Sender: TObject);
begin
  if (FSender = nil) or (not FSender.Connected) then Exit;
  if FIsPaused then
  begin
    FSender.Resume;
    FIsPaused := False;
    BtnPauseResume.Caption := T('Pause');
  end
  else
  begin
    FSender.FeedHold;
    FIsPaused := True;
    BtnPauseResume.Caption := T('Resume');
  end;
end;

procedure TLaserControlFrame.BtnAbortClick(Sender: TObject);
begin
  if FSender = nil then Exit;
  // Mirrors LaserGRBL's own AbortProgram: a deliberate user abort ends job
  // tracking outright (EndLaserJob), unlike an Alarm-triggered stop (plan
  // Phase 5's crash-recovery path), which keeps FLaserJob.Active so the
  // resume dialog has something to offer.
  AbortLaserProgram(FSender);
  FSender.EndLaserJob;
  FIsPaused := False;
  BtnPauseResume.Caption := T('Pause');
  SetStatus(T('Aborted'), True);
  RefreshState;
end;

procedure TLaserControlFrame.ChkArmTestFireChange(Sender: TObject);
begin
  BtnTestFire.Enabled := ChkArmTestFire.Checked and (FSender <> nil) and FSender.Connected;
end;

procedure TLaserControlFrame.BtnTestFireClick(Sender: TObject);
begin
  if (FSender = nil) or (not FSender.Connected) or (not ChkArmTestFire.Checked) then Exit;
  // Bounded pulse via a real dwell (G4), not an open-ended M3 - a fixed,
  // short, predictable test regardless of whatever else might be queued.
  FSender.EnqueueGCode(Format('M3 S%d', [EdTestFirePower.Value]));
  FSender.EnqueueGCode('G4 P0.3');
  FSender.EnqueueGCode('M5');
  // Auto-disarm: every test fire requires a fresh, deliberate re-check of
  // the checkbox, not just repeated clicks on the button.
  ChkArmTestFire.Checked := False;
  SetStatus(T('Test fire sent'), False);
end;

procedure TLaserControlFrame.TrackFeedChange(Sender: TObject);
begin
  LblFeedValue.Caption := IntToStr(TrackFeed.Position) + '%';
  if FSender = nil then Exit;
  FSender.State.TargetOvFeed := TrackFeed.Position;
  FSender.State.OvChanged := True;
end;

procedure TLaserControlFrame.TrackSpindleChange(Sender: TObject);
begin
  LblSpindleValue.Caption := IntToStr(TrackSpindle.Position) + '%';
  if FSender = nil then Exit;
  FSender.State.TargetOvSpindle := TrackSpindle.Position;
  FSender.State.OvChanged := True;
end;

procedure TLaserControlFrame.RbRapidChange(Sender: TObject);
begin
  if FSender = nil then Exit;
  if RbRapid100.Checked then FSender.State.TargetOvRapid := 100
  else if RbRapid50.Checked then FSender.State.TargetOvRapid := 50
  else if RbRapid25.Checked then FSender.State.TargetOvRapid := 25;
  FSender.State.OvChanged := True;
end;

procedure TLaserControlFrame.RefreshState;
var
  progress: TLaserJobProgress;
  connected: Boolean;
begin
  connected := (FSender <> nil) and FSender.Connected;
  if FSender <> nil then
    progress := FSender.LaserJobProgress
  else
    progress.Active := False;

  if progress.Active then
    LblProgress.Caption := Format(T('Executed %d / Sent %d / Target %d'),
      [progress.Executed, progress.Sent, progress.Target])
  else
    LblProgress.Caption := '';

  BtnStart.Enabled := connected and not progress.Active;
  BtnPauseResume.Enabled := connected and progress.Active;
  BtnAbort.Enabled := connected and progress.Active;
  ChkArmTestFireChange(nil); // re-evaluate BtnTestFire.Enabled against the current connection state

  if not progress.Active then
  begin
    FIsPaused := False;
    BtnPauseResume.Caption := T('Pause');
  end;
end;

procedure TLaserControlFrame.ApplyMaterialPreset(const APreset: TMaterialPreset);
var
  i: Integer;
  commentLine: string;
begin
  if APreset.Passes > 0 then
    SpinPasses.Value := APreset.Passes;
  EdTestFirePower.Value := EnsureRange(Round(APreset.Power), EdTestFirePower.MinValue, EdTestFirePower.MaxValue);

  commentLine := Format('(Material: %s - Power S%g Speed F%g)',
    [APreset.Material, APreset.Power, APreset.Speed]);
  // Replace a prior preset-comment line if one is already there, so
  // re-applying a different preset doesn't pile up stale comments.
  for i := 0 to MemoHeader.Lines.Count - 1 do
    if Pos('(Material:', MemoHeader.Lines[i]) = 1 then
    begin
      MemoHeader.Lines[i] := commentLine;
      Exit;
    end;
  MemoHeader.Lines.Insert(0, commentLine);
end;

procedure TLaserControlFrame.RefreshMacroButtons;
var
  i: Integer;
  btn: TButton;
const
  BTN_WIDTH = 130;
  BTN_HEIGHT = 26;
  BTN_GAP = 6;
begin
  FButtons := FButtonStore.LoadAll;
  MacroPanel.DestroyComponents; // frees any TButtons created by a prior call
  for i := 0 to High(FButtons) do
  begin
    btn := TButton.Create(MacroPanel);
    btn.Parent := MacroPanel;
    btn.Caption := FButtons[i].Name;
    btn.Left := (i mod 4) * (BTN_WIDTH + BTN_GAP);
    btn.Top := (i div 4) * (BTN_HEIGHT + BTN_GAP);
    btn.Width := BTN_WIDTH;
    btn.Height := BTN_HEIGHT;
    btn.Tag := i;
    btn.OnClick := @MacroButtonClick;
  end;
end;

procedure TLaserControlFrame.MacroButtonClick(Sender: TObject);
var
  idx, i: Integer;
  lines: TStringList;
begin
  if FSender = nil then Exit;
  idx := TButton(Sender).Tag;
  if (idx < 0) or (idx > High(FButtons)) then Exit;
  lines := TStringList.Create;
  try
    lines.Text := FButtons[idx].GCode;
    for i := 0 to lines.Count - 1 do
      if Trim(lines[i]) <> '' then
        FSender.EnqueueGCode(lines[i]);
  finally
    lines.Free;
  end;
end;

procedure TLaserControlFrame.BtnEditMacrosClick(Sender: TObject);
begin
  if Assigned(FOnEditMacros) then FOnEditMacros(Self);
end;

end.
