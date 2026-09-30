unit udepthmap;

{ udepthmap: Phase 23's photo -> depth-map pipeline. Ported concept (not
  ported code) from Universal-G-Code-Sender's ugs-designer module
  (AbstractOnnxDepthModel.java/DepthAnythingModel.java, read directly) -
  same preprocessing (resize to a fixed square, ImageNet mean/std
  normalize, CHW layout), same ONNX Runtime C API call shape, same
  hand-rolled center-aligned bilinear resize-back for the output.

  Model: depth-anything-v2-small (onnx-community/depth-anything-v2-small
  on HuggingFace, Apache-2.0 - verified via the model card before writing
  this unit, not assumed), input tensor "pixel_values" [1,3,518,518]
  float32, output tensor "predicted_depth" [1,518,518] float32 (verified
  directly from the .onnx file's own graph via Python's onnx package, not
  guessed - 518 is an exact multiple of the model's 14px ViT patch size,
  so no output-shape rounding to account for).

  Deliberately LCL-free and BGRABitmap-free (this project's own
  architecture rule - see uimageio.pas's own header comment): image
  decode/resize is delegated to uimageio.LoadRGBImageResized, the one
  unit allowed to touch BGRABitmap. ONNX Runtime itself is delegated to
  uonnxruntime.pas. This unit only does the numeric preprocess/postprocess
  glue between the two. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, uimageio, uonnxruntime;

const
  DEPTH_MODEL_INPUT_SIZE = 518;
  DEPTH_INPUT_TENSOR_NAME = 'pixel_values';
  DEPTH_OUTPUT_TENSOR_NAME = 'predicted_depth';

  // ImageNet normalization, exactly as depth-anything-v2's own
  // preprocessor_config.json declares (verified, not guessed).
  DEPTH_MEAN: array[0..2] of Single = (0.485, 0.456, 0.406);
  DEPTH_STD: array[0..2] of Single = (0.229, 0.224, 0.225);

type
  TDepthMapImage = record
    Width, Height: Integer;
    // row-major, one byte/pixel, min-max normalized: 255 = nearest point
    // in the photo, 0 = farthest - matches depth-anything's own
    // convention (higher raw output = closer).
    Pixels: array of Byte;
  end;

{ Runs the full pipeline: load+resize APhotoPath, normalize, run the ONNX
  model at AModelPath via the ONNX Runtime shared library at
  AOnnxRuntimeLibPath, then resize the resulting depth map back to the
  photo's own original dimensions. Loads/releases the ONNX Runtime library
  fresh each call - this runs once per user action (loading a photo), not
  in a hot loop, so the simplicity of not keeping a session alive across
  calls is worth more here than the reload cost. }
function GenerateDepthMap(const APhotoPath, AModelPath, AOnnxRuntimeLibPath: string;
  out ADepthMap: TDepthMapImage; out AError: string): Boolean;

function DepthAt(const AImage: TDepthMapImage; AX, AY: Integer): Byte; inline;

{ Where this feature's two non-vendored runtime dependencies live: an
  `onnx-models` folder right next to the running executable - same
  "ExtractFilePath(ParamStr(0)) + '<name>' + PathDelim" convention
  src/ui/ufirmwarebuilderframe.pas already uses for its own `references/`
  folder, so it resolves identically whether run from a plain dev build
  (project root) or packaging/appimage/build-appimage.sh's AppImage
  (which populates this exact folder inside usr/bin/). Neither file is
  vendored into this git repo (~16MB/~99MB) - see that script and
  THIRD-PARTY-NOTICES.md's Phase 23 section for where they come from. }
function DefaultOnnxRuntimeLibPath: string;
function DefaultDepthModelPath: string;

{ The three pure numeric steps of the pipeline above, exposed so they can
  be standalone-tested (against the Python reference dumps in
  tools/onnxruntime/) without needing BGRABitmap/ONNX Runtime at all - see
  this project's standing "standalone-test LCL-free core units" rule. }

{ Preprocesses ARGB (DEPTH_MODEL_INPUT_SIZE square, RGB byte triplets) into
  the CHW float32 tensor the model expects: AOut must already be sized to
  3 * DEPTH_MODEL_INPUT_SIZE * DEPTH_MODEL_INPUT_SIZE. }
procedure PreprocessToTensor(const ARGB: TRGBImage; var AOut: array of Single);

{ Min-max normalizes the raw model output (DEPTH_MODEL_INPUT_SIZE square,
  float32) to 0..255 bytes - same convention the Python/Java reference
  implementations use for a viewable/usable depth map. }
procedure NormalizeToBytes(const ARaw: array of Single; out ABytes: array of Byte);

{ Hand-rolled bilinear resize from a DEPTH_MODEL_INPUT_SIZE-square byte
  map to ATargetWidth x ATargetHeight - ported concept from the Java
  reference's own center-aligned bilinear resize-back
  ((y + 0.5) * scale - 0.5), not FPC/BGRABitmap's own resampler, since
  this operates on a plain byte array, not a bitmap. }
procedure ResizeBilinear(const ASrc: array of Byte; ASrcSize: Integer;
  ATargetWidth, ATargetHeight: Integer; out ADst: array of Byte);

implementation

function DepthAt(const AImage: TDepthMapImage; AX, AY: Integer): Byte;
begin
  Result := AImage.Pixels[AY * AImage.Width + AX];
end;

function OnnxModelsDir: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'onnx-models' + PathDelim;
end;

function DefaultOnnxRuntimeLibPath: string;
begin
  Result := OnnxModelsDir + 'libonnxruntime.so';
end;

function DefaultDepthModelPath: string;
begin
  Result := OnnxModelsDir + 'depth-anything-v2-small.onnx';
end;

procedure PreprocessToTensor(const ARGB: TRGBImage; var AOut: array of Single);
var
  x, y, c: Integer;
  size, plane: Integer;
  v: Single;
begin
  size := DEPTH_MODEL_INPUT_SIZE;
  plane := size * size;
  for y := 0 to size - 1 do
    for x := 0 to size - 1 do
      for c := 0 to 2 do
      begin
        v := ARGB.Pixels[(y * size + x) * 3 + c] / 255.0;
        AOut[c * plane + y * size + x] := (v - DEPTH_MEAN[c]) / DEPTH_STD[c];
      end;
end;

procedure NormalizeToBytes(const ARaw: array of Single; out ABytes: array of Byte);
var
  i, count: Integer;
  lo, hi, range: Single;
begin
  count := DEPTH_MODEL_INPUT_SIZE * DEPTH_MODEL_INPUT_SIZE;
  lo := ARaw[0];
  hi := ARaw[0];
  for i := 1 to count - 1 do
  begin
    if ARaw[i] < lo then lo := ARaw[i];
    if ARaw[i] > hi then hi := ARaw[i];
  end;
  range := hi - lo;
  if range < 1e-8 then range := 1e-8;
  for i := 0 to count - 1 do
    ABytes[i] := Round(EnsureRange((ARaw[i] - lo) / range * 255.0, 0, 255));
end;

procedure ResizeBilinear(const ASrc: array of Byte; ASrcSize: Integer;
  ATargetWidth, ATargetHeight: Integer; out ADst: array of Byte);
var
  tx, ty: Integer;
  sx, sy: Single;
  x0, y0, x1, y1: Integer;
  fx, fy: Single;
  p00, p10, p01, p11: Single;
  scaleX, scaleY: Single;
begin
  scaleX := ASrcSize / ATargetWidth;
  scaleY := ASrcSize / ATargetHeight;
  for ty := 0 to ATargetHeight - 1 do
  begin
    sy := (ty + 0.5) * scaleY - 0.5;
    if sy < 0 then sy := 0;
    y0 := Trunc(sy);
    if y0 > ASrcSize - 2 then y0 := ASrcSize - 2;
    if y0 < 0 then y0 := 0;
    y1 := y0 + 1;
    fy := sy - y0;

    for tx := 0 to ATargetWidth - 1 do
    begin
      sx := (tx + 0.5) * scaleX - 0.5;
      if sx < 0 then sx := 0;
      x0 := Trunc(sx);
      if x0 > ASrcSize - 2 then x0 := ASrcSize - 2;
      if x0 < 0 then x0 := 0;
      x1 := x0 + 1;
      fx := sx - x0;

      p00 := ASrc[y0 * ASrcSize + x0];
      p10 := ASrc[y0 * ASrcSize + x1];
      p01 := ASrc[y1 * ASrcSize + x0];
      p11 := ASrc[y1 * ASrcSize + x1];

      ADst[ty * ATargetWidth + tx] := Round(
        p00 * (1 - fx) * (1 - fy) +
        p10 * fx * (1 - fy) +
        p01 * (1 - fx) * fy +
        p11 * fx * fy);
    end;
  end;
end;

function GenerateDepthMap(const APhotoPath, AModelPath, AOnnxRuntimeLibPath: string;
  out ADepthMap: TDepthMapImage; out AError: string): Boolean;
var
  rgbImg: TRGBImage;
  origW, origH: Integer;
  inputTensor: array of Single;
  rawOutput: array of Single;
  normalizedBytes: array of Byte;
  shape: array[0..3] of Int64;
  env: POrtEnv;
  session: POrtSession;
  memInfo: POrtMemoryInfo;
  size, plane: Integer;
begin
  Result := False;
  ADepthMap.Width := 0;
  ADepthMap.Height := 0;
  SetLength(ADepthMap.Pixels, 0);
  env := nil;
  session := nil;
  memInfo := nil;

  if not uimageio.LoadRGBImageResized(APhotoPath, DEPTH_MODEL_INPUT_SIZE, rgbImg,
      origW, origH, AError) then
    Exit;

  size := DEPTH_MODEL_INPUT_SIZE;
  plane := size * size;
  SetLength(inputTensor, 3 * plane);
  PreprocessToTensor(rgbImg, inputTensor);

  if not OrtLoad(AOnnxRuntimeLibPath, AError) then
    Exit;
  try
    if not OrtCreateEnv(env, AError) then Exit;
    if not OrtCreateSession(env, AModelPath, session, AError) then Exit;
    if not OrtCreateCpuMemoryInfo(memInfo, AError) then Exit;

    shape[0] := 1;
    shape[1] := 3;
    shape[2] := size;
    shape[3] := size;

    SetLength(rawOutput, plane);
    if not OrtRunSingleIO(session, memInfo, DEPTH_INPUT_TENSOR_NAME, DEPTH_OUTPUT_TENSOR_NAME,
        inputTensor, shape, plane, rawOutput, AError) then
      Exit;

    SetLength(normalizedBytes, plane);
    NormalizeToBytes(rawOutput, normalizedBytes);

    ADepthMap.Width := origW;
    ADepthMap.Height := origH;
    SetLength(ADepthMap.Pixels, origW * origH);
    ResizeBilinear(normalizedBytes, size, origW, origH, ADepthMap.Pixels);

    Result := True;
  finally
    OrtReleaseMemoryInfo(memInfo);
    OrtReleaseSession(session);
    OrtReleaseEnv(env);
    OrtUnload;
  end;
end;

end.
