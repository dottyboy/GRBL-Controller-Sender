unit umain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, Menus,
  usender, uappconfig, ugcode, uconnectframe, udroframe, ujogframe,
  uterminalframe, ueditorframe, usettingsform, uopengl3dframe,
  uprobeframe, utoolsframe, usettingsgridframe, ufluidncframe,
  ufirmwarebuilderframe, uspoilboardframe, ui18n, ui18ncontrols;

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
    procedure MenuFileExitClick(Sender: TObject);
    procedure MenuToolsSettingsClick(Sender: TObject);
    procedure MenuLangClick(Sender: TObject);
  private
    FSender: TSender;
    FAppConfig: TAppConfig;
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
    FLastFirmwareName: string; // tracks BoardInfo.FirmwareName so TabFluidNC
                                // is only rebuilt/toggled on an actual change
    procedure SenderLog(Sender: TObject; const ALine: string; IsError: Boolean);
    procedure SenderStateChanged(Sender: TObject);
    procedure ApplyConnectionDefaults;
    procedure CaptureConnectionDefaults;
    procedure View3DRequestParse(Sender: TObject);
    procedure SpoilboardGenerated(const AProgramText: string);
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
  // SetSender is used only by "Send Travel Limits" ($130/$131/$132) -
  // generating/loading g-code never touches the sender.
  SpoilboardFrame.SetSender(FSender);

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
  FGCodeParser.Free;
  FSender.Free;
end;

procedure TForm1.View3DRequestParse(Sender: TObject);
begin
  FGCodeParser.ParseLines(EditorFrame.SynEditor.Lines);
  View3DFrame.SetSegments(FGCodeParser.Segments, FGCodeParser.Count,
    FGCodeParser.MinX, FGCodeParser.MinY, FGCodeParser.MinZ,
    FGCodeParser.MaxX, FGCodeParser.MaxY, FGCodeParser.MaxZ);
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
end;

end.
