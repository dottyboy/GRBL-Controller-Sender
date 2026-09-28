unit uportlist;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

// Enumerate likely GRBL/USB-serial device nodes on Linux
// (/dev/ttyUSB*, /dev/ttyACM*). bCNC's FilePage does the equivalent via
// Python's glob.glob('/dev/ttyUSB*') + '/dev/ttyACM*' (Utils.py serialPorts()).
procedure ListSerialPorts(AList: TStringList);

implementation

procedure ScanPattern(AList: TStrings; const APrefix: string);
var
  Info: TSearchRec;
begin
  if FindFirst('/dev/' + APrefix + '*', faAnyFile, Info) = 0 then
  begin
    repeat
      AList.Add('/dev/' + Info.Name);
    until FindNext(Info) <> 0;
    FindClose(Info);
  end;
end;

procedure ListSerialPorts(AList: TStringList);
begin
  AList.Clear;
  ScanPattern(AList, 'ttyUSB');
  ScanPattern(AList, 'ttyACM');
  AList.Sort;
end;

end.
