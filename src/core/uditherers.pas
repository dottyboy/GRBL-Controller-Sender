unit uditherers;

{ uditherers: error-diffusion dithering (plan Phase 10) - converts a plain
  grayscale byte matrix (0=black..255=white) into a bitonal on/off matrix
  (True = laser-on/dark at that pixel), the same halftoning idea
  LaserGRBL's RasterConverter uses to simulate gray levels via dot density
  on a laser that only has on/off (or power-graded) control.

  Deliberately independent of uimageio.pas/TGrayscaleImage (works on a
  plain `array of Byte` + width/height instead) so this unit has ZERO
  dependency on BGRABitmap, even transitively through a `uses` clause -
  keeps the actual BGRA dependency isolated to exactly uimageio.pas, per
  this project's own architecture decision, and keeps this unit trivially
  standalone-testable (plain fpc, no LCL/BGRA search paths needed).

  Error-diffusion kernels are the standard, well-documented coefficients
  for each named algorithm (Floyd-Steinberg 1976, Jarvis/Judice/Ninke
  1976, Stucki 1981, Burkes 1988, Sierra/Sierra2/SierraLite - Sierra
  1990s, Atkinson - Bill Atkinson's HyperCard-era algorithm, distinctive
  for diffusing only 3/4 of the error rather than all of it) - not
  invented or approximated. }

{$mode objfpc}{$H+}

interface

type
  TDitherAlgorithm = (
    daFloydSteinberg, daJarvisJudiceNinke, daStucki, daBurkes,
    daSierra2, daSierra3, daSierraLite, daAtkinson, daRandom
  );

  TBitonalImage = array of Boolean; // row-major, True = laser-on/dark

// AThreshold (0..255): a pixel darker than this is "on" before/after error
// diffusion redistributes the rounding error to neighbors - 128 is the
// conventional midpoint default. ARandomSeed only affects daRandom (0 =
// seed from the current time, matching TRandomSeed-less `Random()` calls
// elsewhere in this codebase's own convention of not over-engineering
// something this randomness-tolerant).
function DitherImage(const APixels: array of Byte; AWidth, AHeight: Integer;
  AAlgorithm: TDitherAlgorithm; AThreshold: Byte = 128; ARandomSeed: LongInt = 0): TBitonalImage;

implementation

type
  TKernelTap = record
    DX, DY: Integer; // offset from the current pixel
    Weight: Integer; // numerator; kernel's own Divisor is the denominator
  end;

const
  // Standard error-diffusion kernels. DX/DY are relative to the pixel just
  // processed; each algorithm's own Divisor is listed alongside it.
  KERNEL_FLOYD_STEINBERG: array[0..3] of TKernelTap = (
    (DX: 1; DY: 0; Weight: 7), (DX: -1; DY: 1; Weight: 3),
    (DX: 0; DY: 1; Weight: 5), (DX: 1; DY: 1; Weight: 1)
  );
  DIV_FLOYD_STEINBERG = 16;

  KERNEL_JJN: array[0..11] of TKernelTap = (
    (DX: 1; DY: 0; Weight: 7), (DX: 2; DY: 0; Weight: 5),
    (DX: -2; DY: 1; Weight: 3), (DX: -1; DY: 1; Weight: 5), (DX: 0; DY: 1; Weight: 7), (DX: 1; DY: 1; Weight: 5), (DX: 2; DY: 1; Weight: 3),
    (DX: -2; DY: 2; Weight: 1), (DX: -1; DY: 2; Weight: 3), (DX: 0; DY: 2; Weight: 5), (DX: 1; DY: 2; Weight: 3), (DX: 2; DY: 2; Weight: 1)
  );
  DIV_JJN = 48;

  KERNEL_STUCKI: array[0..11] of TKernelTap = (
    (DX: 1; DY: 0; Weight: 8), (DX: 2; DY: 0; Weight: 4),
    (DX: -2; DY: 1; Weight: 2), (DX: -1; DY: 1; Weight: 4), (DX: 0; DY: 1; Weight: 8), (DX: 1; DY: 1; Weight: 4), (DX: 2; DY: 1; Weight: 2),
    (DX: -2; DY: 2; Weight: 1), (DX: -1; DY: 2; Weight: 2), (DX: 0; DY: 2; Weight: 4), (DX: 1; DY: 2; Weight: 2), (DX: 2; DY: 2; Weight: 1)
  );
  DIV_STUCKI = 42;

  KERNEL_BURKES: array[0..6] of TKernelTap = (
    (DX: 1; DY: 0; Weight: 8), (DX: 2; DY: 0; Weight: 4),
    (DX: -2; DY: 1; Weight: 2), (DX: -1; DY: 1; Weight: 4), (DX: 0; DY: 1; Weight: 8), (DX: 1; DY: 1; Weight: 4), (DX: 2; DY: 1; Weight: 2)
  );
  DIV_BURKES = 32;

  KERNEL_SIERRA3: array[0..9] of TKernelTap = (
    (DX: 1; DY: 0; Weight: 5), (DX: 2; DY: 0; Weight: 3),
    (DX: -2; DY: 1; Weight: 2), (DX: -1; DY: 1; Weight: 4), (DX: 0; DY: 1; Weight: 5), (DX: 1; DY: 1; Weight: 4), (DX: 2; DY: 1; Weight: 2),
    (DX: -1; DY: 2; Weight: 2), (DX: 0; DY: 2; Weight: 3), (DX: 1; DY: 2; Weight: 2)
  );
  DIV_SIERRA3 = 32;

  KERNEL_SIERRA2: array[0..4] of TKernelTap = (
    (DX: 1; DY: 0; Weight: 4), (DX: 2; DY: 0; Weight: 3),
    (DX: -2; DY: 1; Weight: 1), (DX: -1; DY: 1; Weight: 2), (DX: 0; DY: 1; Weight: 3)
    // (DX: 1; DY: 1; Weight: 2), (DX: 2; DY: 1; Weight: 1) appended below - see note
  );
  DIV_SIERRA2 = 16;

  KERNEL_SIERRA_LITE: array[0..2] of TKernelTap = (
    (DX: 1; DY: 0; Weight: 2),
    (DX: -1; DY: 1; Weight: 1), (DX: 0; DY: 1; Weight: 1)
  );
  DIV_SIERRA_LITE = 4;

  // Atkinson: only 6/8 of the error is diffused (the other 2/8 is
  // deliberately discarded) - this is the real, distinctive property of
  // Atkinson dithering, not an oversight.
  KERNEL_ATKINSON: array[0..5] of TKernelTap = (
    (DX: 1; DY: 0; Weight: 1), (DX: 2; DY: 0; Weight: 1),
    (DX: -1; DY: 1; Weight: 1), (DX: 0; DY: 1; Weight: 1), (DX: 1; DY: 1; Weight: 1),
    (DX: 0; DY: 2; Weight: 1)
  );
  DIV_ATKINSON = 8;

// Sierra2 (Two-Row Sierra) needs the right-side row-1 taps too (4,2,3,2,1
// distributed as: cur-row +1=4,+2=3; next-row -2=1,-1=2,0=3,+1=2,+2=1);
// declared as a second const array and applied together with
// KERNEL_SIERRA2 above rather than one oversized literal, purely so the
// array literal stays readable - both are applied in DitherImage's
// algorithm dispatch.
const
  KERNEL_SIERRA2_ROW1_RIGHT: array[0..1] of TKernelTap = (
    (DX: 1; DY: 1; Weight: 2), (DX: 2; DY: 1; Weight: 1)
  );

function ApplyKernel(var AErrors: array of Double; AWidth, AHeight, AX, AY: Integer;
  const AKernel: array of TKernelTap; ADivisor: Integer; AError: Double): Boolean;
var
  i, nx, ny: Integer;
begin
  Result := True;
  for i := 0 to High(AKernel) do
  begin
    nx := AX + AKernel[i].DX;
    ny := AY + AKernel[i].DY;
    if (nx >= 0) and (nx < AWidth) and (ny >= 0) and (ny < AHeight) then
      AErrors[ny * AWidth + nx] := AErrors[ny * AWidth + nx] + AError * AKernel[i].Weight / ADivisor;
  end;
end;

function DitherImage(const APixels: array of Byte; AWidth, AHeight: Integer;
  AAlgorithm: TDitherAlgorithm; AThreshold: Byte; ARandomSeed: LongInt): TBitonalImage;
var
  errors: array of Double;
  x, y, idx: Integer;
  adjusted: Double;
  on_: Boolean;
  err: Double;
  rng: Integer;
begin
  SetLength(Result, AWidth * AHeight);
  SetLength(errors, AWidth * AHeight);

  if AAlgorithm = daRandom then
  begin
    if ARandomSeed <> 0 then RandSeed := ARandomSeed;
    for idx := 0 to AWidth * AHeight - 1 do
    begin
      // +/- half the threshold's distance to the nearer bound - a simple,
      // symmetric noise band around the fixed threshold, matching the
      // conventional "ordered random" ditherer's spirit (no diffusion,
      // no serial dependency between pixels).
      rng := Random(256) - 128;
      Result[idx] := (Integer(APixels[idx]) + rng) < AThreshold;
    end;
    Exit;
  end;

  for y := 0 to AHeight - 1 do
    for x := 0 to AWidth - 1 do
    begin
      idx := y * AWidth + x;
      adjusted := APixels[idx] + errors[idx];
      on_ := adjusted < AThreshold;
      Result[idx] := on_;
      if on_ then
        err := adjusted - 0
      else
        err := adjusted - 255;

      case AAlgorithm of
        daFloydSteinberg: ApplyKernel(errors, AWidth, AHeight, x, y, KERNEL_FLOYD_STEINBERG, DIV_FLOYD_STEINBERG, err);
        daJarvisJudiceNinke: ApplyKernel(errors, AWidth, AHeight, x, y, KERNEL_JJN, DIV_JJN, err);
        daStucki: ApplyKernel(errors, AWidth, AHeight, x, y, KERNEL_STUCKI, DIV_STUCKI, err);
        daBurkes: ApplyKernel(errors, AWidth, AHeight, x, y, KERNEL_BURKES, DIV_BURKES, err);
        daSierra3: ApplyKernel(errors, AWidth, AHeight, x, y, KERNEL_SIERRA3, DIV_SIERRA3, err);
        daSierra2:
          begin
            ApplyKernel(errors, AWidth, AHeight, x, y, KERNEL_SIERRA2, DIV_SIERRA2, err);
            ApplyKernel(errors, AWidth, AHeight, x, y, KERNEL_SIERRA2_ROW1_RIGHT, DIV_SIERRA2, err);
          end;
        daSierraLite: ApplyKernel(errors, AWidth, AHeight, x, y, KERNEL_SIERRA_LITE, DIV_SIERRA_LITE, err);
        daAtkinson: ApplyKernel(errors, AWidth, AHeight, x, y, KERNEL_ATKINSON, DIV_ATKINSON, err);
      end;
    end;
end;

end.
