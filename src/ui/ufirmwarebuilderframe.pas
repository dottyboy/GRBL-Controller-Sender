unit ufirmwarebuilderframe;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, StrUtils, Forms, Controls, StdCtrls, ExtCtrls, Grids, Dialogs,
  CheckLst, Spin,
  ufirmwareboards, ufirmwaremodules, ufirmwarebuildconfig, ufirmwaresetupstore, uprocessrunner,
  uportlist, ui18n;

const
  // The only real, verified PlatformIO-buildable grblHAL driver families
  // (see ufirmwareboards.pas / project notes) - the other 16 real driver
  // repos under References/ use CMake or vendor-IDE-only project files, not
  // platformio.ini, so ScanGrblHALEnvironments correctly finds 0 envs for
  // them; no point re-scanning them here every refresh.
  GRBLHAL_FAMILIES: array[0..2] of string = ('stm32f1xx', 'stm32f4xx', 'esp32');

type

  { TFirmwareBuilderFrame: board picker + dual-drive axis config + named
    setups + Generate/Build/Upload (Phase: Firmware Builder). All the real
    logic lives in ufirmwareboards.pas/ufirmwarebuildconfig.pas/
    ufirmwaresetupstore.pas/uprocessrunner.pas, already verified standalone
    against real repos and real `pio` compiles - this frame is the GUI
    plumbing over that, following the same TFrame+.lfm pattern as every
    other tab in this app. }
  TFirmwareBuilderFrame = class(TFrame)
    BtnAddAxis: TButton;
    BtnBuild: TButton;
    BtnDeleteSetup: TButton;
    BtnGenerate: TButton;
    BtnLoadSetup: TButton;
    BtnRefreshBoards: TButton;
    BtnRefreshPorts: TButton;
    BtnRemoveAxis: TButton;
    BtnSaveSetup: TButton;
    BtnUpload: TButton;
    CboAxisLetter: TComboBox;
    CboBoard: TComboBox;
    CboEcosystem: TComboBox;
    CboPort: TComboBox;
    CboSetups: TComboBox;
    CheckListModules: TCheckListBox;
    EdEncDirPin: TSpinEdit;
    EdEncPulsePin: TSpinEdit;
    EdSetupName: TEdit;
    GridAxes: TStringGrid;
    LblAxisLetter: TLabel;
    LblBoard: TLabel;
    LblEcosystem: TLabel;
    LblEncDirPin: TLabel;
    LblEncPulsePin: TLabel;
    LblGeneratedPath: TLabel;
    LblModules: TLabel;
    LblPort: TLabel;
    LblSetupName: TLabel;
    MemoLog: TMemo;
    ToolBarBoard: TPanel;
    ToolBarAxes: TPanel;
    ToolBarModules: TPanel;
    ToolBarSetup: TPanel;
    ToolBarActions: TPanel;
    procedure BtnAddAxisClick(Sender: TObject);
    procedure BtnBuildClick(Sender: TObject);
    procedure BtnDeleteSetupClick(Sender: TObject);
    procedure BtnGenerateClick(Sender: TObject);
    procedure BtnLoadSetupClick(Sender: TObject);
    procedure BtnRefreshBoardsClick(Sender: TObject);
    procedure BtnRefreshPortsClick(Sender: TObject);
    procedure BtnRemoveAxisClick(Sender: TObject);
    procedure BtnSaveSetupClick(Sender: TObject);
    procedure BtnUploadClick(Sender: TObject);
    procedure CboBoardChange(Sender: TObject);
    procedure CboEcosystemChange(Sender: TObject);
    procedure CheckListModulesClickCheck(Sender: TObject);
    procedure EdEncPulsePinChange(Sender: TObject);
    procedure EdEncDirPinChange(Sender: TObject);
  private
    FRefsRoot: string; // absolute path to References/
    FEnvs: TBoardEnvArray;
    FModuleListIds: array of TFirmwareModuleId; // parallel to CheckListModules.Items
    FSetup: TFirmwareSetup;
    FStore: TFirmwareSetupStore;
    FBuildRunner: TProcessRunner;
    FUploadRunner: TProcessRunner;
    FGeneratedDir: string;
    FPioExe: string;
    procedure RefreshBoardsList;
    procedure RefreshAxesGrid;
    procedure RefreshModulesList;
    procedure LogControlSwitchReport;
    procedure RefreshSetupsList;
    function CurrentEnvIndex: Integer;
    procedure LogLine(const AMsg: string);
    procedure OnProcOutput(Sender: TObject; const ALine: string);
    procedure OnBuildDone(Sender: TObject; AExitCode: Integer);
    procedure OnUploadDone(Sender: TObject; AExitCode: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

{$R *.frm}

{ TFirmwareBuilderFrame }

constructor TFirmwareBuilderFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  // Real on-disk directory is lowercase 'references/' (see the .gitignore
  // casing fix of the same name) - Linux is case-sensitive, so the old
  // 'References' here silently found 0 boards even with real uCNC/grblHAL
  // checkouts present.
  FRefsRoot := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'references' + PathDelim;
  FPioExe := ExpandFileName('~/.local/bin/pio');
  FSetup := TFirmwareSetup.Create;
  FStore := TFirmwareSetupStore.Create;
  FBuildRunner := TProcessRunner.Create;
  FBuildRunner.OnOutput := @OnProcOutput;
  FBuildRunner.OnDone := @OnBuildDone;
  FUploadRunner := TProcessRunner.Create;
  FUploadRunner.OnOutput := @OnProcOutput;
  FUploadRunner.OnDone := @OnUploadDone;

  CboEcosystem.Items.Clear;
  CboEcosystem.Items.Add('uCNC');
  CboEcosystem.Items.Add('grblHAL');
  CboEcosystem.ItemIndex := 0;

  CboAxisLetter.Items.Clear;
  CboAxisLetter.Items.Add('X');
  CboAxisLetter.Items.Add('Y');
  CboAxisLetter.Items.Add('Z');
  CboAxisLetter.ItemIndex := 1; // Y is the common case

  GridAxes.ColCount := 3;
  GridAxes.RowCount := 1;
  GridAxes.Cells[0, 0] := 'Axis';
  GridAxes.Cells[1, 0] := 'Motor slot';
  GridAxes.Cells[2, 0] := 'Limit slot';

  EdEncPulsePin.Value := FSetup.EncoderPulsePin;
  EdEncDirPin.Value := FSetup.EncoderDirPin;

  RefreshBoardsList;
  RefreshSetupsList;
  BtnRefreshPortsClick(Self);
end;

destructor TFirmwareBuilderFrame.Destroy;
begin
  FUploadRunner.Free;
  FBuildRunner.Free;
  FStore.Free;
  FSetup.Free;
  inherited Destroy;
end;

procedure TFirmwareBuilderFrame.LogLine(const AMsg: string);
begin
  MemoLog.Lines.Add(AMsg);
  MemoLog.SelStart := Length(MemoLog.Text);
  MemoLog.SelLength := 0;
end;

procedure TFirmwareBuilderFrame.OnProcOutput(Sender: TObject; const ALine: string);
begin
  LogLine(ALine);
end;

procedure TFirmwareBuilderFrame.RefreshBoardsList;
var
  i: Integer;
  grblEnvs: TBoardEnvArray;
  fam: string;
begin
  CboBoard.Items.Clear;
  if CboEcosystem.ItemIndex = 0 then
    FEnvs := ScanUCNCEnvironments(FRefsRoot + 'uCNC')
  else
  begin
    SetLength(FEnvs, 0);
    for fam in GRBLHAL_FAMILIES do
    begin
      grblEnvs := ScanGrblHALEnvironments(FRefsRoot + 'grblHAL-driver-' + fam, fam);
      for i := 0 to High(grblEnvs) do
      begin
        SetLength(FEnvs, Length(FEnvs) + 1);
        FEnvs[High(FEnvs)] := grblEnvs[i];
      end;
    end;
  end;

  for i := 0 to High(FEnvs) do
    CboBoard.Items.Add(FEnvs[i].Family + ': ' + FEnvs[i].EnvName);
  if CboBoard.Items.Count > 0 then CboBoard.ItemIndex := 0;

  LogLine(Format('%d board(s) found for %s', [Length(FEnvs), CboEcosystem.Text]));
  if CboEcosystem.ItemIndex = 1 then
    LogLine('Note: grblHAL already supports M62-M65 relay/digital-output control as a core ' +
      'feature (grbl/gcode.c) on any AUXOUTPUTn pin the board has free - no build config ' +
      'needed, unlike uCNC. Check the board''s own map file for spare AUXOUTPUTn pins.');
  RefreshModulesList;
  LogControlSwitchReport;
end;

// Populates CheckListModules from the modules real for the current
// ecosystem, checked against FSetup's current selection and, per-item,
// enabled/disabled against the currently selected board's own real map
// file content (see ufirmwaremodules.pas's ModuleAvailableForBoard -
// e.g. a grblHAL encoder is only offered when the board already breaks
// out QEI pins).
procedure TFirmwareBuilderFrame.RefreshModulesList;
var
  ids: TFirmwareModuleIdArray;
  info: TModuleInfo;
  eco: TFirmwareEcosystem;
  idx, i: Integer;
  available: Boolean;
  itemCaption: string;
begin
  eco := fwUCNC;
  if CboEcosystem.ItemIndex = 1 then eco := fwGrblHAL;
  ids := ModulesForEcosystem(eco);

  CheckListModules.Items.BeginUpdate;
  try
    CheckListModules.Items.Clear;
    SetLength(FModuleListIds, Length(ids));
    idx := CurrentEnvIndex;

    for i := 0 to High(ids) do
    begin
      info := GetModuleInfo(ids[i]);
      FModuleListIds[i] := ids[i];

      available := True;
      if idx >= 0 then
        available := ModuleAvailableForBoard(ids[i], FEnvs[idx]);

      itemCaption := info.DisplayName;
      if not available then
        itemCaption := itemCaption + ' (not available on this board)';

      CheckListModules.Items.Add(itemCaption);
      CheckListModules.ItemEnabled[i] := available;
      CheckListModules.Checked[i] := available and FSetup.HasBoardEnv and
        (idx >= 0) and (FSetup.BoardEnv.EnvName = FEnvs[idx].EnvName) and
        FSetup.HasModule(ids[i]);
    end;
  finally
    CheckListModules.Items.EndUpdate;
  end;

  EdEncPulsePin.Enabled := (eco = fwUCNC);
  EdEncDirPin.Enabled := (eco = fwUCNC);
end;

function TFirmwareBuilderFrame.CurrentEnvIndex: Integer;
begin
  Result := CboBoard.ItemIndex;
  if (Result < 0) or (Result > High(FEnvs)) then Result := -1;
end;

procedure TFirmwareBuilderFrame.RefreshAxesGrid;
var
  i: Integer;
  a: TDualDriveAxis;
begin
  GridAxes.RowCount := Max(2, FSetup.AxisCount + 1);
  for i := 0 to FSetup.AxisCount - 1 do
  begin
    a := FSetup.AxisAt(i);
    GridAxes.Cells[0, i + 1] := a.AxisLetter;
    GridAxes.Cells[1, i + 1] := a.MotorSlot;
    GridAxes.Cells[2, i + 1] := a.LimitSlot;
  end;
  for i := FSetup.AxisCount to GridAxes.RowCount - 2 do
  begin
    GridAxes.Cells[0, i + 1] := '';
    GridAxes.Cells[1, i + 1] := '';
    GridAxes.Cells[2, i + 1] := '';
  end;
end;

procedure TFirmwareBuilderFrame.RefreshSetupsList;
var
  names: TStringList;
begin
  names := TStringList.Create;
  try
    FStore.ListSetupNames(names);
    CboSetups.Items.Assign(names);
  finally
    names.Free;
  end;
end;

procedure TFirmwareBuilderFrame.CboEcosystemChange(Sender: TObject);
begin
  RefreshBoardsList;
end;

procedure TFirmwareBuilderFrame.CboBoardChange(Sender: TObject);
begin
  RefreshModulesList; // a different board can change which modules are hardware-available
  LogControlSwitchReport;
end;

// Read-only report (see ufirmwareboards.pas's DescribeControlSwitches) -
// many boards already have hold/resume/stop switches wired by default,
// this just makes that visible without opening the raw board map file.
// Deliberately does not offer to activate anything - these are safety-
// critical pins, left as a manual, deliberate edit outside this tool.
procedure TFirmwareBuilderFrame.LogControlSwitchReport;
var
  idx: Integer;
  bm: TBoardMap;
  f: TStringList;
begin
  idx := CurrentEnvIndex;
  if idx < 0 then Exit;
  f := TStringList.Create;
  bm := TBoardMap.Create(FEnvs[idx].Ecosystem);
  try
    f.LoadFromFile(FEnvs[idx].RepoDir + '/' + FEnvs[idx].MapFilePath);
    bm.ParseFile(f.Text);
    LogLine('Control switches (hold/resume/stop): ' + bm.DescribeControlSwitches);
  finally
    bm.Free;
    f.Free;
  end;
end;

procedure TFirmwareBuilderFrame.BtnRefreshBoardsClick(Sender: TObject);
begin
  RefreshBoardsList;
end;

// Syncs FSetup's module selection to whatever's currently checked in
// CheckListModules - rebuilt wholesale rather than diffed by index, since
// TCheckListBox's OnClickCheck is a bare TNotifyEvent with no index
// parameter and by the time it fires the widget's own Checked[] state is
// already updated, so this is simpler and just as correct.
procedure TFirmwareBuilderFrame.CheckListModulesClickCheck(Sender: TObject);
var
  idx, i: Integer;
begin
  idx := CurrentEnvIndex;
  if idx < 0 then Exit;
  if not FSetup.HasBoardEnv or (FSetup.BoardEnv.EnvName <> FEnvs[idx].EnvName) then
    FSetup.SetBoardEnv(FEnvs[idx]);

  for i := 0 to High(FModuleListIds) do
    if CheckListModules.ItemEnabled[i] then
      FSetup.SetModuleEnabled(FModuleListIds[i], CheckListModules.Checked[i]);
end;

procedure TFirmwareBuilderFrame.EdEncPulsePinChange(Sender: TObject);
begin
  FSetup.EncoderPulsePin := EdEncPulsePin.Value;
end;

procedure TFirmwareBuilderFrame.EdEncDirPinChange(Sender: TObject);
begin
  FSetup.EncoderDirPin := EdEncDirPin.Value;
end;

procedure TFirmwareBuilderFrame.BtnAddAxisClick(Sender: TObject);
var
  idx: Integer;
  bm: TBoardMap;
  f: TStringList;
  a: TDualDriveAxis;
  letter: Char;
  motorSlot, limitSlot: string;
begin
  idx := CurrentEnvIndex;
  if idx < 0 then
  begin
    LogLine('Pick a board first.');
    Exit;
  end;
  if CboAxisLetter.Text = '' then Exit;
  letter := CboAxisLetter.Text[1];

  f := TStringList.Create;
  bm := TBoardMap.Create(FEnvs[idx].Ecosystem);
  try
    f.LoadFromFile(FEnvs[idx].RepoDir + '/' + FEnvs[idx].MapFilePath);
    bm.ParseFile(f.Text);
    motorSlot := bm.FindFreeMotorSlot;
    if motorSlot = '' then
    begin
      LogLine('No free motor slot on this board - it may already use all its extra motor headers, or not break any out.');
      Exit;
    end;
    if FEnvs[idx].Ecosystem = fwUCNC then
    begin
      limitSlot := bm.FindFreeLimitSlot(letter);
      if limitSlot = '' then
      begin
        LogLine('Found a free motor slot (' + motorSlot + ') but no free LIMIT_' + letter + '2 slot on this board.');
        Exit;
      end;
    end
    else
      limitSlot := ''; // grblHAL bundles the limit pin into the motor slot itself
  finally
    bm.Free;
    f.Free;
  end;

  a.AxisLetter := letter;
  a.MotorSlot := motorSlot;
  a.LimitSlot := limitSlot;
  if not FSetup.HasBoardEnv or (FSetup.BoardEnv.EnvName <> FEnvs[idx].EnvName) then
    FSetup.SetBoardEnv(FEnvs[idx]);
  FSetup.SetAxis(a);
  RefreshAxesGrid;
  LogLine(Format('Added dual-drive %s: motor %s%s', [letter, motorSlot,
    IfThen(limitSlot <> '', ', limit ' + limitSlot, '')]));
end;

procedure TFirmwareBuilderFrame.BtnRemoveAxisClick(Sender: TObject);
var
  row: Integer;
begin
  row := GridAxes.Row;
  if row < 1 then Exit;
  FSetup.RemoveAxis(row - 1);
  RefreshAxesGrid;
end;

procedure TFirmwareBuilderFrame.BtnSaveSetupClick(Sender: TObject);
begin
  if Trim(EdSetupName.Text) = '' then
  begin
    LogLine('Enter a setup name first.');
    Exit;
  end;
  if not FSetup.HasBoardEnv then
  begin
    LogLine('Pick a board and configure at least one axis first.');
    Exit;
  end;
  FStore.Save(Trim(EdSetupName.Text), FSetup);
  RefreshSetupsList;
  LogLine('Saved setup "' + Trim(EdSetupName.Text) + '".');
end;

procedure TFirmwareBuilderFrame.BtnLoadSetupClick(Sender: TObject);
var
  saved: TSavedSetup;
  i, foundIdx: Integer;
begin
  if CboSetups.Text = '' then Exit;
  if not FStore.Load(CboSetups.Text, saved) then
  begin
    LogLine('Could not load setup "' + CboSetups.Text + '".');
    Exit;
  end;

  if saved.Ecosystem = fwUCNC then
    CboEcosystem.ItemIndex := 0
  else
    CboEcosystem.ItemIndex := 1;
  RefreshBoardsList; // repopulates FEnvs for the ecosystem set above

  foundIdx := -1;
  for i := 0 to High(FEnvs) do
    if FEnvs[i].EnvName = saved.EnvName then foundIdx := i;
  if foundIdx < 0 then
  begin
    LogLine('The board this setup used ("' + saved.EnvName + '") was not found - it may have moved or been removed from References/.');
    Exit;
  end;
  CboBoard.ItemIndex := foundIdx;

  FSetup.SetBoardEnv(FEnvs[foundIdx]);
  for i := 0 to High(saved.Axes) do
    FSetup.SetAxis(saved.Axes[i]);
  RefreshAxesGrid;

  FSetup.EncoderPulsePin := saved.EncPulsePin;
  FSetup.EncoderDirPin := saved.EncDirPin;
  EdEncPulsePin.Value := saved.EncPulsePin;
  EdEncDirPin.Value := saved.EncDirPin;
  for i := 0 to High(saved.Modules) do
    FSetup.SetModuleEnabled(saved.Modules[i], True);
  RefreshModulesList;

  EdSetupName.Text := CboSetups.Text;
  LogLine('Loaded setup "' + CboSetups.Text + '".');
end;

procedure TFirmwareBuilderFrame.BtnDeleteSetupClick(Sender: TObject);
begin
  if CboSetups.Text = '' then Exit;
  FStore.Delete(CboSetups.Text);
  RefreshSetupsList;
  LogLine('Deleted setup "' + CboSetups.Text + '".');
end;

procedure TFirmwareBuilderFrame.BtnGenerateClick(Sender: TObject);
var
  err, setupsDir, setupName: string;
begin
  if not FSetup.HasBoardEnv then
  begin
    LogLine('Pick a board and configure at least one axis first.');
    Exit;
  end;
  setupName := Trim(EdSetupName.Text);
  if setupName = '' then setupName := 'unnamed';

  setupsDir := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) +
    'firmware-projects' + PathDelim + setupName;
  LblGeneratedPath.Caption := T('Generating...');
  Application.ProcessMessages;

  err := FSetup.WriteProjectCopy(setupsDir, FRefsRoot + 'uCNC-modules');
  if err <> '' then
  begin
    LblGeneratedPath.Caption := T('Generate failed');
    LogLine('Generate failed: ' + err);
    Exit;
  end;

  FGeneratedDir := setupsDir;
  LblGeneratedPath.Caption := setupsDir;
  LogLine('Generated project at: ' + setupsDir);
  LogLine('You can open this folder directly in VSCode+PlatformIO or run `pio` yourself, or use Build/Upload below.');
end;

procedure TFirmwareBuilderFrame.BtnBuildClick(Sender: TObject);
var
  params: TStringList;
begin
  if FGeneratedDir = '' then
  begin
    LogLine('Generate a project first.');
    Exit;
  end;
  if FBuildRunner.IsRunning then
  begin
    LogLine('A build is already running.');
    Exit;
  end;
  if not FSetup.HasBoardEnv then Exit;

  LogLine('--- Build: pio run -e ' + FSetup.BoardEnv.EnvName + ' ---');
  params := TStringList.Create;
  try
    params.Add('run');
    params.Add('-e');
    params.Add(FSetup.BoardEnv.EnvName);
    params.Add('-d');
    params.Add(FGeneratedDir);
    FBuildRunner.Run(FPioExe, params, FGeneratedDir);
  finally
    params.Free;
  end;
end;

procedure TFirmwareBuilderFrame.OnBuildDone(Sender: TObject; AExitCode: Integer);
begin
  if AExitCode = 0 then
    LogLine('--- Build finished: SUCCESS ---')
  else
    LogLine(Format('--- Build finished: FAILED (exit code %d) ---', [AExitCode]));
end;

procedure TFirmwareBuilderFrame.BtnRefreshPortsClick(Sender: TObject);
var
  ports: TStringList;
begin
  ports := TStringList.Create;
  try
    ListSerialPorts(ports);
    CboPort.Items.Assign(ports);
    if (CboPort.Text = '') and (CboPort.Items.Count > 0) then
      CboPort.ItemIndex := 0;
  finally
    ports.Free;
  end;
end;

procedure TFirmwareBuilderFrame.BtnUploadClick(Sender: TObject);
var
  params: TStringList;
begin
  if FGeneratedDir = '' then
  begin
    LogLine('Generate a project first.');
    Exit;
  end;
  if CboPort.Text = '' then
  begin
    LogLine('Pick a serial port first.');
    Exit;
  end;
  if FUploadRunner.IsRunning then
  begin
    LogLine('An upload is already running.');
    Exit;
  end;
  if not FSetup.HasBoardEnv then Exit;

  LogLine('--- Upload: pio run -e ' + FSetup.BoardEnv.EnvName + ' -t upload --upload-port ' + CboPort.Text + ' ---');
  LogLine('(Note: uploading to real hardware has not been verified in development - watch this log for errors.)');
  params := TStringList.Create;
  try
    params.Add('run');
    params.Add('-e');
    params.Add(FSetup.BoardEnv.EnvName);
    params.Add('-t');
    params.Add('upload');
    params.Add('--upload-port');
    params.Add(CboPort.Text);
    params.Add('-d');
    params.Add(FGeneratedDir);
    FUploadRunner.Run(FPioExe, params, FGeneratedDir);
  finally
    params.Free;
  end;
end;

procedure TFirmwareBuilderFrame.OnUploadDone(Sender: TObject; AExitCode: Integer);
begin
  if AExitCode = 0 then
    LogLine('--- Upload finished: SUCCESS ---')
  else
    LogLine(Format('--- Upload finished: FAILED (exit code %d) ---', [AExitCode]));
end;

end.
