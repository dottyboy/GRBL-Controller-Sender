unit urasterimportframe;

{ TRasterImportFrame: the "Raster Import" tab (plan Phase 10) - load an
  image, pick tool mode/dither algorithm/scan direction/power/feed/pixel
  size, Generate builds a program and fires OnGenerated so umain.pas can
  push it into the Editor/3D View, same decoupled pattern as
  uspoilboardframe.pas's own OnGenerated. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls, Dialogs,
  Spin, uimageio, uditherers, uscandirections, urasterconvert, ui18n;

type
  TOnGenerated = procedure(const AProgramText: string) of object;

  { TRasterImportFrame }

  TRasterImportFrame = class(TFrame)
    BtnGenerate: TButton;
    BtnOpen: TButton;
    ChkInvert: TCheckBox;
    CboToolMode: TComboBox;
    CboDither: TComboBox;
    CboDirection: TComboBox;
    EdMinPower: TSpinEdit;
    EdMaxPower: TSpinEdit;
    EdFeedRate: TSpinEdit;
    EdPixelSize: TFloatSpinEdit;
    EdThreshold: TSpinEdit;
    LblDirection: TLabel;
    LblDither: TLabel;
    LblFeedRate: TLabel;
    LblFile: TLabel;
    LblMaxPower: TLabel;
    LblMinPower: TLabel;
    LblPixelSize: TLabel;
    LblStatus: TLabel;
    LblThreshold: TLabel;
    LblToolMode: TLabel;
    procedure BtnGenerateClick(Sender: TObject);
    procedure BtnOpenClick(Sender: TObject);
    procedure CboToolModeChange(Sender: TObject);
  private
    FOpenDialog: TOpenDialog;
    FLoadedFile: string;
    FOnGenerated: TOnGenerated;
    procedure SetStatus(const AMsg: string; AIsError: Boolean);
    procedure UpdateEnabledState;
  public
    constructor Create(AOwner: TComponent); override;
    // ImportFile: plan Phase 22 (SincroStart's IMPORT_RASTER:<path>
    // message) - programmatic equivalent of "Open Image..." followed by
    // "Generate", for a caller (umain.pas) that already has a path in
    // hand and isn't going through the Open-file dialog.
    procedure ImportFile(const AFileName: string);
    property OnGenerated: TOnGenerated read FOnGenerated write FOnGenerated;
  end;

implementation

{$R *.frm}

{ TRasterImportFrame }

constructor TRasterImportFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FOpenDialog := TOpenDialog.Create(Self);
  FOpenDialog.Filter := 'Image files (*.png;*.jpg;*.jpeg;*.bmp;*.gif)|*.png;*.jpg;*.jpeg;*.bmp;*.gif|All files (*.*)|*.*';

  CboToolMode.Items.Add('Dithering');
  CboToolMode.Items.Add('Line-to-line');
  CboToolMode.ItemIndex := 0;

  CboDither.Items.Add('Floyd-Steinberg');
  CboDither.Items.Add('Jarvis-Judice-Ninke');
  CboDither.Items.Add('Stucki');
  CboDither.Items.Add('Burkes');
  CboDither.Items.Add('Sierra2');
  CboDither.Items.Add('Sierra3');
  CboDither.Items.Add('SierraLite');
  CboDither.Items.Add('Atkinson');
  CboDither.Items.Add('Random');
  CboDither.ItemIndex := 0;

  CboDirection.Items.Add('Horizontal');
  CboDirection.Items.Add('Vertical');
  CboDirection.Items.Add('Diagonal');
  CboDirection.Items.Add('ZigZag');
  CboDirection.ItemIndex := 0;

  UpdateEnabledState;
end;

procedure TRasterImportFrame.SetStatus(const AMsg: string; AIsError: Boolean);
begin
  LblStatus.Caption := AMsg;
  if AIsError then
    LblStatus.Font.Color := clRed
  else
    LblStatus.Font.Color := clGreen;
end;

procedure TRasterImportFrame.UpdateEnabledState;
var
  isDithering: Boolean;
begin
  isDithering := CboToolMode.ItemIndex = 0;
  CboDither.Enabled := isDithering;
  EdThreshold.Enabled := isDithering;
  EdMinPower.Enabled := not isDithering;
end;

procedure TRasterImportFrame.CboToolModeChange(Sender: TObject);
begin
  UpdateEnabledState;
end;

procedure TRasterImportFrame.ImportFile(const AFileName: string);
begin
  FLoadedFile := AFileName;
  LblFile.Caption := ExtractFileName(FLoadedFile);
  BtnGenerateClick(Self);
end;

procedure TRasterImportFrame.BtnOpenClick(Sender: TObject);
begin
  if not FOpenDialog.Execute then Exit;
  FLoadedFile := FOpenDialog.FileName;
  LblFile.Caption := ExtractFileName(FLoadedFile);
  SetStatus('', False);
end;

procedure TRasterImportFrame.BtnGenerateClick(Sender: TObject);
var
  img: TGrayscaleImage;
  err: string;
  opts: TRasterConvertOptions;
  prog: TStringList;
begin
  if FLoadedFile = '' then
  begin
    SetStatus(T('Nothing to run'), True);
    Exit;
  end;

  if not LoadGrayscaleImage(FLoadedFile, img, err) then
  begin
    SetStatus(err, True);
    Exit;
  end;

  opts := DefaultRasterOptions;
  if CboToolMode.ItemIndex = 1 then
    opts.ToolMode := rtmLineToLine
  else
    opts.ToolMode := rtmDithering;
  opts.DitherAlgorithm := TDitherAlgorithm(CboDither.ItemIndex);
  opts.Direction := TScanDirection(CboDirection.ItemIndex);
  opts.Threshold := EdThreshold.Value;
  opts.MinPower := EdMinPower.Value;
  opts.MaxPower := EdMaxPower.Value;
  opts.FeedRate := EdFeedRate.Value;
  opts.PixelSizeMM := EdPixelSize.Value;
  opts.Invert := ChkInvert.Checked;

  prog := GenerateRasterProgram(img, opts);
  try
    if Assigned(FOnGenerated) then
      FOnGenerated(prog.Text);
    SetStatus(Format('%d x %d px, %d lines', [img.Width, img.Height, prog.Count]), False);
  finally
    prog.Free;
  end;
end;

end.
