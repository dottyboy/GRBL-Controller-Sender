unit umain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, Dialogs, ComCtrls, Menus,
  StdCtrls, TplStatusBarExUnit, TplProgressBarUnit, rxclock, usender,
  uappconfig, ugcode, uconnectframe, udroframe, ujogframe, uterminalframe,
  ueditorframe, usettingsform, uopengl3dframe, uprobeframe, utoolsframe,
  usettingsgridframe, ufluidncframe, ufirmwarebuilderframe, uspoilboardframe,
  ui18n, ui18ncontrols, uhotkeys, ustatebuilder, uresumejobform,
  ulasercontrolframe, umaterialpreset, umaterialpresetframe, ucustombuttonframe,
  urasterimportframe, usvgimportframe, uhotkeysframe, ulasertestgenframe,
  ulaserusage, ulaserusagestore, ulaserusageform, usincrostart,
  uaxiscalibrationframe, ugerberimportframe, uwificonfigframe;

type

  { TMainForm }

  TMainForm = class(TForm)
    JobProgress: TProgressBar;
    JobStatusText: TLabel;
    MainMenu1: TMainMenu;
    MenuFile: TMenuItem;
    MenuFileExit: TMenuItem;
    MenuTools: TMenuItem;
    MenuToolsSettings: TMenuItem;
    MenuToolsLaserUsage: TMenuItem;
    MenuToolsAxisCalibration: TMenuItem;
    MenuLanguage: TMenuItem;
    MenuLangEN: TMenuItem;
    MenuLangHR: TMenuItem;
    MenuLangDE: TMenuItem;
    plStatusBarEx1: TplStatusBarEx;
    ProgressBar1: TProgressBar;
    RxClock1: TRxClock;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MenuFileExitClick(Sender: TObject);
    procedure MenuToolsSettingsClick(Sender: TObject);
    procedure MenuToolsLaserUsageClick(Sender: TObject);
    procedure MenuToolsAxisCalibrationClick(Sender: TObject);
    procedure MenuLangClick(Sender: TObject);
  private
    FSender: TSender;
    FAppConfig: TAppConfig;
    FHotkeyMap: THotkeyMap;
    FLaserUsageStore: TLaserUsageStore;
    FLaserUsageCounters: TLaserUsageCounterArray;
    FLaserUsageActiveGuid: string;
    FSincroStart: TSincroStartListener;
    FGCodeParser: TGCodeParser;
    // GUI reorganization ("razmisliti o tome ima li smisla??" - user
    // agreed to proceed, "vjerujemo tvom izboru"): 17 flat top-level tabs
    // no longer fit the tab bar without scrolling, so they're now grouped
    // into three outer tabs (Machine/Laser/Settings & Tools), each with
    // its own INNER TPageControl holding the original tab sheets
    // unchanged. GroupPages uses tpBottom (not tpLeft/tpRight) - LCL's
    // vertical tab rendering is inconsistent across widgetsets even
    // though this project currently only ships Qt5, and tpTop/tpBottom
    // are the most universally well-supported positions, matching the
    // actual reason Qt5 was chosen for this project in the first place
    // (reliable cross-platform rendering, not a Qt5-only bet).
    GroupPages: TPageControl;
    GroupMachine, GroupLaser, GroupSettings: TTabSheet;
    PagesMachine, PagesLaser, PagesSettings: TPageControl;
    TabControl: TTabSheet;
    TabEditor: TTabSheet;
    TabView3D: TTabSheet;
    TabProbe: TTabSheet;
    TabTools: TTabSheet;
    TabSettingsGrid: TTabSheet;
    TabFluidNC: TTabSheet;
    TabFirmwareBuilder: TTabSheet;
    TabSpoilboard: TTabSheet;
    TabGerberImport: TTabSheet;
    TabRasterImport: TTabSheet;
    TabSvgImport: TTabSheet;
    TabLaserTestGen: TTabSheet;
    TabLaserControl: TTabSheet;
    TabMaterials: TTabSheet;
    TabMacros: TTabSheet;
    TabHotkeys: TTabSheet;
    TabAxisCalibration: TTabSheet;
    TabTerminal: TTabSheet;
    TabWiFiConfig: TTabSheet;
    ConnectFrame: TConnectFrame;
    DROFrame: TDROFrame;
    JogFrame: TJogFrame;
    TerminalFrame: TTerminalFrame;
    WiFiConfigFrame: TWiFiConfigFrame;
    EditorFrame: TEditorFrame;
    View3DFrame: TOpenGL3DFrame;
    ProbeFrame: TProbeFrame;
    ToolsFrame: TToolsFrame;
    SettingsGridFrame: TSettingsGridFrame;
    FluidNCFrame: TFluidNCFrame;
    FirmwareBuilderFrame: TFirmwareBuilderFrame;
    SpoilboardFrame: TSpoilboardFrame;
    GerberImportFrame: TGerberImportFrame;
    RasterImportFrame: TRasterImportFrame;
    SvgImportFrame: TSvgImportFrame;
    LaserTestGenFrame: TLaserTestGenFrame;
    LaserControlFrame: TLaserControlFrame;
    MaterialPresetFrame: TMaterialPresetFrame;
    CustomButtonFrame: TCustomButtonFrame;
    HotkeysFrame: THotkeysFrame;
    AxisCalibrationFrame: TAxisCalibrationFrame;
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
    procedure WiFiConfigRequested(Sender: TObject);
    procedure WiFiDeviceSelected(const ADeviceString: string);
    procedure PagesChange(Sender: TObject);
    procedure ApplyConnectionDefaults;
    procedure CaptureConnectionDefaults;
    procedure View3DRequestParse(Sender: TObject);
    procedure SpoilboardGenerated(const AProgramText: string);
    procedure GerberImportGenerated(const AProgramText: string);
    procedure RasterGenerated(const AProgramText: string);
    procedure SvgGenerated(const AProgramText: string);
    procedure LaserTestGenGenerated(const AProgramText: string);
    procedure ApplyActiveLaserUsage;
    procedure StoreActiveLaserUsage;
    procedure SincroStartMessageReceived(const AMsg: TSincroStartMessage);
    // Plan Phase 38: wires the user's own hand-added status bar skeleton
    // (plStatusBarEx1/RxClock1/JobProgress/JobStatusText) to already-real
    // data this app already tracks - called from SenderStateChanged
    // (live, while connected/streaming) and once from FormCreate (so the
    // bar shows a sane "Not connected" state immediately, not blank).
    procedure UpdateStatusBar;
    procedure EditorFileChanged(Sender: TObject);
    // ActivateTab: switches to ATab regardless of which of the three
    // inner PageControls it lives in - flips GroupPages to the right
    // outer group first (derived from ATab.PageControl's own Parent,
    // never hardcoded per call site), then that inner PageControl to
    // ATab. Replaces every old "Pages.ActivePage := TabX" call site.
    procedure ActivateTab(ATab: TTabSheet);
  public

  end;

var
  MainForm: TMainForm;

implementation

{$R *.frm}

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
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

  // Plan Phase 20: load the persisted multi-laser usage/lifetime list and
  // point FSender.LaserUsage at whichever counter was last active - if
  // the store is empty (first run) or the saved active guid doesn't
  // match anything (e.g. it was deleted), seed one real default counter
  // and activate that, mirroring LaserGRBL's own CreateDefault-when-empty
  // behavior.
  FLaserUsageStore := TLaserUsageStore.Create(
    IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'laserusage.ini');
  FLaserUsageCounters := FLaserUsageStore.LoadAll;
  FLaserUsageActiveGuid := FLaserUsageStore.LoadActiveGuid;
  if Length(FLaserUsageCounters) = 0 then
  begin
    SetLength(FLaserUsageCounters, 1);
    FLaserUsageCounters[0] := CreateDefaultCounter;
    FLaserUsageActiveGuid := FLaserUsageCounters[0].Guid;
  end;
  ApplyActiveLaserUsage;

  GroupPages := TPageControl.Create(Self);
  GroupPages.Parent := Self;
  GroupPages.Align := alClient;
  GroupPages.TabPosition := tpBottom;

  GroupMachine := GroupPages.AddTabSheet;
  GroupMachine.Caption := 'Machine';
  GroupLaser := GroupPages.AddTabSheet;
  GroupLaser.Caption := 'Laser';
  GroupSettings := GroupPages.AddTabSheet;
  GroupSettings.Caption := 'Settings && Tools';

  PagesMachine := TPageControl.Create(GroupMachine);
  PagesMachine.Parent := GroupMachine;
  PagesMachine.Align := alClient;

  PagesLaser := TPageControl.Create(GroupLaser);
  PagesLaser.Parent := GroupLaser;
  PagesLaser.Align := alClient;

  PagesSettings := TPageControl.Create(GroupSettings);
  PagesSettings.Parent := GroupSettings;
  PagesSettings.Align := alClient;

  TabControl := PagesMachine.AddTabSheet;
  TabControl.Caption := 'Control';

  TabEditor := PagesMachine.AddTabSheet;
  TabEditor.Caption := 'Editor';

  TabView3D := PagesMachine.AddTabSheet;
  TabView3D.Caption := '3D View';

  TabProbe := PagesMachine.AddTabSheet;
  TabProbe.Caption := 'Probe';

  TabSpoilboard := PagesMachine.AddTabSheet;
  TabSpoilboard.Caption := 'Spoilboard';

  TabGerberImport := PagesMachine.AddTabSheet;
  TabGerberImport.Caption := 'Gerber Import';

  TabTerminal := PagesMachine.AddTabSheet;
  TabTerminal.Caption := 'Terminal';

  // Plan Phase 21, converted from a modal dialog to a plain tab in a
  // later session - same reasoning as TabAxisCalibration's own creation
  // comment (real, environment-level ShowModal crash in this X11/Qt5
  // setup, confirmed not a code regression - a tab sidesteps it).
  TabWiFiConfig := PagesMachine.AddTabSheet;
  TabWiFiConfig.Caption := 'WiFi Config';

  TabRasterImport := PagesLaser.AddTabSheet;
  TabRasterImport.Caption := 'Raster Import';

  TabSvgImport := PagesLaser.AddTabSheet;
  TabSvgImport.Caption := 'SVG / Vectorize';

  TabLaserTestGen := PagesLaser.AddTabSheet;
  TabLaserTestGen.Caption := 'Laser Test Patterns';

  TabLaserControl := PagesLaser.AddTabSheet;
  TabLaserControl.Caption := 'Laser Control';
  TabLaserControl.TabVisible := False; // shown only once BoardInfo.SupportLaserMode is known True

  TabMaterials := PagesLaser.AddTabSheet;
  TabMaterials.Caption := 'Materials';

  TabTools := PagesSettings.AddTabSheet;
  TabTools.Caption := 'Tools';

  TabSettingsGrid := PagesSettings.AddTabSheet;
  TabSettingsGrid.Caption := 'Settings ($$)';

  TabFluidNC := PagesSettings.AddTabSheet;
  TabFluidNC.Caption := 'FluidNC Config';
  TabFluidNC.TabVisible := False; // shown only once a FluidNC board is detected

  TabFirmwareBuilder := PagesSettings.AddTabSheet;
  TabFirmwareBuilder.Caption := 'Firmware Builder';

  TabMacros := PagesSettings.AddTabSheet;
  TabMacros.Caption := 'Macros';

  TabHotkeys := PagesSettings.AddTabSheet;
  TabHotkeys.Caption := 'Hotkeys';

  // Plan Phase 24, converted from a modal dialog to a plain tab in a
  // later session - this X11/Qt5 environment hit a real, reproducible
  // crash creating any second top-level window via ShowModal (confirmed
  // environment-level, not a code regression - reproduced even on an
  // already-shipped, long-working dialog via a genuine menu click, no
  // debug code involved at all). A tab sidesteps it entirely.
  TabAxisCalibration := PagesSettings.AddTabSheet;
  TabAxisCalibration.Caption := 'Axis Calibration';

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
  EditorFrame.OnCurrentFileChanged := @EditorFileChanged;

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

  // Plan Phase 33: CNC-milling-only (isolation routing needs a real tool
  // diameter/Z-depth, no laser equivalent), so it lives in the Machine
  // group alongside Spoilboard - same reasoning as that tab's own
  // placement in the reorg.
  GerberImportFrame := TGerberImportFrame.Create(TabGerberImport);
  GerberImportFrame.Parent := TabGerberImport;
  GerberImportFrame.OnGenerated := @GerberImportGenerated;

  RasterImportFrame := TRasterImportFrame.Create(TabRasterImport);
  RasterImportFrame.Parent := TabRasterImport;
  RasterImportFrame.OnGenerated := @RasterGenerated;

  SvgImportFrame := TSvgImportFrame.Create(TabSvgImport);
  SvgImportFrame.Parent := TabSvgImport;
  SvgImportFrame.OnGenerated := @SvgGenerated;

  LaserTestGenFrame := TLaserTestGenFrame.Create(TabLaserTestGen);
  LaserTestGenFrame.Parent := TabLaserTestGen;
  LaserTestGenFrame.OnGenerated := @LaserTestGenGenerated;
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

  AxisCalibrationFrame := TAxisCalibrationFrame.Create(TabAxisCalibration);
  AxisCalibrationFrame.Parent := TabAxisCalibration;
  AxisCalibrationFrame.SetSender(FSender);

  LaserControlFrame.OnEditMacros := @EditMacrosRequested;
  PagesLaser.OnChange := @PagesChange; // only TabLaserControl (see below) cares

  TerminalFrame := TTerminalFrame.Create(TabTerminal);
  TerminalFrame.Parent := TabTerminal;
  TerminalFrame.SetSender(FSender);

  WiFiConfigFrame := TWiFiConfigFrame.Create(TabWiFiConfig);
  WiFiConfigFrame.Parent := TabWiFiConfig;
  WiFiConfigFrame.SetSender(FSender);
  WiFiConfigFrame.OnDeviceSelected := @WiFiDeviceSelected;
  ConnectFrame.OnWiFiConfigRequested := @WiFiConfigRequested;

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

  // Plan Phase 22: SincroStart - external "start the loaded job" trigger
  // via a named FIFO, started last (after every frame it might dispatch
  // to already exists).
  FSincroStart := TSincroStartListener.Create;
  FSincroStart.StartListening(
    IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'sincrostart.fifo',
    @SincroStartMessageReceived);

  // Plan Phase 38, root-caused live: JobStatusText is a TLabel, i.e. a
  // TGraphicControl with no window of its own - it's painted directly onto
  // MainForm's canvas. plStatusBarEx1 is a real windowed TCustomControl
  // that physically covers the same screen rectangle (same Top/Height
  // band, full form width) and repaints its own window on every
  // Invalidate, which always wins over content the form painted
  // underneath it for an overlapping non-windowed sibling - so
  // JobStatusText could never render there no matter its Caption/Font.
  // JobProgress/RxClock1 are unaffected because they're real windowed
  // siblings too, and ordinary sibling-window Z-order works between
  // those. Fix: route the status text through plStatusBarEx1's own
  // Panels (confirmed-working DrawText rendering, same mechanism the
  // file-path SimpleText already used) instead of the label, and hide
  // the now-redundant label. Pure code, .frm left untouched.
  plStatusBarEx1.SimplePanel := False;
  with plStatusBarEx1.Panels.Add do
  begin
    Alignment := taLeftJustify;
    Spring := True;
  end;
  with plStatusBarEx1.Panels.Add do
  begin
    Alignment := taRightJustify;
    Width := 319;
  end;
  // Blank spacer panel, same width as the region JobProgress+RxClock1
  // physically occupy (Left=899 to the bar's own right edge, ~360px) -
  // without it, Panels[1]'s own rect would end up UNDER those two real
  // windowed siblings and get hidden by them the same way JobStatusText
  // was, just shifted into a different rectangle.
  with plStatusBarEx1.Panels.Add do
    Width := 360;
  JobStatusText.Visible := False;

  UpdateStatusBar;
end;

procedure TMainForm.ApplyConnectionDefaults;
begin
  if FAppConfig.LastPort <> '' then
    ConnectFrame.CboPort.Text := FAppConfig.LastPort;
  ConnectFrame.CboBaud.Text := IntToStr(FAppConfig.LastBaud);
  if (FAppConfig.LastControllerIndex >= 0) and
     (FAppConfig.LastControllerIndex < ConnectFrame.CboController.Items.Count) then
    ConnectFrame.CboController.ItemIndex := FAppConfig.LastControllerIndex;
end;

procedure TMainForm.CaptureConnectionDefaults;
begin
  FAppConfig.LastPort := ConnectFrame.CboPort.Text;
  FAppConfig.LastBaud := StrToIntDef(ConnectFrame.CboBaud.Text, 115200);
  FAppConfig.LastControllerIndex := ConnectFrame.CboController.ItemIndex;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FSincroStart.Free; // stops the listener thread (TSincroStartListener.Destroy calls StopListening)
  CaptureConnectionDefaults;
  FAppConfig.Save(FSender.State);
  FAppConfig.Free;
  FHotkeyMap.Save(IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'hotkeys.ini');
  FHotkeyMap.Free;
  // Plan Phase 20: merge the active counter's live, worker-thread-
  // accumulated stats back into the full list before it's persisted -
  // FSender.LaserUsage is the one TSenderThread has actually been
  // ticking, FLaserUsageCounters[...] is whatever stale copy was loaded
  // at startup. SaveActiveGuid must run AFTER SaveAll (see
  // ulaserusagestore.pas's own note - SaveAll rewrites the whole file).
  StoreActiveLaserUsage;
  FLaserUsageStore.SaveAll(FLaserUsageCounters);
  FLaserUsageStore.SaveActiveGuid(FLaserUsageActiveGuid);
  FLaserUsageStore.Free;
  FGCodeParser.Free;
  FSender.Free;
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
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

procedure TMainForm.View3DRequestParse(Sender: TObject);
begin
  FGCodeParser.ParseLines(EditorFrame.SynEditor.Lines);
  View3DFrame.SetSegments(FGCodeParser.Segments, FGCodeParser.Count,
    FGCodeParser.MinX, FGCodeParser.MinY, FGCodeParser.MinZ,
    FGCodeParser.MaxX, FGCodeParser.MaxY, FGCodeParser.MaxZ,
    FGCodeParser.MaxPower);
end;

procedure TMainForm.SpoilboardGenerated(const AProgramText: string);
begin
  // Loads into the editor exactly like opening a file by hand would - the
  // user reviews/edits/saves/sends it from there, this frame never touches
  // the sender directly. CurrentFile stays '' (unsaved) so Save/Save As
  // asks for a filename rather than silently overwriting whatever was open.
  EditorFrame.LoadGeneratedText(AProgramText);
  View3DRequestParse(Self);
  ActivateTab(TabView3D);
end;

procedure TMainForm.GerberImportGenerated(const AProgramText: string);
begin
  EditorFrame.LoadGeneratedText(AProgramText);
  View3DRequestParse(Self);
  ActivateTab(TabView3D);
end;

procedure TMainForm.RasterGenerated(const AProgramText: string);
begin
  EditorFrame.LoadGeneratedText(AProgramText);
  View3DRequestParse(Self);
  ActivateTab(TabView3D);
end;

procedure TMainForm.SvgGenerated(const AProgramText: string);
begin
  EditorFrame.LoadGeneratedText(AProgramText);
  View3DRequestParse(Self);
  ActivateTab(TabView3D);
end;

procedure TMainForm.LaserTestGenGenerated(const AProgramText: string);
begin
  EditorFrame.LoadGeneratedText(AProgramText);
  View3DRequestParse(Self);
  ActivateTab(TabView3D);
end;

// ApplyActiveLaserUsage: points FSender.LaserUsage (the one counter
// TSenderThread actually ticks) at whichever entry in FLaserUsageCounters
// matches FLaserUsageActiveGuid - falls back to the first counter if the
// guid isn't found (e.g. it was deleted via the Laser Usage dialog while
// it happened to still be marked active, or a fresh/corrupt store).
procedure TMainForm.ApplyActiveLaserUsage;
var
  i: Integer;
begin
  if Length(FLaserUsageCounters) = 0 then Exit;
  for i := 0 to High(FLaserUsageCounters) do
    if FLaserUsageCounters[i].Guid = FLaserUsageActiveGuid then
    begin
      FSender.LaserUsage := FLaserUsageCounters[i];
      Exit;
    end;
  FLaserUsageActiveGuid := FLaserUsageCounters[0].Guid;
  FSender.LaserUsage := FLaserUsageCounters[0];
end;

// StoreActiveLaserUsage: the inverse - writes FSender.LaserUsage's live,
// worker-thread-accumulated stats back into FLaserUsageCounters, so nothing
// ticked since the dialog was last opened (or since startup) gets lost
// when the list is next shown or saved.
procedure TMainForm.StoreActiveLaserUsage;
var
  i: Integer;
begin
  for i := 0 to High(FLaserUsageCounters) do
    if FLaserUsageCounters[i].Guid = FLaserUsageActiveGuid then
    begin
      FLaserUsageCounters[i] := FSender.LaserUsage;
      Exit;
    end;
end;

// SincroStartMessageReceived: mirrors LaserGRBL's real SincroStart.cs
// 3-way priority (CanSendFile->RunProgram / CanResumeHold->Resume /
// CanFeedHold->FeedHold) for the "START" tag, plus this project's own
// extended IMPORT_SVG/IMPORT_RASTER tags (see usincrostart.pas's own
// header for why/how). Called via Synchronize from the listener thread,
// so this runs safely on the main thread just like any button click.
procedure TMainForm.SincroStartMessageReceived(const AMsg: TSincroStartMessage);
begin
  case AMsg.Kind of
    sskStart:
      begin
        // Only sskStart needs a live connection - it drives the machine.
        // sskImportSvg/sskImportRaster (Phases 27-30's bridge plugins) are
        // pure "load this artwork into the import tab" actions, same as
        // File > Open, and must work before the user has even connected -
        // gating them on Connected here would make every design-then-
        // connect workflow silently drop the very first import.
        if not FSender.Connected then Exit;
        if not FSender.LaserJobProgress.Active then
          LaserControlFrame.BtnStartClick(Self)
        else if FSender.State.StateStr = 'Hold' then
          FSender.Resume
        else
          FSender.FeedHold;
      end;
    sskImportSvg:
      if FileExists(AMsg.Path) then
      begin
        SvgImportFrame.ImportFile(AMsg.Path);
        ActivateTab(TabSvgImport);
      end;
    sskImportRaster:
      if FileExists(AMsg.Path) then
      begin
        RasterImportFrame.ImportFile(AMsg.Path);
        ActivateTab(TabRasterImport);
      end;
  end;
end;

procedure TMainForm.MenuToolsLaserUsageClick(Sender: TObject);
begin
  StoreActiveLaserUsage;
  TLaserUsageForm.Execute(FLaserUsageCounters, FLaserUsageActiveGuid);
  ApplyActiveLaserUsage;
end;

procedure TMainForm.MenuToolsAxisCalibrationClick(Sender: TObject);
begin
  // Was a modal dialog (TAxisCalibrationForm.Execute) - now just jumps to
  // its own permanent tab, see TabAxisCalibration's own creation comment.
  ActivateTab(TabAxisCalibration);
end;

procedure TMainForm.MaterialPresetApply(const APreset: TMaterialPreset);
begin
  // Not gated on TabLaserControl.TabVisible (whether SupportLaserMode is
  // known True yet) - ApplyMaterialPreset only touches the frame's own
  // fields (Passes/Test-Fire-power/header comment), all safe to set on a
  // hidden tab the same as any other frame field, and it's exactly what a
  // user preparing a job before ever connecting would want to happen.
  LaserControlFrame.ApplyMaterialPreset(APreset);
  ActivateTab(TabLaserControl);
end;

procedure TMainForm.EditMacrosRequested(Sender: TObject);
begin
  ActivateTab(TabMacros);
end;

procedure TMainForm.WiFiConfigRequested(Sender: TObject);
begin
  ActivateTab(TabWiFiConfig);
end;

procedure TMainForm.WiFiDeviceSelected(const ADeviceString: string);
begin
  ConnectFrame.UseDeviceString(ADeviceString);
  ActivateTab(TabControl);
end;

procedure TMainForm.ActivateTab(ATab: TTabSheet);
begin
  if (ATab = nil) or (ATab.PageControl = nil) then Exit;
  // ATab.PageControl is one of PagesMachine/PagesLaser/PagesSettings, and
  // ITS OWN Parent is the outer GroupPages tab sheet (GroupMachine/
  // GroupLaser/GroupSettings) that hosts it - derived generically here so
  // this never needs updating if a tab is ever moved to a different
  // group later.
  if ATab.PageControl.Parent is TTabSheet then
    GroupPages.ActivePage := TTabSheet(ATab.PageControl.Parent);
  ATab.PageControl.ActivePage := ATab;
end;

procedure TMainForm.PagesChange(Sender: TObject);
begin
  // Picks up edits made on the Macros tab the moment the user switches back
  // to Laser Control - reactive-refresh, same reasoning as RefreshState's
  // own doc comment (avoids a dedicated poll/timer for something that only
  // needs to be current when actually shown).
  if PagesLaser.ActivePage = TabLaserControl then
    LaserControlFrame.RefreshMacroButtons;
end;

procedure TMainForm.MenuFileExitClick(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.MenuLangClick(Sender: TObject);
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

procedure TMainForm.MenuToolsSettingsClick(Sender: TObject);
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

procedure TMainForm.SenderLog(Sender: TObject; const ALine: string; IsError: Boolean);
begin
  TerminalFrame.AppendLine(ALine, IsError);
  // FluidNC doesn't fail a config.yaml upload on a bad key - it just logs
  // it and moves on, so a typo would otherwise go unnoticed (see Phase G's
  // plan note and ufluidncframe.pas's ReportIgnoredKey).
  if Pos('Ignored key', ALine) > 0 then
    FluidNCFrame.ReportIgnoredKey(ALine);
end;

procedure TMainForm.UpdateStatusBar;
var
  laserProg: TLaserJobProgress;
  progressPct: Integer;
  connText, progressText, stopText, fileText: string;
begin
  if FSender.Connected then connText := T('Connected') else connText := T('Disconnected');

  // Laser jobs keep their own, more precise Sent-vs-Executed(acked)
  // tracking (FSender.LaserJobProgress) - preferred when active. The
  // generic Phase 37/38 path (FSender.GenericJobActive/
  // GenericJobProgressFraction) covers plain CNC streaming from the
  // Editor tab, which has no equivalent execution-ack tracking of its
  // own, only "how much has gone out over the wire" - disclosed
  // difference, not silently presented as equally precise.
  laserProg := FSender.LaserJobProgress;
  progressPct := -1;
  if laserProg.Active and (laserProg.Target > 0) then
    progressPct := EnsureRange(Round(100 * laserProg.Executed / laserProg.Target), 0, 100)
  else if FSender.GenericJobActive and (FSender.GenericJobProgressFraction >= 0) then
    progressPct := EnsureRange(Round(100 * FSender.GenericJobProgressFraction), 0, 100);

  if progressPct >= 0 then
  begin
    JobProgress.Max := 100;
    JobProgress.Position := progressPct;
    progressText := Format('%d%%', [progressPct]);
  end
  else
  begin
    JobProgress.Position := 0;
    progressText := '-';
  end;

  if Pos('Alarm', FSender.State.StateStr) = 1 then
    stopText := 'STOP'
  else
    stopText := '-';

  plStatusBarEx1.Panels[1].Text := Format('%s / %s / %s / %s',
    [FSender.State.StateStr, connText, progressText, stopText]);

  if EditorFrame.CurrentFile = '' then
    fileText := T('(untitled)')
  else
    fileText := EditorFrame.CurrentFile;
  plStatusBarEx1.Panels[0].Text := fileText;
end;

procedure TMainForm.EditorFileChanged(Sender: TObject);
begin
  UpdateStatusBar;
end;

procedure TMainForm.SenderStateChanged(Sender: TObject);
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
  UpdateStatusBar;

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

procedure TMainForm.OfferLaserResume;
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
