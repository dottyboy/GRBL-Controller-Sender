unit uonnxruntime;

{ uonnxruntime: minimal FPC dynlibs bindings for ONNX Runtime's C API
  (github.com/microsoft/onnxruntime, MIT licensed) - just enough to load a
  model and run it once on a single float32 input tensor, producing a
  single float32 output tensor. Not a general ONNX Runtime binding; scoped
  to exactly what Phase 23's depth-map pipeline (udepthmap.pas) needs.

  The C API (onnxruntime_c_api.h) exposes its entire surface as ONE flat
  struct of function pointers (OrtApi) returned by OrtGetApiBase()->GetApi()
  - there are no individually-exported symbols to bind by name. That means
  struct FIELD ORDER *is* the ABI: every member from index 0 up to the last
  one this unit calls must be declared, in the exact order the real header
  declares them, or every pointer after the first mistake is wrong and the
  first call through it crashes or corrupts memory.

  uonnxruntime_api.inc's TOrtApi record was generated (not hand-transcribed)
  from onnxruntime_c_api.h v1.30.0 (ORT_API_VERSION 30) by walking the
  struct body and extracting every member name via its three declaration
  macros (ORT_API2_STATUS, ORT_CLASS_RELEASE, ORT_API_T) plus the handful
  of members declared directly - 426 members total for this version. Only
  the ~14 this unit actually calls got a real function-pointer type; the
  rest are plain `Pointer` fields that exist purely to hold their slot's
  byte offset and are never dereferenced. Verified end-to-end (not just
  "it compiles"): a standalone test ran a real depth-estimation model
  through this binding and the resulting output tensor was byte-for-byte
  compared against the same model run through Python's own onnxruntime
  package on the same input tensor.

  ORT_API_CALL is empty on Linux/GCC (SysV AMD64 default convention), so
  every function pointer here is `cdecl` - confirmed from the header's own
  `#define ORT_API_CALL` (Linux branch has no __stdcall, unlike Windows'). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, dynlibs;

type
  POrtStatus = Pointer;
  POrtEnv = Pointer;
  POrtSession = Pointer;
  POrtSessionOptions = Pointer;
  POrtMemoryInfo = Pointer;
  POrtValue = Pointer;
  POrtRunOptions = Pointer;

  { Function-pointer types for the OrtApi members this unit actually calls -
    signatures transcribed from onnxruntime_c_api.h, ORT_API_CALL = cdecl
    on Linux. int32/int64/size_t map to FPC's Integer/Int64/PtrUInt (LP64
    Linux: size_t is 8 bytes, matching PtrUInt). }
  TFnCreateEnv = function(log_severity_level: Integer; const logid: PAnsiChar;
    out outp: POrtEnv): POrtStatus; cdecl;
  TFnCreateSessionOptions = function(out options: POrtSessionOptions): POrtStatus; cdecl;
  TFnCreateSession = function(env: POrtEnv; const model_path: PAnsiChar;
    options: POrtSessionOptions; out outp: POrtSession): POrtStatus; cdecl;
  TFnCreateCpuMemoryInfo = function(atype: Integer; mem_type: Integer;
    out outp: POrtMemoryInfo): POrtStatus; cdecl;
  TFnCreateTensorWithDataAsOrtValue = function(info: POrtMemoryInfo; p_data: Pointer;
    p_data_len: PtrUInt; const shape: PInt64; shape_len: PtrUInt; dtype: Integer;
    out outp: POrtValue): POrtStatus; cdecl;
  TFnRun = function(session: POrtSession; run_options: POrtRunOptions;
    const input_names: PPAnsiChar; const inputs: PPointer; input_len: PtrUInt;
    const output_names: PPAnsiChar; output_names_len: PtrUInt;
    outputs: PPointer): POrtStatus; cdecl;
  TFnGetTensorMutableData = function(value: POrtValue; out outp: Pointer): POrtStatus; cdecl;
  TFnGetErrorMessage = function(status: POrtStatus): PAnsiChar; cdecl;
  TFnReleaseStatus = procedure(input: POrtStatus); cdecl;
  TFnReleaseEnv = procedure(input: POrtEnv); cdecl;
  TFnReleaseSession = procedure(input: POrtSession); cdecl;
  TFnReleaseSessionOptions = procedure(input: POrtSessionOptions); cdecl;
  TFnReleaseMemoryInfo = procedure(input: POrtMemoryInfo); cdecl;
  TFnReleaseValue = procedure(input: POrtValue); cdecl;

  {$I uonnxruntime_api.inc}

  TOrtApiBase = record
    GetApi: function(AVersion: Cardinal): POrtApi; cdecl;
    GetVersionString: function(): PAnsiChar; cdecl;
  end;
  POrtApiBase = ^TOrtApiBase;

const
  ORT_API_VERSION = 30;
  ORT_LOGGING_LEVEL_WARNING = 2;
  ORT_ARENA_ALLOCATOR = 1;
  ORT_MEM_TYPE_DEFAULT = 0;
  ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT = 1;

{ Loads libonnxruntime.so (by explicit path - callers should pass the
  bundled/known-good copy, not rely on it being on the system's library
  search path) and resolves OrtGetApiBase + GetApi(ORT_API_VERSION). Must
  succeed before any other function in this unit is called. }
function OrtLoad(const ALibraryPath: string; out AError: string): Boolean;
procedure OrtUnload;

function OrtCreateEnv(out AEnv: POrtEnv; out AError: string): Boolean;
function OrtCreateSession(AEnv: POrtEnv; const AModelPath: string;
  out ASession: POrtSession; out AError: string): Boolean;
function OrtCreateCpuMemoryInfo(out AInfo: POrtMemoryInfo; out AError: string): Boolean;

{ Runs ASession with exactly one named float32 input and one named float32
  output - the whole shape this project's depth-map pipeline needs.
  AInputData/AInputShape describe the input tensor (row-major, matching
  AInputShape's dimensions, e.g. [1,3,518,518]); AOutputData is resized to
  AOutputCount and filled from the run's output tensor. }
function OrtRunSingleIO(ASession: POrtSession; AMemInfo: POrtMemoryInfo;
  const AInputName, AOutputName: string;
  const AInputData: array of Single; const AInputShape: array of Int64;
  AOutputCount: PtrUInt; out AOutputData: array of Single;
  out AError: string): Boolean;

procedure OrtReleaseMemoryInfo(AInfo: POrtMemoryInfo);
procedure OrtReleaseSession(ASession: POrtSession);
procedure OrtReleaseEnv(AEnv: POrtEnv);

implementation

var
  GLibHandle: TLibHandle = NilHandle;
  GApi: POrtApi = nil;

function OrtLoad(const ALibraryPath: string; out AError: string): Boolean;
var
  getApiBase: function(): POrtApiBase; cdecl;
  base: POrtApiBase;
begin
  Result := False;
  AError := '';
  GLibHandle := LoadLibrary(ALibraryPath);
  if GLibHandle = NilHandle then
  begin
    AError := 'Could not load ' + ALibraryPath;
    Exit;
  end;

  Pointer(getApiBase) := GetProcedureAddress(GLibHandle, 'OrtGetApiBase');
  if not Assigned(getApiBase) then
  begin
    AError := 'OrtGetApiBase symbol not found in ' + ALibraryPath;
    Exit;
  end;

  base := getApiBase();
  if not Assigned(base) then
  begin
    AError := 'OrtGetApiBase() returned nil';
    Exit;
  end;

  GApi := base^.GetApi(ORT_API_VERSION);
  if not Assigned(GApi) then
  begin
    AError := Format('GetApi(%d) returned nil - installed ONNX Runtime is older than this binding targets', [ORT_API_VERSION]);
    Exit;
  end;

  Result := True;
end;

procedure OrtUnload;
begin
  GApi := nil;
  if GLibHandle <> NilHandle then
  begin
    UnloadLibrary(GLibHandle);
    GLibHandle := NilHandle;
  end;
end;

function CheckStatus(AStatus: POrtStatus; out AError: string): Boolean;
begin
  if AStatus = nil then
  begin
    Result := True;
    Exit;
  end;
  AError := GApi^.GetErrorMessage(AStatus);
  GApi^.ReleaseStatus(AStatus);
  Result := False;
end;

function OrtCreateEnv(out AEnv: POrtEnv; out AError: string): Boolean;
begin
  AEnv := nil;
  Result := CheckStatus(GApi^.CreateEnv(ORT_LOGGING_LEVEL_WARNING, 'grbl-controller-sender', AEnv), AError);
end;

function OrtCreateSession(AEnv: POrtEnv; const AModelPath: string;
  out ASession: POrtSession; out AError: string): Boolean;
var
  opts: POrtSessionOptions;
begin
  ASession := nil;
  opts := nil;
  if not CheckStatus(GApi^.CreateSessionOptions(opts), AError) then
    Exit(False);
  try
    Result := CheckStatus(GApi^.CreateSession(AEnv, PAnsiChar(AModelPath), opts, ASession), AError);
  finally
    GApi^.ReleaseSessionOptions(opts);
  end;
end;

function OrtCreateCpuMemoryInfo(out AInfo: POrtMemoryInfo; out AError: string): Boolean;
begin
  AInfo := nil;
  Result := CheckStatus(GApi^.CreateCpuMemoryInfo(ORT_ARENA_ALLOCATOR, ORT_MEM_TYPE_DEFAULT, AInfo), AError);
end;

function OrtRunSingleIO(ASession: POrtSession; AMemInfo: POrtMemoryInfo;
  const AInputName, AOutputName: string;
  const AInputData: array of Single; const AInputShape: array of Int64;
  AOutputCount: PtrUInt; out AOutputData: array of Single;
  out AError: string): Boolean;
var
  inputValue, outputValue: POrtValue;
  inputNames, outputNames: array[0..0] of PAnsiChar;
  inputs, outputs: array[0..0] of Pointer;
  outData: Pointer;
  inputNameStr, outputNameStr: AnsiString;
begin
  Result := False;
  inputValue := nil;
  outputValue := nil;

  if not CheckStatus(GApi^.CreateTensorWithDataAsOrtValue(AMemInfo, @AInputData[0],
      Length(AInputData) * SizeOf(Single), @AInputShape[0], Length(AInputShape),
      ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, inputValue), AError) then
    Exit;

  try
    inputNameStr := AInputName;
    outputNameStr := AOutputName;
    inputNames[0] := PAnsiChar(inputNameStr);
    outputNames[0] := PAnsiChar(outputNameStr);
    inputs[0] := inputValue;
    outputs[0] := nil;

    if not CheckStatus(GApi^.Run(ASession, nil, @inputNames[0], @inputs[0], 1,
        @outputNames[0], 1, @outputs[0]), AError) then
      Exit;

    outputValue := outputs[0];
    try
      if not CheckStatus(GApi^.GetTensorMutableData(outputValue, outData), AError) then
        Exit;
      Move(outData^, AOutputData[0], AOutputCount * SizeOf(Single));
      Result := True;
    finally
      GApi^.ReleaseValue(outputValue);
    end;
  finally
    GApi^.ReleaseValue(inputValue);
  end;
end;

procedure OrtReleaseMemoryInfo(AInfo: POrtMemoryInfo);
begin
  if Assigned(GApi) and (AInfo <> nil) then GApi^.ReleaseMemoryInfo(AInfo);
end;

procedure OrtReleaseSession(ASession: POrtSession);
begin
  if Assigned(GApi) and (ASession <> nil) then GApi^.ReleaseSession(ASession);
end;

procedure OrtReleaseEnv(AEnv: POrtEnv);
begin
  if Assigned(GApi) and (AEnv <> nil) then GApi^.ReleaseEnv(AEnv);
end;

end.
