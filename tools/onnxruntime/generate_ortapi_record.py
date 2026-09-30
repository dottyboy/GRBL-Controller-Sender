#!/usr/bin/env python3
"""Regenerates src/core/uonnxruntime_api.inc's TOrtApi record from a real
onnxruntime_c_api.h (the ONNX Runtime C API header, MIT licensed,
github.com/microsoft/onnxruntime). Needed only if uonnxruntime.pas is ever
upgraded to target a newer ORT_API_VERSION - the OrtApi struct is a flat
vtable of function pointers with no individually-exported symbols, so
every member from index 0 up to the last one actually called must be
declared in the header's exact order, or the ABI is wrong.

Usage:
    curl -sL -o onnxruntime_c_api.h \\
      https://raw.githubusercontent.com/microsoft/onnxruntime/v<VERSION>/include/onnxruntime/core/session/onnxruntime_c_api.h
    python3 generate_ortapi_record.py onnxruntime_c_api.h > TOrtApi_generated.inc

Then diff TOrtApi_generated.inc's typed members against uonnxruntime_api.inc
and carry over the same ~14 TFnXxx type annotations (search uonnxruntime.pas
for TYPED_MEMBERS below) before replacing the .inc file - a newer version
only ever APPENDS members, per ONNX Runtime's own versioning guarantee, so
existing indices/names should be unchanged.
"""
import re
import sys

TYPED_MEMBERS = {
    'CreateEnv': 'TFnCreateEnv',
    'CreateSessionOptions': 'TFnCreateSessionOptions',
    'CreateSession': 'TFnCreateSession',
    'CreateCpuMemoryInfo': 'TFnCreateCpuMemoryInfo',
    'CreateTensorWithDataAsOrtValue': 'TFnCreateTensorWithDataAsOrtValue',
    'Run': 'TFnRun',
    'GetTensorMutableData': 'TFnGetTensorMutableData',
    'GetErrorMessage': 'TFnGetErrorMessage',
    'ReleaseStatus': 'TFnReleaseStatus',
    'ReleaseEnv': 'TFnReleaseEnv',
    'ReleaseSession': 'TFnReleaseSession',
    'ReleaseSessionOptions': 'TFnReleaseSessionOptions',
    'ReleaseMemoryInfo': 'TFnReleaseMemoryInfo',
    'ReleaseValue': 'TFnReleaseValue',
}


def strip_comments(s):
    s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
    s = re.sub(r'//[^\n]*', '', s)
    return s


def extract_members(header_text):
    start = header_text.index('struct OrtApi {')
    body = header_text[start:]
    end = body.index('\n};')
    body = body[:end]
    clean = strip_comments(body)

    pattern = re.compile(
        r'ORT_API2_STATUS\(\s*([A-Za-z_]\w*)\s*[,)]'
        r'|ORT_CLASS_RELEASE\(\s*([A-Za-z_]\w*)\s*\)'
        r'|ORT_API_T\(\s*[^,]+,\s*([A-Za-z_]\w*)\s*,'
        r'|\(ORT_API_CALL\s*\*\s*([A-Za-z_]\w*)\s*\)\s*\('
    )
    names = []
    for m in pattern.finditer(clean):
        g1, g2, g3, g4 = m.groups()
        if g1:
            names.append(g1)
        elif g2:
            names.append('Release' + g2)
        elif g3:
            names.append(g3)
        elif g4:
            names.append(g4)
    return names


def main():
    with open(sys.argv[1]) as f:
        text = f.read()
    names = extract_members(text)

    print(f'  {{ Auto-generated from onnxruntime_c_api.h ({len(names)} members for this')
    print(f'    header version) by tools/onnxruntime/generate_ortapi_record.py - every')
    print(f'    OrtApi struct member, in exact declaration order, since the C API is a')
    print(f'    flat vtable-like struct and position IS the ABI. Only the members this')
    print(f'    unit actually calls (see that script\'s TYPED_MEMBERS) get a real')
    print(f'    function-pointer type; the rest are plain Pointer fields that only')
    print(f'    exist to keep every later field at the correct byte offset - never')
    print(f'    dereferenced. }}')
    print('  TOrtApi = record')
    for i, name in enumerate(names):
        t = TYPED_MEMBERS.get(name, 'Pointer')
        print(f'    {name}: {t}; // [{i}]')
    print('  end;')
    print('  POrtApi = ^TOrtApi;')


if __name__ == '__main__':
    main()
