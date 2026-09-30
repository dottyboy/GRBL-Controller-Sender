unit ucustombutton;

{ TCustomButton: one saved macro button (plan Phase 14) - a name plus a
  g-code snippet of one or more lines. LCL-free, shared by the store
  (ucustombuttonstore.pas) and the management UI (ucustombuttonform.pas).

  Plan Phase 37 adds RunOnJobStart/RunOnJobEnd: a button flagged either
  way fires automatically at job-enqueue time (not just on a manual
  click) for BOTH laser jobs (LaserControlFrame) and plain CNC streaming
  (EditorFrame) - see usender.pas's own new BeginJob/EndJob, the shared
  call site both paths now go through. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TCustomButton = record
    Name: string;
    GCode: string; // one or more lines, joined by LineEnding
    RunOnJobStart: Boolean;
    RunOnJobEnd: Boolean;
  end;

  TCustomButtonArray = array of TCustomButton;

function DefaultCustomButton: TCustomButton;

{ CombinedAutoRunGCode: every button flagged RunOnJobStart (AOnStart=True)
  or RunOnJobEnd (AOnStart=False), in array order, each line appended to
  ALines (does not clear ALines first - the caller decides whether this
  is the whole queue addition or one part of a larger one). }
procedure CombinedAutoRunGCode(const AButtons: TCustomButtonArray;
  AOnStart: Boolean; ALines: TStrings);

implementation

function DefaultCustomButton: TCustomButton;
begin
  Result.Name := 'New button';
  Result.GCode := '';
  Result.RunOnJobStart := False;
  Result.RunOnJobEnd := False;
end;

procedure CombinedAutoRunGCode(const AButtons: TCustomButtonArray;
  AOnStart: Boolean; ALines: TStrings);
var
  i: Integer;
  flagged: Boolean;
  snippet: TStringList;
  j: Integer;
begin
  snippet := TStringList.Create;
  try
    for i := 0 to High(AButtons) do
    begin
      if AOnStart then flagged := AButtons[i].RunOnJobStart
      else flagged := AButtons[i].RunOnJobEnd;
      if not flagged then Continue;
      snippet.Text := AButtons[i].GCode;
      for j := 0 to snippet.Count - 1 do
        if Trim(snippet[j]) <> '' then
          ALines.Add(snippet[j]);
    end;
  finally
    snippet.Free;
  end;
end;

end.
