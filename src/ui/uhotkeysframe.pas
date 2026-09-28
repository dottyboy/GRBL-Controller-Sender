unit uhotkeysframe;

{ THotkeysFrame: the "Hotkeys" tab (plan Phase 15's remaining piece - the
  rebind-editor UI; uhotkeys.pas's core+defaults were already done). A
  flat grid (Action | Key), matching the already-proven tab pattern
  (Materials/Macros) rather than a modal dialog - Phase 14's own session
  found a real, 100%-reproducible crash pairing a TStringGrid with a
  freshly-created modal TForm on this specific Qt5/LCL build, so every
  grid-based editor in this codebase lives in a permanent tab now, this
  one included, not just as a stylistic match.

  Doesn't own the THotkeyMap - takes a REFERENCE to umain.pas's own
  instance (the same one FormKeyDown already dispatches from), so a
  rebind here takes effect immediately with no separate reload/sync step.

  Capturing a new key needs the NEXT keydown regardless of which control
  has focus - same mechanism umain.pas's FormKeyDown already uses for
  live hotkey dispatch (Form1.KeyPreview). This frame doesn't hook that
  itself; umain.pas's FormKeyDown checks IsCapturing FIRST and routes the
  next keydown to CaptureKeyPress instead of normal dispatch when true. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls, Grids,
  uhotkeys, ui18n;

const
  COL_ACTION = 0;
  COL_KEY = 1;

type

  { THotkeysFrame }

  THotkeysFrame = class(TFrame)
    BtnRebind: TButton;
    Grid: TStringGrid;
    LblHint: TLabel;
    ToolBar: TPanel;
    procedure BtnRebindClick(Sender: TObject);
  private
    FMap: THotkeyMap;
    FCapturing: Boolean;
    FCapturingAction: THotkeyAction;
    procedure PopulateGrid;
    procedure SetStatus(const AMsg: string);
  public
    procedure SetHotkeyMap(AMap: THotkeyMap);
    property IsCapturing: Boolean read FCapturing;
    // Called by umain.pas's FormKeyDown when IsCapturing is True, instead
    // of normal hotkey dispatch. AKey=27 (Escape) cancels without
    // rebinding anything.
    procedure CaptureKeyPress(AKey: Word; AShift, ACtrl, AAlt: Boolean);
  end;

function KeyName(AKey: Word): string;
function BindingDisplayString(const B: THotkeyBinding): string;

implementation

{$R *.frm}

const
  VK_ESCAPE = 27;

function KeyName(AKey: Word): string;
begin
  case AKey of
    96:  Result := 'NumPad0';
    97:  Result := 'NumPad1';
    98:  Result := 'NumPad2';
    99:  Result := 'NumPad3';
    100: Result := 'NumPad4';
    101: Result := 'NumPad5';
    102: Result := 'NumPad6';
    103: Result := 'NumPad7';
    104: Result := 'NumPad8';
    105: Result := 'NumPad9';
    106: Result := 'NumPad*';
    107: Result := 'NumPad+';
    109: Result := 'NumPad-';
    111: Result := 'NumPad/';
    112..123: Result := 'F' + IntToStr(AKey - 111); // 112=F1 .. 123=F12
    65..90: Result := Chr(AKey);                    // VK codes equal ASCII for A-Z
    48..57: Result := Chr(AKey);                    // and for 0-9
  else
    Result := 'Key' + IntToStr(AKey);
  end;
end;

function BindingDisplayString(const B: THotkeyBinding): string;
begin
  Result := '';
  if B.Ctrl then Result := Result + 'Ctrl+';
  if B.Shift then Result := Result + 'Shift+';
  if B.Alt then Result := Result + 'Alt+';
  Result := Result + KeyName(B.Key);
end;

{ THotkeysFrame }

procedure THotkeysFrame.SetHotkeyMap(AMap: THotkeyMap);
begin
  FMap := AMap;
  PopulateGrid;
end;

procedure THotkeysFrame.PopulateGrid;
var
  i: Integer;
  b: THotkeyBinding;
begin
  if FMap = nil then Exit;
  Grid.Cells[COL_ACTION, 0] := 'Action';
  Grid.Cells[COL_KEY, 0] := 'Key';
  Grid.RowCount := Max(2, FMap.Count + 1);
  for i := 0 to FMap.Count - 1 do
  begin
    b := FMap.Binding(i);
    Grid.Cells[COL_ACTION, i + 1] := ActionName(b.Action);
    Grid.Cells[COL_KEY, i + 1] := BindingDisplayString(b);
  end;
end;

procedure THotkeysFrame.SetStatus(const AMsg: string);
begin
  LblHint.Caption := AMsg;
end;

procedure THotkeysFrame.BtnRebindClick(Sender: TObject);
var
  row: Integer;
begin
  if FMap = nil then Exit;
  row := Grid.Row;
  // Grid row (row-1) maps 1:1 onto FMap's own binding index - PopulateGrid
  // fills row i+1 from FMap.Binding(i) in exactly this order, so there's
  // no need to round-trip the action through its name string here.
  if (row < 1) or (row - 1 >= FMap.Count) then
  begin
    SetStatus(T('Nothing to run'));
    Exit;
  end;
  FCapturingAction := FMap.Binding(row - 1).Action;
  FCapturing := True;
  SetStatus(Format('Press a key for "%s"... (Esc to cancel)', [Grid.Cells[COL_ACTION, row]]));
end;

procedure THotkeysFrame.CaptureKeyPress(AKey: Word; AShift, ACtrl, AAlt: Boolean);
begin
  if not FCapturing then Exit;
  FCapturing := False;
  if AKey = VK_ESCAPE then
  begin
    SetStatus(T('Cancelled'));
    Exit;
  end;
  FMap.SetBinding(FCapturingAction, AKey, AShift, ACtrl, AAlt);
  PopulateGrid;
  SetStatus('');
end;

end.
