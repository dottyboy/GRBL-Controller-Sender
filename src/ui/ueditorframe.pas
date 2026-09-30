unit ueditorframe;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Dialogs,
  SynEdit,
  usender, ucustombutton, ucustombuttonstore, uheaderfooterpreset,
  uheaderfooterpresetstore, ui18n;

type

  { TEditorFrame }

  TEditorFrame = class(TFrame)
    BtnLoadHeaderFooterPreset: TButton;
    BtnOpen: TButton;
    BtnSave: TButton;
    BtnSaveAs: TButton;
    BtnSend: TButton;
    BtnStop: TButton;
    CboHeaderFooterPreset: TComboBox;
    ChkHeaderFooterEnabled: TCheckBox;
    LblFile: TLabel;
    LblHeaderFooterPreset: TLabel;
    SynEditor: TSynEdit;
    ToolBar: TPanel;
    procedure BtnLoadHeaderFooterPresetClick(Sender: TObject);
    procedure BtnOpenClick(Sender: TObject);
    procedure BtnSaveClick(Sender: TObject);
    procedure BtnSaveAsClick(Sender: TObject);
    procedure BtnSendClick(Sender: TObject);
    procedure BtnStopClick(Sender: TObject);
  private
    FSender: TSender;
    FCurrentFile: string;
    FOpenDialog: TOpenDialog;
    FSaveDialog: TSaveDialog;
    // Plan Phase 37: plain CNC streaming (this frame's own Send) gains the
    // same named Header/Footer preset + auto-run-macro capability the
    // laser path already had - reachable from here too, not laser-only
    // (the real gap the user caught: "ne samo laser, nego i cnc mora
    // imati mogućnost").
    FHFStore: THeaderFooterPresetStore;
    FHFPresets: THeaderFooterPresetArray;
    FSelectedHeader, FSelectedFooter: string;
    FButtonStore: TCustomButtonStore;
    procedure DoSave(const AFileName: string);
    procedure SetCurrentFile(const AFileName: string);
    procedure RefreshHeaderFooterPresets;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetSender(ASender: TSender);
    procedure OpenFile(const AFileName: string);
    procedure LoadGeneratedText(const AText: string);
    property CurrentFile: string read FCurrentFile;
  end;

implementation

{$R *.frm}

{ TEditorFrame }

constructor TEditorFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FOpenDialog := TOpenDialog.Create(Self);
  FOpenDialog.Filter := 'G-code files (*.nc;*.ngc;*.gcode;*.tap)|*.nc;*.ngc;*.gcode;*.tap|All files (*.*)|*.*';
  FSaveDialog := TSaveDialog.Create(Self);
  FSaveDialog.Filter := FOpenDialog.Filter;
  FSaveDialog.DefaultExt := 'nc';

  FHFStore := THeaderFooterPresetStore.Create(
    IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'headerfooterpresets.ini');
  RefreshHeaderFooterPresets;
  FButtonStore := TCustomButtonStore.Create(
    IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'custombuttons.ini');
end;

destructor TEditorFrame.Destroy;
begin
  FButtonStore.Free;
  FHFStore.Free;
  inherited Destroy;
end;

procedure TEditorFrame.RefreshHeaderFooterPresets;
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

procedure TEditorFrame.BtnLoadHeaderFooterPresetClick(Sender: TObject);
var
  idx: Integer;
begin
  idx := CboHeaderFooterPreset.ItemIndex;
  if (idx < 0) or (idx > High(FHFPresets)) then Exit;
  FSelectedHeader := FHFPresets[idx].Header;
  FSelectedFooter := FHFPresets[idx].Footer;
end;

procedure TEditorFrame.SetSender(ASender: TSender);
begin
  FSender := ASender;
end;

procedure TEditorFrame.SetCurrentFile(const AFileName: string);
begin
  FCurrentFile := AFileName;
  if AFileName = '' then
    LblFile.Caption := T('(untitled)')
  else
    LblFile.Caption := ExtractFileName(AFileName);
end;

procedure TEditorFrame.OpenFile(const AFileName: string);
begin
  SynEditor.Lines.LoadFromFile(AFileName);
  SetCurrentFile(AFileName);
end;

procedure TEditorFrame.LoadGeneratedText(const AText: string);
begin
  // Not tied to any file on disk - clears FCurrentFile so a subsequent
  // Save behaves like Save As (asks for a filename) instead of silently
  // overwriting whatever file happened to be open before this replaced it.
  SynEditor.Lines.Text := AText;
  SetCurrentFile('');
end;

procedure TEditorFrame.DoSave(const AFileName: string);
begin
  SynEditor.Lines.SaveToFile(AFileName);
  SetCurrentFile(AFileName);
end;

procedure TEditorFrame.BtnOpenClick(Sender: TObject);
begin
  if not FOpenDialog.Execute then Exit;
  OpenFile(FOpenDialog.FileName);
end;

procedure TEditorFrame.BtnSaveClick(Sender: TObject);
begin
  if FCurrentFile = '' then
    BtnSaveAsClick(Sender)
  else
    DoSave(FCurrentFile);
end;

procedure TEditorFrame.BtnSaveAsClick(Sender: TObject);
begin
  if FCurrentFile <> '' then
    FSaveDialog.FileName := FCurrentFile;
  if not FSaveDialog.Execute then Exit;
  DoSave(FSaveDialog.FileName);
end;

procedure TEditorFrame.BtnSendClick(Sender: TObject);
var
  i: Integer;
  line: string;
  buttons: TCustomButtonArray;
  startMacroLines, endMacroLines, headerLines, footerLines: TStringList;
begin
  if FSender = nil then Exit;

  // Plan Phase 37: the same shared BeginJob/EndJob hook the laser path
  // uses - auto-run macros fire here too, not just for laser jobs (the
  // real gap this phase exists to close).
  buttons := FButtonStore.LoadAll;
  startMacroLines := TStringList.Create;
  endMacroLines := TStringList.Create;
  headerLines := TStringList.Create;
  footerLines := TStringList.Create;
  try
    CombinedAutoRunGCode(buttons, True, startMacroLines);
    CombinedAutoRunGCode(buttons, False, endMacroLines);

    if ChkHeaderFooterEnabled.Checked then
    begin
      headerLines.Text := FSelectedHeader;
      footerLines.Text := FSelectedFooter;
    end;

    FSender.BeginJob(startMacroLines);
    for i := 0 to headerLines.Count - 1 do
      if Trim(headerLines[i]) <> '' then FSender.EnqueueGCode(headerLines[i]);

    for i := 0 to SynEditor.Lines.Count - 1 do
    begin
      line := Trim(SynEditor.Lines[i]);
      if line = '' then Continue;
      if (line[1] = ';') or (Copy(line, 1, 1) = '(') then Continue; // comment
      FSender.EnqueueGCode(line);
    end;

    for i := 0 to footerLines.Count - 1 do
      if Trim(footerLines[i]) <> '' then FSender.EnqueueGCode(footerLines[i]);
    FSender.EndJob(endMacroLines);
  finally
    startMacroLines.Free;
    endMacroLines.Free;
    headerLines.Free;
    footerLines.Free;
  end;
end;

procedure TEditorFrame.BtnStopClick(Sender: TObject);
begin
  if FSender <> nil then FSender.StopStreaming;
end;

end.
