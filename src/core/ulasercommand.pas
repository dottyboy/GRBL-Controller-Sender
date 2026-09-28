unit ulasercommand;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ugcode;

type
  TLaserCommandStatus = (lsQueued, lsSent, lsGood, lsBad);

  { TLaserCommand: one parsed g-code line, laser-relevant flags only -
    scoped-down analog of LaserGRBL's GrblCommand.cs (IsMovement/IsM3/IsM4/
    IsLaserON/IsLaserOFF/CommandStatus). Full modal-state replay (what X/Y/Z
    the machine is actually AT after this line) is deliberately NOT done
    here - that's ustatebuilder.pas's job (plan Phase 5); this record only
    describes what the line itself says. }
  TLaserCommand = record
    RawText: string;
    LineNumber: Integer;
    GCode: Integer;       // explicit motion word on this line: 0,1,2,3, or -1
    IsMovement: Boolean;   // GCode in [0..3]
    IsM3: Boolean;
    IsM4: Boolean;
    IsM5: Boolean;
    IsLaserOn: Boolean;    // IsM3 or IsM4
    IsLaserOff: Boolean;   // IsM5
    HasS: Boolean;
    SValue: Double;
    Status: TLaserCommandStatus;
  end;

  TLaserCommandArray = array of TLaserCommand;

  { TLaserProgram: the parsed body of a laser job (one TLaserCommand per
    non-blank g-code line) plus user-editable Header/Footer text blocks
    assembled around N repeated passes of the body - mirrors LaserGRBL's
    GrblFile.SaveGCODE header/passes/footer injection, but as a build-time
    assembly step (BuildProgram) rather than baked into a loaded file. }
  TLaserProgram = class
  private
    FCommands: TLaserCommandArray;
    FCount: Integer;
    FHeader: TStringList;
    FFooter: TStringList;
    procedure ParseCommand(const ALine: string; ALineNumber: Integer; out ACmd: TLaserCommand);
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromLines(ALines: TStrings);
    procedure Clear;
    // Header + (body repeated APassCount times) + Footer. APassCount < 1
    // is treated as 1. Caller owns and frees the returned TStringList.
    function BuildProgram(APassCount: Integer): TStringList;
    property Commands: TLaserCommandArray read FCommands;
    property Count: Integer read FCount;
    property Header: TStringList read FHeader;
    property Footer: TStringList read FFooter;
  end;

implementation

{ TLaserProgram }

constructor TLaserProgram.Create;
begin
  inherited Create;
  FHeader := TStringList.Create;
  FFooter := TStringList.Create;
end;

destructor TLaserProgram.Destroy;
begin
  FFooter.Free;
  FHeader.Free;
  inherited Destroy;
end;

procedure TLaserProgram.ParseCommand(const ALine: string; ALineNumber: Integer; out ACmd: TLaserCommand);
var
  tokens: TStringArray;
  i: Integer;
  tok: string;
  c: Char;
  value: Double;
  gcode, mcode: Integer;
begin
  ACmd.RawText := ALine;
  ACmd.LineNumber := ALineNumber;
  ACmd.GCode := -1;
  ACmd.IsMovement := False;
  ACmd.IsM3 := False;
  ACmd.IsM4 := False;
  ACmd.IsM5 := False;
  ACmd.IsLaserOn := False;
  ACmd.IsLaserOff := False;
  ACmd.HasS := False;
  ACmd.SValue := 0;
  ACmd.Status := lsQueued;

  tokens := TokenizeGCodeLine(ALine);
  for i := 0 to High(tokens) do
  begin
    tok := tokens[i];
    if tok = '' then Continue;
    c := tok[1];
    value := StrToFloatDef(Copy(tok, 2, Length(tok) - 1), 0);
    case c of
      'G':
        begin
          gcode := Trunc(value);
          if gcode in [0, 1, 2, 3] then
          begin
            ACmd.GCode := gcode;
            ACmd.IsMovement := True;
          end;
        end;
      'M':
        begin
          mcode := Trunc(value);
          case mcode of
            3: begin ACmd.IsM3 := True; ACmd.IsLaserOn := True; end;
            4: begin ACmd.IsM4 := True; ACmd.IsLaserOn := True; end;
            5: begin ACmd.IsM5 := True; ACmd.IsLaserOff := True; end;
          end;
        end;
      'S':
        begin
          ACmd.HasS := True;
          ACmd.SValue := value;
        end;
    end;
  end;
end;

procedure TLaserProgram.LoadFromLines(ALines: TStrings);
var
  i: Integer;
begin
  FCount := 0;
  SetLength(FCommands, ALines.Count);
  for i := 0 to ALines.Count - 1 do
  begin
    if Trim(ALines[i]) = '' then Continue;
    ParseCommand(ALines[i], i + 1, FCommands[FCount]);
    Inc(FCount);
  end;
  SetLength(FCommands, FCount);
end;

procedure TLaserProgram.Clear;
begin
  FCount := 0;
  SetLength(FCommands, 0);
end;

function TLaserProgram.BuildProgram(APassCount: Integer): TStringList;
var
  i, p: Integer;
begin
  Result := TStringList.Create;
  if APassCount < 1 then APassCount := 1;

  for i := 0 to FHeader.Count - 1 do
    Result.Add(FHeader[i]);

  for p := 1 to APassCount do
    for i := 0 to FCount - 1 do
      Result.Add(FCommands[i].RawText);

  for i := 0 to FFooter.Count - 1 do
    Result.Add(FFooter[i]);
end;

end.
