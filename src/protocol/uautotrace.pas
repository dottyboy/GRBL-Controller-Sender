unit uautotrace;

{ uautotrace: shells to the system `autotrace` tool in centerline mode
  (plan Phase 12) - mirrors the already-established external-tool pattern
  (PlatformIO/avrdude in the Firmware Builder phases). Writes a plain PGM
  (portable graymap) from a TGrayscaleImage - a trivial, dependency-free
  format this unit can write itself with zero risk of an unsupported input
  format, rather than assuming autotrace's own build supports PNG/whatever
  BGRA could export.

  Runs SYNCHRONOUSLY (TProcess + poWaitOnExit), not through the async
  uprocessrunner.pas used for long Firmware Builder compiles - a single
  autotrace invocation on a small image is fast enough that a blocking
  call is the simpler, more directly testable choice here, same reasoning
  Phase G's XMODEM transfer already used for its own synchronous exchange.

  DISCLOSED, real limitation: the `autotrace` binary is not installed in
  this development environment (confirmed: neither present on PATH nor
  findable via `apt-cache search`), so this unit's actual invocation
  against a real binary is UNVERIFIED - the CLI flags used here match
  autotrace's own real, long-documented command-line syntax (not
  guessed), and the PGM writer/output-SVG parsing are each independently
  correct and tested on their own terms, but the end-to-end round trip
  through a genuine `autotrace` process has not been exercised. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process, uimageio, usvgimport;

// Writes AImage as a binary PGM (P5) file - real 0=black..255=white
// grayscale, no external dependency at all.
function WriteGrayscalePGM(const AImage: TGrayscaleImage; const AFileName: string): Boolean;

// Exported (not just a local implementation helper) so both the real
// centerline flow and standalone verification can check it directly.
function FindOnPath(const AExeName: string): string;

// Runs `autotrace -centerline -output-format svg -output-file <out> <in>`
// on AImage (written to a temp PGM first), parses the resulting SVG via
// usvgimport.pas. Returns False (with AError set) if the binary isn't
// found, the process fails, or the output can't be parsed.
function RunAutotraceCenterline(const AImage: TGrayscaleImage;
  out AShapes: TSvgShapeArray; out AError: string): Boolean;

implementation

function FindOnPath(const AExeName: string): string;
var
  dirs: TStringArray;
  i: Integer;
  candidate: string;
begin
  Result := '';
  dirs := GetEnvironmentVariable('PATH').Split(':');
  for i := 0 to High(dirs) do
  begin
    if dirs[i] = '' then Continue;
    candidate := IncludeTrailingPathDelimiter(dirs[i]) + AExeName;
    if FileExists(candidate) then
    begin
      Result := candidate;
      Exit;
    end;
  end;
end;

function WriteGrayscalePGM(const AImage: TGrayscaleImage; const AFileName: string): Boolean;
var
  f: TFileStream;
  header: string;
  i: Integer;
  buf: array of Byte;
begin
  Result := False;
  if (AImage.Width <= 0) or (AImage.Height <= 0) then Exit;
  try
    f := TFileStream.Create(AFileName, fmCreate);
    try
      header := Format('P5'#10'%d %d'#10'255'#10, [AImage.Width, AImage.Height]);
      f.WriteBuffer(header[1], Length(header));
      SetLength(buf, Length(AImage.Pixels));
      for i := 0 to High(AImage.Pixels) do
        buf[i] := AImage.Pixels[i];
      if Length(buf) > 0 then
        f.WriteBuffer(buf[0], Length(buf));
      Result := True;
    finally
      f.Free;
    end;
  except
    Result := False;
  end;
end;

function RunAutotraceCenterline(const AImage: TGrayscaleImage;
  out AShapes: TSvgShapeArray; out AError: string): Boolean;
var
  proc: TProcess;
  inFile, outFile, exe: string;
begin
  Result := False;
  AError := '';
  SetLength(AShapes, 0);

  exe := FindOnPath('autotrace');
  if exe = '' then
  begin
    AError := 'autotrace not found on PATH';
    Exit;
  end;

  inFile := GetTempDir(False) + 'gcs_autotrace_in.pgm';
  outFile := GetTempDir(False) + 'gcs_autotrace_out.svg';

  if not WriteGrayscalePGM(AImage, inFile) then
  begin
    AError := 'Could not write temporary PGM file';
    Exit;
  end;

  proc := TProcess.Create(nil);
  try
    proc.Executable := exe;
    proc.Parameters.Add('-centerline');
    proc.Parameters.Add('-output-format');
    proc.Parameters.Add('svg');
    proc.Parameters.Add('-output-file');
    proc.Parameters.Add(outFile);
    proc.Parameters.Add(inFile);
    proc.Options := [poWaitOnExit, poUsePipes];
    try
      proc.Execute;
    except
      on E: Exception do
      begin
        AError := E.Message;
        Exit;
      end;
    end;

    if proc.ExitStatus <> 0 then
    begin
      AError := Format('autotrace exited with status %d', [proc.ExitStatus]);
      Exit;
    end;
  finally
    proc.Free;
  end;

  if not FileExists(outFile) then
  begin
    AError := 'autotrace did not produce an output file';
    Exit;
  end;

  Result := LoadSvgShapes(outFile, AShapes, AError);
end;

end.
