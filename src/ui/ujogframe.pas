unit ujogframe;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Graphics,
  usender;

type

  { TJogFrame }

  TJogFrame = class(TFrame)
    BtnHold: TButton;
    BtnHome: TButton;
    BtnReset: TButton;
    BtnResume: TButton;
    BtnUnlock: TButton;
    BtnXMinus: TButton;
    BtnXPlus: TButton;
    BtnYMinus: TButton;
    BtnYPlus: TButton;
    BtnZMinus: TButton;
    BtnZPlus: TButton;
    BtnNW: TButton;
    BtnNE: TButton;
    BtnSW: TButton;
    BtnSE: TButton;
    CboStep: TComboBox;
    CboStepZ: TComboBox;
    LblStep: TLabel;
    LblStepZ: TLabel;
    procedure JogClick(Sender: TObject);
    procedure DiagonalJogClick(Sender: TObject);
    procedure HomeClick(Sender: TObject);
    procedure UnlockClick(Sender: TObject);
    procedure HoldClick(Sender: TObject);
    procedure ResumeClick(Sender: TObject);
    procedure ResetClick(Sender: TObject);
  private
    FSender: TSender;
    FCurrentExtraLetters: string;
    FExtraCaptions: array of TLabel;
    FExtraMinus: array of TButton;
    FExtraPlus: array of TButton;
    function StepValue: Double;
    function StepValueZ: Double;
    procedure ClearExtraRows;
    procedure ExtraJogClick(Sender: TObject);
  public
    procedure SetSender(ASender: TSender);
    // Phase D: adds a +/- row per axis beyond X/Y/Z, mirrors udroframe.pas's
    // SetAxisConfig - same no-op-if-unchanged behavior.
    procedure SetAxisConfig(const ALetters: string);
  end;

implementation

{$R *.frm}

{ TJogFrame }

procedure TJogFrame.SetSender(ASender: TSender);
begin
  FSender := ASender;
end;

function TJogFrame.StepValue: Double;
begin
  Result := StrToFloatDef(CboStep.Text, 1.0);
end;

function TJogFrame.StepValueZ: Double;
begin
  Result := StrToFloatDef(CboStepZ.Text, 1.0);
end;

procedure TJogFrame.ClearExtraRows;
var
  i: Integer;
begin
  for i := 0 to High(FExtraCaptions) do
  begin
    FExtraCaptions[i].Free;
    FExtraMinus[i].Free;
    FExtraPlus[i].Free;
  end;
  SetLength(FExtraCaptions, 0);
  SetLength(FExtraMinus, 0);
  SetLength(FExtraPlus, 0);
end;

procedure TJogFrame.SetAxisConfig(const ALetters: string);
var
  extra: string;
  i, y: Integer;
  cap: TLabel;
  btnMinus, btnPlus: TButton;
begin
  if Length(ALetters) > 3 then
    extra := Copy(ALetters, 4, Length(ALetters) - 3)
  else
    extra := '';

  if extra = FCurrentExtraLetters then Exit;
  FCurrentExtraLetters := extra;

  ClearExtraRows;
  SetLength(FExtraCaptions, Length(extra));
  SetLength(FExtraMinus, Length(extra));
  SetLength(FExtraPlus, Length(extra));

  for i := 1 to Length(extra) do
  begin
    y := 180 + (i - 1) * 34;

    cap := TLabel.Create(Self);
    cap.Parent := Self;
    cap.SetBounds(8, y + 6, 20, 20);
    cap.Font.Style := [fsBold];
    cap.Caption := extra[i];
    FExtraCaptions[i - 1] := cap;

    btnMinus := TButton.Create(Self);
    btnMinus.Parent := Self;
    btnMinus.SetBounds(44, y, 50, 30);
    btnMinus.Caption := extra[i] + '-';
    btnMinus.OnClick := @ExtraJogClick;
    FExtraMinus[i - 1] := btnMinus;

    btnPlus := TButton.Create(Self);
    btnPlus.Parent := Self;
    btnPlus.SetBounds(100, y, 50, 30);
    btnPlus.Caption := extra[i] + '+';
    btnPlus.OnClick := @ExtraJogClick;
    FExtraPlus[i - 1] := btnPlus;
  end;
end;

procedure TJogFrame.ExtraJogClick(Sender: TObject);
var
  btnCaption, dir: string;
  step: Double;
begin
  if FSender = nil then Exit;
  btnCaption := TButton(Sender).Caption; // e.g. "A-" or "A+"
  if Length(btnCaption) < 2 then Exit;
  step := StepValue;
  if btnCaption[2] = '-' then
    dir := Format('%s-%g', [btnCaption[1], step])
  else
    dir := Format('%s%g', [btnCaption[1], step]);
  FSender.Jog(dir);
end;

procedure TJogFrame.JogClick(Sender: TObject);
var
  dir: string;
  step: Double;
begin
  if FSender = nil then Exit;
  // X/Y share CboStep; Z has its own CboStepZ (added so a smaller, more
  // careful Z step can be used independently of the X/Y jog distance).
  if (Sender = BtnZMinus) or (Sender = BtnZPlus) then
    step := StepValueZ
  else
    step := StepValue;
  if Sender = BtnXMinus then dir := Format('X-%g', [step])
  else if Sender = BtnXPlus then dir := Format('X%g', [step])
  else if Sender = BtnYMinus then dir := Format('Y-%g', [step])
  else if Sender = BtnYPlus then dir := Format('Y%g', [step])
  else if Sender = BtnZMinus then dir := Format('Z-%g', [step])
  else if Sender = BtnZPlus then dir := Format('Z%g', [step])
  else Exit;
  FSender.Jog(dir);
end;

procedure TJogFrame.DiagonalJogClick(Sender: TObject);
var
  dir: string;
  step: Double;
begin
  // Plan Phase 17 (jog panel parity check against LaserGRBL's real
  // JogForm.cs, which has a full 8-direction pad, N/S/E/W plus
  // NE/SE/SW/NW): this app only had the 4 cardinal directions. GRBL's
  // $J= jog command (already used by TGRBL1Controller.Jog, see
  // ugrbl1.pas) accepts multiple axis words on one line, so a diagonal
  // is just X and Y combined in a single jog command - no protocol
  // changes needed, reuses the same StepValue as the X/Y buttons.
  if FSender = nil then Exit;
  step := StepValue;
  if Sender = BtnNW then dir := Format('X-%gY%g', [step, step])
  else if Sender = BtnNE then dir := Format('X%gY%g', [step, step])
  else if Sender = BtnSW then dir := Format('X-%gY-%g', [step, step])
  else if Sender = BtnSE then dir := Format('X%gY-%g', [step, step])
  else Exit;
  FSender.Jog(dir);
end;

procedure TJogFrame.HomeClick(Sender: TObject);
begin
  if FSender <> nil then FSender.Home;
end;

procedure TJogFrame.UnlockClick(Sender: TObject);
begin
  if FSender <> nil then FSender.Unlock;
end;

procedure TJogFrame.HoldClick(Sender: TObject);
begin
  if FSender <> nil then FSender.FeedHold;
end;

procedure TJogFrame.ResumeClick(Sender: TObject);
begin
  if FSender <> nil then FSender.Resume;
end;

procedure TJogFrame.ResetClick(Sender: TObject);
begin
  if FSender <> nil then FSender.SoftReset;
end;

end.
