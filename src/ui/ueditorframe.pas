unit ueditorframe;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Dialogs,
  SynEdit,
  usender, ui18n;

type

  { TEditorFrame }

  TEditorFrame = class(TFrame)
    BtnOpen: TButton;
    BtnSave: TButton;
    BtnSaveAs: TButton;
    BtnSend: TButton;
    BtnStop: TButton;
    LblFile: TLabel;
    SynEditor: TSynEdit;
    ToolBar: TPanel;
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
    procedure DoSave(const AFileName: string);
    procedure SetCurrentFile(const AFileName: string);
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
end;

destructor TEditorFrame.Destroy;
begin
  inherited Destroy;
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
begin
  if FSender = nil then Exit;
  for i := 0 to SynEditor.Lines.Count - 1 do
  begin
    line := Trim(SynEditor.Lines[i]);
    if line = '' then Continue;
    if (line[1] = ';') or (Copy(line, 1, 1) = '(') then Continue; // comment
    FSender.EnqueueGCode(line);
  end;
end;

procedure TEditorFrame.BtnStopClick(Sender: TObject);
begin
  if FSender <> nil then FSender.StopStreaming;
end;

end.
