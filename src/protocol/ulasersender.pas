unit ulasersender;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ulasercommand, usender, ustatebuilder;

// RunLaserProgram: switches ASender into laser mode (see TSender.IsLaserMode
// in usender.pas - this is what makes every abort path force-enqueue M5)
// and enqueues Header + APassCount repeats of the body + Footer, built via
// AProgram.BuildProgram. Also starts fresh Sent/Executed progress tracking
// (plan Phase 5) against AProgram's own body list, single-pass - see
// TSender.BeginLaserJob's doc comment for the multi-pass caveat.
procedure RunLaserProgram(ASender: TSender; AProgram: TLaserProgram; APassCount: Integer = 1);

// AbortLaserProgram: stops streaming; because IsLaserMode is already True
// from RunLaserProgram, TSenderThread.Execute guarantees M5 is sent right
// after the queue is cleared - see usender.pas.
procedure AbortLaserProgram(ASender: TSender);

// ContinueLaserProgramFromLine: resumes from AProgram.Commands[ALineIndex]
// onward (Footer still appended). Unlike a bare "M5 then keep going", this
// replays the program's own modal/positional state up to ALineIndex
// (ustatebuilder.pas, plan Phase 5) and issues a safe M5-then-reposition
// preamble first: laser off -> optional $H/$X -> units/WCS/plane restored
// -> G0 move to the exact last-known X/Y/Z with the laser still off ->
// feed/coolant modals restored -> the laser only re-arms (M3/M4+S) AFTER
// the machine is back in position. AOpts controls homing/unlock and WCO
// restoration - see TResumeOptions in ustatebuilder.pas.
procedure ContinueLaserProgramFromLine(ASender: TSender; AProgram: TLaserProgram;
  ALineIndex: Integer; const AOpts: TResumeOptions);

implementation

procedure RunLaserProgram(ASender: TSender; AProgram: TLaserProgram; APassCount: Integer = 1);
var
  lines: TStringList;
  bodyOnly: TStringList;
  i: Integer;
begin
  ASender.IsLaserMode := True;
  lines := AProgram.BuildProgram(APassCount);
  try
    // BeginLaserJob copies whatever it's handed (see its own comment in
    // usender.pas), so this locally-scoped list only needs to outlive the
    // BeginLaserJob call itself, not the run - build the flat text view
    // once here rather than changing AProgram.Commands' typed-array shape.
    bodyOnly := TStringList.Create;
    try
      for i := 0 to AProgram.Count - 1 do
        bodyOnly.Add(AProgram.Commands[i].RawText);
      ASender.BeginLaserJob(bodyOnly, AProgram.Footer, AProgram.Header.Count);
    finally
      bodyOnly.Free;
    end;
    ASender.EnqueueLines(lines);
  finally
    lines.Free;
  end;
end;

procedure AbortLaserProgram(ASender: TSender);
begin
  ASender.StopStreaming;
end;

procedure ContinueLaserProgramFromLine(ASender: TSender; AProgram: TLaserProgram;
  ALineIndex: Integer; const AOpts: TResumeOptions);
var
  i: Integer;
  bodyLines: TStringList;
begin
  bodyLines := TStringList.Create;
  try
    for i := 0 to AProgram.Count - 1 do
      bodyLines.Add(AProgram.Commands[i].RawText);
    // Establishes tracking against the FULL body first (HeaderCount=0, so
    // ResumeLaserJob's own state replay starts from line 0 of THIS body,
    // not wherever a prior/unrelated job left off), then ResumeLaserJob
    // does the actual replay + M5-reposition preamble + trim + re-enqueue -
    // the same logic path the crash-recovery dialog in umain.pas uses, so
    // an explicit "resume a loaded file" action and real crash recovery
    // can never silently diverge in behavior.
    ASender.BeginLaserJob(bodyLines, AProgram.Footer, 0);
    ASender.ResumeLaserJob(ALineIndex, AOpts);
  finally
    bodyLines.Free;
  end;
end;

end.
