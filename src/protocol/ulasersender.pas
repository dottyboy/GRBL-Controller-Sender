unit ulasersender;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ulasercommand, usender;

// RunLaserProgram: switches ASender into laser mode (see TSender.IsLaserMode
// in usender.pas - this is what makes every abort path force-enqueue M5)
// and enqueues Header + APassCount repeats of the body + Footer, built via
// AProgram.BuildProgram.
procedure RunLaserProgram(ASender: TSender; AProgram: TLaserProgram; APassCount: Integer = 1);

// AbortLaserProgram: stops streaming; because IsLaserMode is already True
// from RunLaserProgram, TSenderThread.Execute guarantees M5 is sent right
// after the queue is cleared - see usender.pas.
procedure AbortLaserProgram(ASender: TSender);

// ContinueLaserProgramFromLine: resumes from AProgram.Commands[ALineIndex]
// onward (Footer still appended), forcing M5 first. Does NOT yet replay
// modal state to reposition the machine before resuming - that safety
// piece (state replay -> laser-off repositioning move) is added on top of
// this in ustatebuilder.pas (plan Phase 5); until then this only
// guarantees the laser is off, it does not guarantee correct position.
procedure ContinueLaserProgramFromLine(ASender: TSender; AProgram: TLaserProgram; ALineIndex: Integer);

implementation

procedure RunLaserProgram(ASender: TSender; AProgram: TLaserProgram; APassCount: Integer = 1);
var
  lines: TStringList;
begin
  ASender.IsLaserMode := True;
  lines := AProgram.BuildProgram(APassCount);
  try
    ASender.EnqueueLines(lines);
  finally
    lines.Free;
  end;
end;

procedure AbortLaserProgram(ASender: TSender);
begin
  ASender.StopStreaming;
end;

procedure ContinueLaserProgramFromLine(ASender: TSender; AProgram: TLaserProgram; ALineIndex: Integer);
var
  i: Integer;
  lines: TStringList;
begin
  ASender.IsLaserMode := True;
  lines := TStringList.Create;
  try
    lines.Add('M5');
    if ALineIndex < 0 then ALineIndex := 0;
    for i := ALineIndex to AProgram.Count - 1 do
      lines.Add(AProgram.Commands[i].RawText);
    for i := 0 to AProgram.Footer.Count - 1 do
      lines.Add(AProgram.Footer[i]);
    ASender.EnqueueLines(lines);
  finally
    lines.Free;
  end;
end;

end.
