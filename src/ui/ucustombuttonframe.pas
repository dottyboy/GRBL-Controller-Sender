unit ucustombuttonframe;

{ TCustomButtonFrame: the "Macros" tab (plan Phase 14) - a flat grid editor
  for the macro-button library, structurally identical to
  umaterialpresetframe.pas (own tab, not a modal dialog). A modal dialog
  with a TStringGrid was tried first and hit a real, 100%-reproducible X11
  "BadWindow"/X_GetProperty crash specific to this environment - confirmed
  by testing that this codebase's ONLY other TStringGrid-in-a-freshly-
  created-TForm usage doesn't exist anywhere else (every other TStringGrid
  lives in a TFrame that's part of the app's permanent object tree from
  startup, never a dynamically shown-and-destroyed modal) - so this frame/
  tab design sidesteps the issue entirely by reusing the already-proven
  pattern instead of chasing the Qt5/LCL root cause under time pressure. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, StdCtrls, ExtCtrls, Grids,
  ucustombutton, ucustombuttonstore, ui18n;

const
  COL_NAME = 0;
  COL_GCODE = 1;

type

  { TCustomButtonFrame }

  TCustomButtonFrame = class(TFrame)
    BtnAdd: TButton;
    BtnDelete: TButton;
    Grid: TStringGrid;
    LblHint: TLabel;
    ToolBar: TPanel;
    procedure BtnAddClick(Sender: TObject);
    procedure BtnDeleteClick(Sender: TObject);
    procedure GridEditingDone(Sender: TObject);
  private
    FStore: TCustomButtonStore;
    procedure LoadButtons;
    procedure SaveButtons;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

{$R *.frm}

{ TCustomButtonFrame }

constructor TCustomButtonFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Grid.Cells[COL_NAME, 0] := 'Name';
  Grid.Cells[COL_GCODE, 0] := 'G-code (use | to separate lines)';
  FStore := TCustomButtonStore.Create(
    IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'custombuttons.ini');
  LoadButtons;
end;

destructor TCustomButtonFrame.Destroy;
begin
  FStore.Free;
  inherited Destroy;
end;

procedure TCustomButtonFrame.LoadButtons;
var
  buttons: TCustomButtonArray;
  i: Integer;
begin
  buttons := FStore.LoadAll;
  Grid.RowCount := Max(2, Length(buttons) + 1);
  for i := 0 to High(buttons) do
  begin
    Grid.Cells[COL_NAME, i + 1] := buttons[i].Name;
    Grid.Cells[COL_GCODE, i + 1] := StringReplace(buttons[i].GCode, LineEnding, '|', [rfReplaceAll]);
  end;
end;

procedure TCustomButtonFrame.SaveButtons;
var
  buttons: TCustomButtonArray;
  row, n: Integer;
begin
  SetLength(buttons, Grid.RowCount - 1);
  n := 0;
  for row := 1 to Grid.RowCount - 1 do
  begin
    if Trim(Grid.Cells[COL_NAME, row]) = '' then Continue;
    buttons[n].Name := Grid.Cells[COL_NAME, row];
    buttons[n].GCode := StringReplace(Grid.Cells[COL_GCODE, row], '|', LineEnding, [rfReplaceAll]);
    Inc(n);
  end;
  SetLength(buttons, n);
  FStore.SaveAll(buttons);
end;

procedure TCustomButtonFrame.BtnAddClick(Sender: TObject);
begin
  Grid.RowCount := Grid.RowCount + 1;
  Grid.Cells[COL_NAME, Grid.RowCount - 1] := DefaultCustomButton.Name;
  SaveButtons;
end;

procedure TCustomButtonFrame.BtnDeleteClick(Sender: TObject);
begin
  if (Grid.RowCount > 2) and (Grid.Row >= 1) then
  begin
    Grid.DeleteRow(Grid.Row);
    SaveButtons;
  end;
end;

procedure TCustomButtonFrame.GridEditingDone(Sender: TObject);
begin
  SaveButtons;
end;

end.
