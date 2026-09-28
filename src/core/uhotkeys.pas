unit uhotkeys;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles;

type
  { THotkeyAction: plan Phase 15 - the subset of LaserGRBL's ~50-action
    HotKeysManager.cs that actually maps to functionality this app has
    (no WiFi/custom-button/drawing-zoom actions - those don't exist here
    yet). Scoped down this session to jog + the control buttons
    ujogframe.pas already has (Home/Unlock/FeedHold/Resume/SoftReset),
    including the diagonal directions added in the same session's
    Phase 17 - a keybinding EDITOR UI is deliberately not built this
    pass (see the plan file's own Phase 15 note); this unit is usable
    standalone with sensible defaults in the meantime. }
  THotkeyAction = (
    haNone,
    haJogXPlus, haJogXMinus, haJogYPlus, haJogYMinus, haJogZPlus, haJogZMinus,
    haJogNE, haJogNW, haJogSE, haJogSW,
    haJogStepIncrease, haJogStepDecrease,
    haHome, haUnlock, haFeedHold, haResume, haSoftReset
  );

  THotkeyBinding = record
    Action: THotkeyAction;
    Key: Word;   // a Windows-style virtual-key code, same numbering LCL's
                 // TForm.OnKeyDown Key parameter and LCLType's VK_* consts
                 // use on every widgetset incl. Qt5 - see the literal
                 // values used in LoadDefaults for exactly which codes.
    Shift: Boolean;
    Ctrl: Boolean;
    Alt: Boolean;
  end;

  { THotkeyMap: an ordered list of action<->key bindings. Deliberately
    has NO LCL dependency (Classes/SysUtils/IniFiles only) so it stays
    standalone-testable like the rest of src/core - the caller (umain.pas)
    translates a real TForm.OnKeyDown event's Key/Shift/ssCtrl/ssAlt into
    plain Word/Boolean values before calling Find. }
  THotkeyMap = class
  private
    FBindings: array of THotkeyBinding;
    function IndexOfAction(AAction: THotkeyAction): Integer;
  public
    procedure LoadDefaults;
    procedure Load(const AFileName: string);
    procedure Save(const AFileName: string);
    // Returns haNone if no binding matches.
    function Find(AKey: Word; AShift, ACtrl, AAlt: Boolean): THotkeyAction;
    procedure SetBinding(AAction: THotkeyAction; AKey: Word; AShift, ACtrl, AAlt: Boolean);
    function Count: Integer;
    function Binding(AIndex: Integer): THotkeyBinding;
  end;

// For ini keys today and a future binding-editor UI's action list.
function ActionName(AAction: THotkeyAction): string;

implementation

function ActionName(AAction: THotkeyAction): string;
begin
  case AAction of
    haJogXPlus:         Result := 'JogXPlus';
    haJogXMinus:        Result := 'JogXMinus';
    haJogYPlus:         Result := 'JogYPlus';
    haJogYMinus:        Result := 'JogYMinus';
    haJogZPlus:         Result := 'JogZPlus';
    haJogZMinus:        Result := 'JogZMinus';
    haJogNE:            Result := 'JogNE';
    haJogNW:            Result := 'JogNW';
    haJogSE:            Result := 'JogSE';
    haJogSW:            Result := 'JogSW';
    haJogStepIncrease:  Result := 'JogStepIncrease';
    haJogStepDecrease:  Result := 'JogStepDecrease';
    haHome:             Result := 'Home';
    haUnlock:           Result := 'Unlock';
    haFeedHold:         Result := 'FeedHold';
    haResume:           Result := 'Resume';
    haSoftReset:        Result := 'SoftReset';
  else
    Result := '';
  end;
end;

function ActionFromName(const AName: string): THotkeyAction;
var
  a: THotkeyAction;
begin
  Result := haNone;
  for a := Low(THotkeyAction) to High(THotkeyAction) do
    if ActionName(a) = AName then
    begin
      Result := a;
      Exit;
    end;
end;

{ THotkeyMap }

function THotkeyMap.IndexOfAction(AAction: THotkeyAction): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(FBindings) do
    if FBindings[i].Action = AAction then
    begin
      Result := i;
      Exit;
    end;
end;

procedure THotkeyMap.SetBinding(AAction: THotkeyAction; AKey: Word; AShift, ACtrl, AAlt: Boolean);
var
  idx: Integer;
begin
  idx := IndexOfAction(AAction);
  if idx < 0 then
  begin
    idx := Length(FBindings);
    SetLength(FBindings, idx + 1);
    FBindings[idx].Action := AAction;
  end;
  FBindings[idx].Key := AKey;
  FBindings[idx].Shift := AShift;
  FBindings[idx].Ctrl := ACtrl;
  FBindings[idx].Alt := AAlt;
end;

// Real Windows-style virtual-key codes (same numbering LCLType.pas's
// VK_* constants and every LCL widgetset's OnKeyDown use, Qt5 included -
// not invented): NumPad1..4/6..9=97..100/102..105 (compass layout, minus
// the unused NumPad5 center), Add=107/Subtract=109 (Z+/Z-), Multiply=106/
// Divide=111 (step +/-), F6=117/F7=118, letter keys H/U/X=72/85/88 (VK
// codes equal ASCII for A-Z). Defaults mirror LaserGRBL's own real
// HotKeysManager.cs numpad-as-compass jog convention (read directly from
// its source, not guessed) for the directions that exist in both apps.
procedure THotkeyMap.LoadDefaults;
begin
  SetLength(FBindings, 0);
  SetBinding(haJogYPlus,  104, False, False, False); // NumPad8 = N
  SetBinding(haJogYMinus, 98,  False, False, False); // NumPad2 = S
  SetBinding(haJogXPlus,  102, False, False, False); // NumPad6 = E
  SetBinding(haJogXMinus, 100, False, False, False); // NumPad4 = W
  SetBinding(haJogNE,     105, False, False, False); // NumPad9
  SetBinding(haJogNW,     103, False, False, False); // NumPad7
  SetBinding(haJogSE,     99,  False, False, False); // NumPad3
  SetBinding(haJogSW,     97,  False, False, False); // NumPad1
  SetBinding(haJogZPlus,  107, False, False, False); // NumPad +
  SetBinding(haJogZMinus, 109, False, False, False); // NumPad -
  SetBinding(haJogStepIncrease, 106, False, False, False); // NumPad *
  SetBinding(haJogStepDecrease, 111, False, False, False); // NumPad /
  SetBinding(haHome,      72,  False, True,  False); // Ctrl+H
  SetBinding(haUnlock,    85,  False, True,  False); // Ctrl+U
  SetBinding(haFeedHold,  117, False, False, False);  // F6
  SetBinding(haResume,    118, False, False, False);  // F7
  SetBinding(haSoftReset, 88,  False, True,  False); // Ctrl+X
end;

function THotkeyMap.Find(AKey: Word; AShift, ACtrl, AAlt: Boolean): THotkeyAction;
var
  i: Integer;
begin
  Result := haNone;
  for i := 0 to High(FBindings) do
    if (FBindings[i].Key = AKey) and (FBindings[i].Shift = AShift) and
       (FBindings[i].Ctrl = ACtrl) and (FBindings[i].Alt = AAlt) then
    begin
      Result := FBindings[i].Action;
      Exit;
    end;
end;

function THotkeyMap.Count: Integer;
begin
  Result := Length(FBindings);
end;

function THotkeyMap.Binding(AIndex: Integer): THotkeyBinding;
begin
  Result := FBindings[AIndex];
end;

procedure THotkeyMap.Load(const AFileName: string);
var
  ini: TIniFile;
  names: TStringList;
  i: Integer;
  action: THotkeyAction;
  parts: TStringArray;
begin
  LoadDefaults;
  if not FileExists(AFileName) then Exit;

  ini := TIniFile.Create(AFileName);
  names := TStringList.Create;
  try
    ini.ReadSection('Hotkeys', names);
    for i := 0 to names.Count - 1 do
    begin
      action := ActionFromName(names[i]);
      if action = haNone then Continue;
      parts := ini.ReadString('Hotkeys', names[i], '').Split(',');
      if Length(parts) <> 4 then Continue;
      SetBinding(action, StrToIntDef(parts[0], 0),
        parts[1] = '1', parts[2] = '1', parts[3] = '1');
    end;
  finally
    names.Free;
    ini.Free;
  end;
end;

procedure THotkeyMap.Save(const AFileName: string);
var
  ini: TIniFile;
  i: Integer;
  b: THotkeyBinding;
  val: string;
begin
  ForceDirectories(ExtractFileDir(AFileName));
  ini := TIniFile.Create(AFileName);
  try
    ini.EraseSection('Hotkeys');
    for i := 0 to High(FBindings) do
    begin
      b := FBindings[i];
      val := Format('%d,%d,%d,%d', [b.Key, Ord(b.Shift), Ord(b.Ctrl), Ord(b.Alt)]);
      ini.WriteString('Hotkeys', ActionName(b.Action), val);
    end;
  finally
    ini.Free;
  end;
end;

end.
