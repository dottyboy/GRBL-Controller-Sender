unit udroframe;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Graphics,
  usender;

type

  { TDROFrame }

  TDROFrame = class(TFrame)
    LblMPos: TLabel;
    LblStateBig: TLabel;
    LblWX: TLabel;
    LblWY: TLabel;
    LblWZ: TLabel;
    LblXCaption: TLabel;
    LblYCaption: TLabel;
    LblZCaption: TLabel;
  private
    FSender: TSender;
    FCurrentExtraLetters: string;
    FExtraCaptions: array of TLabel;
    FExtraValues: array of TLabel;
    procedure ClearExtraRows;
  public
    procedure SetSender(ASender: TSender);
    procedure RefreshState;
    // Phase D: rebuilds any axis rows beyond the static X/Y/Z ones above
    // for whatever the connected board reports past 3 axes (e.g. 'A' for
    // a 4th axis) - see uboardinfo.pas's AxisLetters. A no-op if the
    // extra-axis part of ALetters hasn't changed since the last call, so
    // this is safe to call on every status refresh.
    procedure SetAxisConfig(const ALetters: string);
  end;

implementation

{$R *.frm}

var
  // Phase E "ganged axis" marker: a font-color highlight rather than an
  // appended glyph - the axis caption and value labels are laid out as two
  // independently-positioned, fixed-width labels (not one auto-sizing
  // block), so widening the caption's text risks visually overlapping the
  // value column. A color change carries the same "this one's different"
  // signal without touching layout at all.
  //
  // Set via RGBToColor(R,G,B) in this unit's initialization, rather than a
  // raw $BBGGRR hex literal - TColor stores bytes as $00BBGGRR (blue/green/
  // red, NOT red/green/blue), so a hand-written hex constant is an easy way
  // to get the wrong color by transposing R and B (exactly what happened
  // here originally: $C36A00 was intended as amber but is actually
  // RGB(0,106,195), a blue - this file's own earlier bug).
  GANGED_COLOR: TColor;

{ TDROFrame }

procedure TDROFrame.SetSender(ASender: TSender);
begin
  FSender := ASender;
end;

procedure TDROFrame.ClearExtraRows;
var
  i: Integer;
begin
  for i := 0 to High(FExtraCaptions) do
  begin
    FExtraCaptions[i].Free;
    FExtraValues[i].Free;
  end;
  SetLength(FExtraCaptions, 0);
  SetLength(FExtraValues, 0);
end;

procedure TDROFrame.SetAxisConfig(const ALetters: string);
var
  extra: string;
  i, y: Integer;
  cap, val: TLabel;
begin
  if Length(ALetters) > 3 then
    extra := Copy(ALetters, 4, Length(ALetters) - 3)
  else
    extra := '';

  if extra = FCurrentExtraLetters then Exit; // no change, nothing to rebuild
  FCurrentExtraLetters := extra;

  ClearExtraRows;
  SetLength(FExtraCaptions, Length(extra));
  SetLength(FExtraValues, Length(extra));

  for i := 1 to Length(extra) do
  begin
    y := 38 + (2 + i) * 30; // continues the X(38)/Y(68)/Z(98) row spacing

    cap := TLabel.Create(Self);
    cap.Parent := Self;
    cap.SetBounds(8, y, 20, 24);
    cap.Font.Size := 14;
    cap.Font.Style := [fsBold];
    cap.Caption := extra[i];
    FExtraCaptions[i - 1] := cap;

    val := TLabel.Create(Self);
    val.Parent := Self;
    val.SetBounds(36, y, 160, 24);
    val.Font.Size := 14;
    val.Caption := '0.000';
    FExtraValues[i - 1] := val;
  end;

  // LblMPos sits right after the last row, static rows or dynamic.
  LblMPos.Top := 38 + (3 + Length(extra)) * 30;
end;

procedure TDROFrame.RefreshState;
var
  i: Integer;
  extraVal: Double;
begin
  if FSender = nil then Exit;
  with FSender.State do
  begin
    LblWX.Caption := Format('%.3f', [WX]);
    LblWY.Caption := Format('%.3f', [WY]);
    LblWZ.Caption := Format('%.3f', [WZ]);
    LblMPos.Caption := Format('M: %.3f, %.3f, %.3f', [MX, MY, MZ]);
    LblStateBig.Caption := StateStr;

    // Phase E: cosmetic marker on any axis the user has declared as ganged
    // (2 motors, auto-squared) via the Machine Settings dialog.
    if Pos('X', GangedAxes) > 0 then LblXCaption.Font.Color := GANGED_COLOR
    else LblXCaption.Font.Color := clDefault;
    if Pos('Y', GangedAxes) > 0 then LblYCaption.Font.Color := GANGED_COLOR
    else LblYCaption.Font.Color := clDefault;
    if Pos('Z', GangedAxes) > 0 then LblZCaption.Font.Color := GANGED_COLOR
    else LblZCaption.Font.Color := clDefault;

    for i := 0 to High(FExtraValues) do
    begin
      case i of
        0: extraVal := WA;
        1: extraVal := WB;
        2: extraVal := WC;
      else
        extraVal := 0; // more than 6 total axes isn't modeled in TCNCState
      end;
      FExtraValues[i].Caption := Format('%.3f', [extraVal]);
      if i < Length(FCurrentExtraLetters) then
      begin
        if Pos(FCurrentExtraLetters[i + 1], GangedAxes) > 0 then
          FExtraCaptions[i].Font.Color := GANGED_COLOR
        else
          FExtraCaptions[i].Font.Color := clDefault;
      end;
    end;
  end;
end;

initialization
  GANGED_COLOR := RGBToColor(154, 205, 50); // "YellowGreen" - clear on light/dark alike

end.
