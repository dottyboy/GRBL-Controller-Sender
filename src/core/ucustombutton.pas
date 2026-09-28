unit ucustombutton;

{ TCustomButton: one saved macro button (plan Phase 14) - a name plus a
  g-code snippet of one or more lines. LCL-free, shared by the store
  (ucustombuttonstore.pas) and the management UI (ucustombuttonform.pas). }

{$mode objfpc}{$H+}

interface

type
  TCustomButton = record
    Name: string;
    GCode: string; // one or more lines, joined by LineEnding
  end;

  TCustomButtonArray = array of TCustomButton;

function DefaultCustomButton: TCustomButton;

implementation

function DefaultCustomButton: TCustomButton;
begin
  Result.Name := 'New button';
  Result.GCode := '';
end;

end.
