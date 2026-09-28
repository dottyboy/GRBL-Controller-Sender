unit umain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, Menus,
  usender, uappconfig, ugcode, uconnectframe, udroframe, ujogframe,
  uterminalframe, ueditorframe, usettingsform, uopengl3dframe,
  uprobeframe, utoolsframe, usettingsgridframe, ufluidncframe,
  ufirmwarebuilderframe, uspoilboardframe, ui18n, ui18ncontrols, uhotkeys,
  ustatebuilder, uresumejobform, ulasercontrolframe, umaterialpreset,
  umaterialpresetframe, ucustombuttonframe, urasterimportframe,
  usvgimportframe, uhotkeysframe;

type

  { TForm1 }

  TForm1 = class(TForm)
    MainMenu1: TMainMenu;
    MenuFile: TMenuItem;
    MenuFileExit: TMenuItem;
    MenuTools: TMenuItem;
    MenuToolsSettings: TMenuItem;
    MenuLanguage: TMenuItem;
    MenuLangEN: TMenuItem;
    MenuLangHR: TMenuItem;
    MenuLangDE: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MenuFileExitClick(Sender: TObject);
    procedure MenuToolsSettingsClick(Sender: TObject);
    procedure MenuLangClick(Sender: TObject);
  private
    FSender: TSender;
    FAppConfig: TAppConfig;
    FHotkeyMap: THotkeyMap;
    FGCodeParser: TGCodeParser;
    Pages: TPageControl;
    TabControl: TTabSheet;
    TabEditor: TTabSheet;
    TabView3D: TTabSheet;
    TabProbe: TTabSheet;
    TabTools: TTabSheet;
    TabSettingsGrid: TTabSheet;
    TabFluidNC: TTabSheet;
    TabFirmwareBuilder: TTabSheet;
    TabSpoilboard: TTabSheet;
    TabRasterImport: TTabSheet;
    TabSvgImport: TTabSheet;
    TabLaserControl: TTabSheet;
    TabMaterials: TTabSheet;
    TabMacros: TTabSheet;
    TabHotkeys: TTabSheet;
    TabTerminal: TTabSheet;
    ConnectFrame: TConnectFrame;
    DROFrame: TDROFrame;
    JogFrame: TJogFrame;
    TerminalFrame: TTerminalFrame;
    EditorFrame: TEditorFrame;
    View3DFrame: TOpenGL3DFrame;
    ProbeFrame: TProbeFrame;
    ToolsFrame: TToolsFrame;
    SettingsGridFrame: TSettingsGridFrame;
    FluidNCFrame: TFluidNCFrame;
    FirmwareBuilderFrame: TFirmwareBuilderFrame;
    SpoilboardFrame: TSpoilboardFrame;
    RasterImportFrame: TRasterImportFrame;
    SvgImportFrame: TSvgImportFrame;
    LaserControlFrame: TLaserControlFrame;
    MaterialPresetFrame: TMaterialPresetFrame;
    CustomButtonFrame: TCustomButtonFrame;
    HotkeysFrame: THotkeysFrame;
    FLastFirmwareName: string; // tracks BoardInfo.FirmwareName so TabFluidNC
                                // is only rebuilt/toggled on an actual change
    // Plan Phase 9: tracks BoardInfo.SupportLaserMode so TabLaserControl is
    // only rebuilt/toggled on an actual change, same pattern as
    // FLastFirmwareName/TabFluidNC just above.
    FLastSupportLaserMode: Boolean;
    // Plan Phase 5: edge-trigger guard for the resume-from-position dialog -
    // True while the current Alarm has already been offered, so it doesn't
    // re-fire on every subsequent status poll while still in Alarm; reset
    // the moment StateStr leaves Alarm. See SenderStateChanged.
    FAlarmDialogArmed: Boolean;
    procedure SenderLog(Sender: TObject; const ALine: string; IsError: Boolean);
    procedure SenderStateChanged(Sender: TObject);
    procedure OfferLaserResume;
    procedure MaterialPresetApply(const APreset: TMaterialPreset);
    procedure EditMacrosRequested(Sender: TObject);
    procedure PagesChange(Sender: TObject);
    procedure ApplyConnectionDefaults;
    procedure CaptureConnectionDefaults;
    procedure View3DRequestParse(Sender: TObject);
    procedure SpoilboardGenerated(const AProgramText: string);
    procedure RasterGenerated(const AProgramText: string);
    procedure SvgGenerated(const AProgramText: string);
  public

  end;

var
  Form1: TForm1;

implementation

{$R *.frm}

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  FSender := TSender.Create;
  FSender.OnLog := @SenderLog;
  FSender.OnStateChanged := @SenderStateChanged;

  FAppConfig := TAppConfig.Create;
  FAppConfig.Load(FSender.State);
  FGCodeParser := TGCodeParser.Create;

  // Plan Phase 15 (scoped down this session - defaults only, no rebind
  // UI yet): loads a saved hotkeys.ini if one exists, else the built-in
  // defaults (LoadDefaults runs first inside Load either way).
  FHotkeyMap := THotkeyMap.Create;
  FHotkeyMap.Load(IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'hotkeys.ini');

  Pages := TPageControl.Create(Self);
  Pages.Parent := Self;
  Pages.Align := alClient;

  TabControl := Pages.AddTabSheet;
  TabControl.Caption := 'Control';

  TabEditor := Pages.AddTabSheet;
  TabEditor.Caption := 'Editor';

  TabView3D := Pages.AddTabSheet;
  TabView3D.Caption := '3D View';

  TabProbe := Pages.AddTabSheet;
  TabProbe.Caption := 'Probe';

  TabTools := Pages.AddTabSheet;
  TabTools.Caption := 'Tools';

  TabSettingsGrid := Pages.AddTabSheet;
  TabSettingsGrid.Caption := 'Settings ($$)';

  TabFluidNC := Pages.AddTabSheet;
  TabFluidNC.Caption := 'FluidNC Config';
  TabFluidNC.TabVisible := False; // shown only once a FluidNC board is detected

  TabFirmwareBuilder := Pages.AddTabSheet;
  TabFirmwareBuilder.Caption := 'Firmware Builder';

  TabSpoilboard := Pages.AddTabSheet;
  TabSpoilboard.Caption := 'Spoilboard';

  TabRasterImport := Pages.AddTabSheet;
  TabRasterImport.Caption := 'Raster Import';

  TabSvgImport := Pages.AddTabSheet;
  TabSvgImport.Caption := 'SVG / Vectorize';

  TabLaserControl := Pages.AddTabSheet;
  TabLaserControl.Caption := 'Laser Control';
  TabLaserControl.TabVisible := False; // shown only once BoardInfo.SupportLaserMode is known True

  TabMaterials := Pages.AddTabSheet;
  TabMaterials.Caption := 'Materials';

  TabMacros := Pages.AddTabSheet;
  TabMacros.Caption := 'Macros';

  TabHotkeys := Pages.AddTabSheet;
  TabHotkeys.Caption := 'Hotkeys';

  TabTerminal := Pages.AddTabSheet;
  TabTerminal.Caption := 'Terminal';

  ConnectFrame := TConnectFrame.Create(TabControl);
  ConnectFrame.Parent := TabControl;
  ConnectFrame.SetSender(FSender);

  JogFrame := TJogFrame.Create(TabControl);
  JogFrame.Parent := TabControl;
  JogFrame.SetSender(FSender);

  DROFrame := TDROFrame.Create(TabControl);
  DROFrame.Parent := TabControl;
  DROFrame.SetSender(FSender);

  EditorFrame := TEditorFrame.Create(TabEditor);
  EditorFrame.Parent := TabEditor;
  EditorFrame.SetSender(FSender);

  View3DFrame := TOpenGL3DFrame.Create(TabView3D);
  View3DFrame.Parent := TabView3D;
  View3DFrame.OnRequestParse := @View3DRequestParse;

  ProbeFrame := TProbeFrame.Create(TabProbe);
  ProbeFrame.Parent := TabProbe;
  ProbeFrame.SetSender(FSender);

  ToolsFrame := TToolsFrame.Create(TabTools);
  ToolsFrame.Parent := TabTools;
  ToolsFrame.SetSender(FSender);

  SettingsGridFrame := TSettingsGridFrame.Create(TabSettingsGrid);
  SettingsGridFrame.Parent := TabSettingsGrid;
  SettingsGridFrame.SetSender(FSender);

  FluidNCFrame := TFluidNCFrame.Create(TabFluidNC);
  FluidNCFrame.Parent := TabFluidNC;
  FluidNCFrame.SetSender(FSender);

  // No SetSender - board/firmware selection here is independent of
  // whatever's currently connected (or not connected at all).
  FirmwareBuilderFrame := TFirmwareBuilderFrame.Create(TabFirmwareBuilder);
  FirmwareBuilderFrame.Parent := TabFirmwareBuilder;

  SpoilboardFrame := TSpoilboardFrame.Create(TabSpoilboard);
  SpoilboardFrame.Parent := TabSpoilboard;
  SpoilboardFrame.OnGenerated := @SpoilboardGenerated;

  RasterImportFrame := TRasterImportFrame.Create(TabRasterImport);
  RasterImportFrame.Parent := TabRasterImport;
  RasterImportFrame.OnGenerated := @RasterGenerated;

  SvgImportFrame := TSvgImportFrame.Create(TabSvgImport);
  SvgImportFrame.Parent := TabSvgImport;
  SvgImportFrame.OnGenerated := @SvgGenerated;
  // SetSender is used only by "Send Travel Limits" ($130/$131/$132) -
  // generating/loading g-code never touches the sender.
  SpoilboardFrame.SetSender(FSender);

  LaserControlFrame := TLaserControlFrame.Create(TabLaserControl);
  LaserControlFrame.Parent := TabLaserControl;
  LaserControlFrame.SetSender(FSender);
  LaserControlFrame.SetAppConfig(FAppConfig);
  LaserControlFrame.SetEditorLines(EditorFrame.SynEditor.Lines);

  MaterialPresetFrame := TMaterialPresetFrame.Create(TabMaterials);
  MaterialPresetFrame.Parent := TabMaterials;
  MaterialPresetFrame.OnApply := @MaterialPresetApply;

  CustomButtonFrame := TCustomButtonFrame.Create(TabMacros);
  CustomButtonFrame.Parent := TabMacros;

  HotkeysFrame := THotkeysFrame.Create(TabHotkeys);
  HotkeysFrame.Parent := TabHotkeys;
  HotkeysFrame.SetHotkeyMap(FHotkeyMap);

  LaserControlFrame.OnEditMacros := @EditMacrosRequested;
  Pages.OnChange := @PagesChange;

  TerminalFrame := TTerminalFrame.Create(TabTerminal);
  TerminalFrame.Parent := TabTerminal;
  TerminalFrame.SetSender(FSender);

  ApplyConnectionDefaults;

  // Reflect config loaded above (e.g. a persisted GangedAxes) immediately -
  // otherwise the DRO's ganged-axis marker stays absent until the next real
  // state change (connect, or the Settings dialog closing), even though the
  // underlying TCNCState field was already loaded correctly.
  DROFrame.RefreshState;

  SetLanguage(LoadLanguageSetting);
  case CurrentLanguage of
    langHR: MenuLangHR.Checked := True;
    langDE: MenuLangDE.Checked := True;
  else
    MenuLangEN.Checked := True;
  end;
  TranslateControls(Self);
  TranslateMenu(MainMenu1.Items);
end;

procedure TForm1.ApplyConnectionDefaults;
begin
  if FAppConfig.LastPort <> '' then
    ConnectFrame.CboPort.Text := FAppConfig.LastPort;
  ConnectFrame.CboBaud.Text := IntToStr(FAppConfig.LastBaud);
  if (FAppConfig.LastControllerIndex >= 0) and
     (FAppConfig.LastControllerIndex < ConnectFrame.CboController.Items.Count) then
    ConnectFrame.CboController.ItemIndex := FAppConfig.LastControllerIndex;
end;

procedure TForm1.CaptureConnectionDefaults;
begin
  FAppConfig.LastPort := ConnectFrame.CboPort.Text;
  FAppConfig.LastBaud := StrToIntDef(ConnectFrame.CboBaud.Text, 115200);
  FAppConfig.LastControllerIndex := ConnectFrame.CboController.ItemIndex;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  CaptureConnectionDefaults;
  FAppConfig.Save(FSender.State);
  FAppConfig.Free;
  FHotkeyMap.Save(IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'hotkeys.ini');
  FHotkeyMap.Free;
  FGCodeParser.Free;
  FSender.Free;
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  hkAction: THotkeyAction;
  stepXY, stepZ: Double;
begin
  // Plan Phase 15: while the Hotkeys tab is waiting for a new key (after
  // "Rebind Selected"), the NEXT keydown anywhere in the app is the new
  // binding, not a normal hotkey trigger - checked first, before the
  // regular dispatch below, and consumes the key either way.
  if HotkeysFrame.IsCapturing then
  begin
    HotkeysFrame.CaptureKeyPress(Key, ssShift in Shift, ssCtrl in Shift, ssAlt in Shift);
    Key := 0;
    Exit;
  end;

  hkAction := FHotkeyMap.Find(Key, ssShift in Shift, ssCtrl in Shift, ssAlt in Shift);
  if hkAction = haNone then Exit;
  if FSender = nil then Exit;

  stepXY := StrToFloatDef(JogFrame.CboStep.Text, 1.0);
  stepZ := StrToFloatDef(JogFrame.CboStepZ.Text, 1.0);

  // Mirrors ujogframe.pas's own click handlers exactly (including not
  // guarding on FSender.Connected - jog/control buttons already queue
  // harmlessly while disconnected, so a hotkey does the same, not more).
  case hkAction of
    haJogXPlus:  FSender.Jog(Format('X%g', [stepXY]));
    haJogXMinus: FSender.Jog(Format('X-%g', [stepXY]));
    haJogYPlus:  FSender.Jog(Format('Y%g', [stepXY]));
    haJogYMinus: FSender.Jog(Format('Y-%g', [stepXY]));
    haJogZPlus:  FSender.Jog(Format('Z%g', [stepZ]));
    haJogZMinus: FSender.Jog(Format('Z-%g', [stepZ]));
    haJogNE:     FSender.Jog(Format('X%gY%g', [stepXY, stepXY]));
    haJogNW:     FSender.Jog(Format('X-%gY%g', [stepXY, stepXY]));
    haJogSE:     FSender.Jog(Format('X%gY-%g', [stepXY, stepXY]));
    haJogSW:     FSender.Jog(Format('X-%gY-%g', [stepXY, stepXY]));
    haJogStepIncrease:
      if JogFrame.CboStep.ItemIndex < JogFrame.CboStep.Items.Count - 1 then
        JogFrame.CboStep.ItemIndex := JogFrame.CboStep.ItemIndex + 1;
    haJogStepDecrease:
      if JogFrame.CboStep.ItemIndex > 0 then
        JogFrame.CboStep.ItemIndex := JogFrame.CboStep.ItemIndex - 1;
    haHome:      FSender.Home;
    haUnlock:    FSender.Unlock;
    haFeedHold:  FSender.FeedHold;
    haResume:    FSender.Resume;
    haSoftReset: FSender.SoftReset;
  end;

  Key := 0; // handled - don't also deliver it to whatever control has focus
end;

procedure TForm1.View3DRequestParse(Sender: TObject);
begin
  FGCodeParser.ParseLines(EditorFrame.SynEditor.Lines);
  View3DFrame.SetSegments(FGCodeParser.Segments, FGCodeParser.Count,
    FGCodeParser.MinX, FGCodeParser.MinY, FGCodeParser.MinZ,
    FGCodeParser.MaxX, FGCodeParser.MaxY, FGCodeParser.MaxZ,
    FGCodeParser.MaxPower);
end;

procedure TForm1.SpoilboardGenerated(const AProgramText: string);
begin
  // Loads into the editor exactly like opening a file by hand would - the
  // user reviews/edits/saves/sends it from there, this frame never touches
  // the sender directly. CurrentFile stays '' (unsaved) so Save/Save As
  // asks for a filename rather than silently overwriting whatever was open.
  EditorFrame.LoadGeneratedText(AProgramText);
  View3DRequestParse(Self);
  Pages.ActivePage := TabView3D;
end;

procedure TForm1.RasterGenerated(const AProgramText: string);
begin
  EditorFrame.LoadGeneratedText(AProgramText);
  View3DRequestParse(Self);
  Pages.ActivePage := TabView3D;
end;

procedure TForm1.SvgGenerated(const AProgramText: string);
begin
  EditorFrame.LoadGeneratedText(AProgramText);
  View3DRequestParse(Self);
  Pages.ActivePage := TabView3D;
end;

procedure TForm1.MaterialPresetApply(const APreset: TMaterialPreset);
begin
  // Not gated on TabLaserControl.TabVisible (whether SupportLaserMode is
  // known True yet) - ApplyMaterialPreset only touches the frame's own
  // fields (Passes/Test-Fire-power/header comment), all safe to set on a
  // hidden tab the same as any other frame field, and it's exactly what a
  // user preparing a job before ever connecting would want to happen.
  LaserControlFrame.ApplyMaterialPreset(APreset);
  Pages.ActivePage := TabLaserControl;
end;

procedure TForm1.EditMacrosRequested(Sender: TObject);
begin
  Pages.ActivePage := TabMacros;
end;

procedure TForm1.PagesChange(Sender: TObject);
begin
  // Picks up edits made on the Macros tab the moment the user switches back
  // to Laser Control - reactive-refresh, same reasoning as RefreshState's
  // own doc comment (avoids a dedicated poll/timer for something that only
  // needs to be current when actually shown).
  if Pages.ActivePage = TabLaserControl then
    LaserControlFrame.RefreshMacroButtons;
end;

procedure TForm1.MenuFileExitClick(Sender: TObject);
begin
  Close;
end;

procedure TForm1.MenuLangClick(Sender: TObject);
var
  newLang: TAppLanguage;
begin
  case TMenuItem(Sender).Tag of
    1: newLang := langHR;
    2: newLang := langDE;
  else
    newLang := langEN;
  end;
  SetLanguage(newLang);
  SaveLanguageSetting(newLang);
  TranslateControls(Self);
  TranslateMenu(MainMenu1.Items);
end;

procedure TForm1.MenuToolsSettingsClick(Sender: TObject);
var
  dlg: TSettingsForm;
begin
  dlg := TSettingsForm.Create(Self);
  try
    dlg.LoadFromState(FSender.State);
    if dlg.ShowModal = mrOK then
    begin
      dlg.SaveToState(FSender.State);
      DROFrame.RefreshState; // e.g. ganged-axis markers need to reflect immediately
    end;
  finally
    dlg.Free;
  end;
end;

procedure TForm1.SenderLog(Sender: TObject; const ALine: string; IsError: Boolean);
begin
  TerminalFrame.AppendLine(ALine, IsError);
  // FluidNC doesn't fail a config.yaml upload on a bad key - it just logs
  // it and moves on, so a typo would otherwise go unnoticed (see Phase G's
  // plan note and ufluidncframe.pas's ReportIgnoredKey).
  if Pos('Ignored key', ALine) > 0 then
    FluidNCFrame.ReportIgnoredKey(ALine);
end;

procedure TForm1.SenderStateChanged(Sender: TObject);
var
  progress: TLaserJobProgress;
  isAlarm: Boolean;
begin
  DROFrame.SetAxisConfig(FSender.State.BoardInfo.AxisLetters);
  JogFrame.SetAxisConfig(FSender.State.BoardInfo.AxisLetters);
  DROFrame.RefreshState;
  ConnectFrame.RefreshState;

  if FSender.State.BoardInfo.FirmwareName <> FLastFirmwareName then
  begin
    FLastFirmwareName := FSender.State.BoardInfo.FirmwareName;
    TabFluidNC.TabVisible := FLastFirmwareName = 'FluidNC';
  end;

  if FSender.State.BoardInfo.SupportLaserMode <> FLastSupportLaserMode then
  begin
    FLastSupportLaserMode := FSender.State.BoardInfo.SupportLaserMode;
    TabLaserControl.TabVisible := FLastSupportLaserMode;
  end;
  LaserControlFrame.RefreshState;

  // Plan Phase 5: crash-recovery prompt, edge-triggered on the transition
  // INTO Alarm (FAlarmDialogArmed guards repeats while still in Alarm; an
  // alarm with no active-and-unfinished laser job to resume - e.g. one
  // triggered by manual jogging - is correctly left alone). No separate
  // forced M5 here before the dialog: grbl itself rejects ordinary g-code
  // with error:9 (locked) while in Alarm until $X/$H, so an M5 sent from
  // here wouldn't reach the laser any sooner than grbl's own Alarm entry
  // already should have. Note this call chain runs on the UI thread via
  // TSenderThread.Execute's Synchronize (see FlushToUI) - ShowModal below
  // blocks that Synchronize call, so the serial read/write loop pauses for
  // as long as the dialog is open. Acceptable here: the machine is already
  // halted (Alarm) and grbl won't act on further commands until $X/$H
  // anyway, so nothing time-sensitive is being delayed.
  isAlarm := Pos('ALARM', FSender.State.StateStr) = 1;
  progress := FSender.LaserJobProgress;
  if isAlarm and not FAlarmDialogArmed and progress.Active and
     (progress.Executed < progress.Target) then
  begin
    FAlarmDialogArmed := True;
    OfferLaserResume;
  end
  else if not isAlarm then
    FAlarmDialogArmed := False;
end;

procedure TForm1.OfferLaserResume;
var
  progress: TLaserJobProgress;
  cause: string;
  resumeLine: Integer;
  opts: TResumeOptions;
  hasWCO: Boolean;
begin
  progress := FSender.LaserJobProgress;
  if FSender.State.ErrLine <> '' then
    cause := FSender.State.ErrLine
  else
    cause := T('Unexpected Alarm during laser job');

  hasWCO := (FSender.State.WCOX <> 0) or (FSender.State.WCOY <> 0) or (FSender.State.WCOZ <> 0);

  if TResumeJobForm.Execute(progress.Executed, progress.Sent, progress.Target, cause,
       hasWCO, FSender.State.WCOX, FSender.State.WCOY, FSender.State.WCOZ,
       resumeLine, opts) then
    FSender.ResumeLaserJob(resumeLine, opts)
  else
    FSender.EndLaserJob; // declined - stop tracking a job that won't be resumed
end;

end.
