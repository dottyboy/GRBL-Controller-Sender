unit ufluidncframe;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Dialogs,
  SynEdit,
  usender, uaxeseditform, ui18n;

type

  { TFluidNCFrame: raw config.yaml editor + XMODEM upload/download (Phase G),
    plus a structured "Edit Axes..." dialog (Phase H MVP - axes/motors/
    homing only, the highest-value section; everything else in the file
    stays hand-edited here in the raw SynEdit). Only meaningful for a
    FluidNC board - umain.pas hides this tab (TabVisible := False) for any
    other firmware. }
  TFluidNCFrame = class(TFrame)
    BtnDownload: TButton;
    BtnEditAxes: TButton;
    BtnOpen: TButton;
    BtnSave: TButton;
    BtnSaveAs: TButton;
    BtnUpload: TButton;
    EdBoardFile: TEdit;
    LblBoardFile: TLabel;
    LblFile: TLabel;
    LblStatus: TLabel;
    SynEditor: TSynEdit;
    ToolBar: TPanel;
    procedure BtnDownloadClick(Sender: TObject);
    procedure BtnEditAxesClick(Sender: TObject);
    procedure BtnOpenClick(Sender: TObject);
    procedure BtnSaveClick(Sender: TObject);
    procedure BtnSaveAsClick(Sender: TObject);
    procedure BtnUploadClick(Sender: TObject);
  private
    FSender: TSender;
    FCurrentFile: string;
    FOpenDialog: TOpenDialog;
    FSaveDialog: TSaveDialog;
    procedure DoSave(const AFileName: string);
    procedure SetCurrentFile(const AFileName: string);
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetSender(ASender: TSender);
    // Called from umain.pas's SenderLog when a line matching
    // "[MSG:ERR: Ignored key ...]" arrives - FluidNC logs bad config.yaml
    // keys instead of failing the upload outright, so a typo would
    // otherwise go unnoticed until something doesn't work as expected.
    procedure ReportIgnoredKey(const ALine: string);
  end;

implementation

{$R *.frm}

{ TFluidNCFrame }

constructor TFluidNCFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FOpenDialog := TOpenDialog.Create(Self);
  FOpenDialog.Filter := 'YAML files (*.yaml;*.yml)|*.yaml;*.yml|All files (*.*)|*.*';
  FSaveDialog := TSaveDialog.Create(Self);
  FSaveDialog.Filter := FOpenDialog.Filter;
  FSaveDialog.DefaultExt := 'yaml';
  SetCurrentFile('');
  LblStatus.Caption := T('Not connected');
end;

procedure TFluidNCFrame.SetSender(ASender: TSender);
begin
  FSender := ASender;
end;

procedure TFluidNCFrame.SetCurrentFile(const AFileName: string);
begin
  FCurrentFile := AFileName;
  if AFileName = '' then
    LblFile.Caption := T('(untitled)')
  else
    LblFile.Caption := ExtractFileName(AFileName);
end;

procedure TFluidNCFrame.DoSave(const AFileName: string);
begin
  SynEditor.Lines.SaveToFile(AFileName);
  SetCurrentFile(AFileName);
end;

procedure TFluidNCFrame.BtnOpenClick(Sender: TObject);
begin
  if not FOpenDialog.Execute then Exit;
  SynEditor.Lines.LoadFromFile(FOpenDialog.FileName);
  SetCurrentFile(FOpenDialog.FileName);
end;

procedure TFluidNCFrame.BtnEditAxesClick(Sender: TObject);
var
  dlg: TAxesEditForm;
begin
  dlg := TAxesEditForm.Create(Self);
  try
    if not dlg.LoadFromYAML(SynEditor.Lines.Text) then
    begin
      LblStatus.Caption := T('No "axes:" block found in the current text - open/download a config.yaml first');
      Exit;
    end;
    if dlg.ShowModal = mrOK then
    begin
      SynEditor.Lines.Text := dlg.ApplyToYAML(SynEditor.Lines.Text);
      LblStatus.Caption := T('Axes updated - remember to Upload to board (or Save) to keep it');
    end;
  finally
    dlg.Free;
  end;
end;

procedure TFluidNCFrame.BtnSaveClick(Sender: TObject);
begin
  if FCurrentFile = '' then
    BtnSaveAsClick(Sender)
  else
    DoSave(FCurrentFile);
end;

procedure TFluidNCFrame.BtnSaveAsClick(Sender: TObject);
begin
  if FCurrentFile <> '' then
    FSaveDialog.FileName := FCurrentFile;
  if not FSaveDialog.Execute then Exit;
  DoSave(FSaveDialog.FileName);
end;

procedure TFluidNCFrame.BtnDownloadClick(Sender: TObject);
var
  data: TBytes;
  s: string;
  i: Integer;
begin
  if (FSender = nil) or (not FSender.Connected) then
  begin
    LblStatus.Caption := T('Not connected');
    Exit;
  end;
  if Trim(EdBoardFile.Text) = '' then
  begin
    LblStatus.Caption := T('Enter a board filename first');
    Exit;
  end;

  LblStatus.Caption := T('Downloading...');
  Application.ProcessMessages; // paint the status before the blocking transfer
  if FSender.DownloadFile(Trim(EdBoardFile.Text), data) then
  begin
    SetLength(s, Length(data));
    for i := 0 to Length(data) - 1 do s[i + 1] := Chr(data[i]);
    SynEditor.Lines.Text := s;
    SetCurrentFile('');
    LblStatus.Caption := Format('Downloaded %d bytes', [Length(data)]);
  end
  else
    LblStatus.Caption := T('Download failed - check wiring/filename and retry');
end;

procedure TFluidNCFrame.BtnUploadClick(Sender: TObject);
var
  data: TBytes;
  s: string;
  i: Integer;
begin
  if (FSender = nil) or (not FSender.Connected) then
  begin
    LblStatus.Caption := T('Not connected');
    Exit;
  end;
  if Trim(EdBoardFile.Text) = '' then
  begin
    LblStatus.Caption := T('Enter a board filename first');
    Exit;
  end;

  s := SynEditor.Lines.Text;
  SetLength(data, Length(s));
  for i := 1 to Length(s) do data[i - 1] := Byte(Ord(s[i]));

  LblStatus.Caption := T('Uploading...');
  Application.ProcessMessages;
  if FSender.UploadFile(Trim(EdBoardFile.Text), data) then
    LblStatus.Caption := Format('Uploaded %d bytes - watch Terminal for "Ignored key" warnings', [Length(data)])
  else
    LblStatus.Caption := T('Upload failed - check wiring/filename and retry');
end;

procedure TFluidNCFrame.ReportIgnoredKey(const ALine: string);
begin
  LblStatus.Caption := T('Board reported: ') + ALine;
end;

end.
