# Third-Party Notices

This project (GRBL-Controller-Sender) is a fresh implementation in
Object Pascal (Free Pascal / Lazarus / CodeTyphon), **not** a mechanical
translation of any single upstream codebase. It was built by studying
several existing open-source CNC/laser sender projects as behavior and
protocol references, and in a few places porting their algorithms or
wire-protocol logic fairly closely. This file lists every project that
influenced this codebase, what was actually used from it, and its
license. Every license below was checked directly against that
project's own `LICENSE`/`COPYING` file or PyPI/GitHub license metadata
as of 2026-09-28 — none of it is assumed or guessed.

**If you ship, fork, or otherwise redistribute this project, you must
comply with the licenses listed here for the corresponding parts, in
addition to this project's own license (see `LICENSE`, GPL-3.0-or-later).**

## bCNC (GPL-2.0, **not** "or later")

- Project: <https://github.com/vlachoudis/bCNC> (this project referenced
  a fork of it)
- License: GNU General Public License, version 2 only — confirmed via
  bCNC's own `setup.py` (`license="GPLv2"`, PyPI classifier `License ::
  OSI Approved :: GNU General Public License v2 (GPLv2)`), not "or later".
- What was used: bCNC's Python architecture is the direct blueprint for
  this project's serial-streaming/protocol/probing layer. Several
  modules closely mirror bCNC's own module structure and logic,
  including (but not limited to):
  - `src/protocol/usender.pas` — mirrors `Sender.py`'s `serialIO()`
    (character-counting streaming protocol, `cline`/`sline` FIFO
    bookkeeping, single dedicated worker thread design).
  - `src/protocol/ugenericcontroller.pas`, `ugrbl0.pas`, `ugrbl1.pas`,
    `usmoothie.pas`, `ug2core.pas` — mirror bCNC's `controllers/`
    package (`_GenericController.py`, `GRBL0.py`, `GRBL1.py`,
    `Smoothie.py`, `G2core.py`).
  - `src/core/ugcode.pas`'s `TGCodeParser` — mirrors `CNC.py`'s
    `motionPath()`/`motionCenter()` (arc-to-segment expansion) and
    `parseLine()` (g-code tokenizing).
  - `src/core/uprobe.pas` — mirrors `CNC.py`'s `Probe` class (grid-scan
    g-code generation, bilinear interpolation) and `ProbePage.py`'s
    corner/edge-finder probing flow.
- **Known license-compatibility wrinkle, disclosed rather than papered
  over**: this project is GPL-3.0-or-later (see `LICENSE`), and several
  other upstream references below are GPL-3.0-or-later too — but bCNC
  is GPL-2.0 *only*, with no "or later" clause. Strictly, the Free
  Software Foundation's own compatibility guidance is that GPL-2.0-only
  code and GPL-3.0-only code cannot be combined into a single unified
  GPL-licensed work without one side granting the "or later" option.
  Whether the degree of porting here (closely-following architecture
  and, in the protocol/streaming modules, fairly literal logic
  translation — not literal Python-to-Pascal copy-paste, since the
  languages differ, but a close structural port) constitutes a
  "derivative work" of bCNC under copyright law, and if so whether that
  creates a real GPL-2/GPL-3 conflict for this repository, is a
  genuine open legal question this project has **not** had resolved by
  a lawyer. Flagging this explicitly here rather than assuming it away:
  if you plan to rely on this project commercially or at scale, get
  your own legal opinion on this point before you do. For a hobby/test
  publication this is disclosed in good faith.

## LaserGRBL (GPL-3.0-or-later)

- Project: <https://github.com/arkypita/LaserGRBL>
- Author: Diego Settimi, Copyright (c) 2016
- License: GPL-3.0-or-later — confirmed via LaserGRBL's own
  `LICENSE.md` ("either version 3 of the License, or (at your option)
  any later version").
- What was used: the "Laser" module currently being added to this
  project (raster/vector image-to-gcode, laser-safe streaming, resume-
  from-position, auto-cooling, etc.) is a fresh Pascal reimplementation
  of LaserGRBL's feature set, not a translation of its C#/.NET source
  — but its `Core/GrblCore.cs` state machine, safety properties
  (forced-M5-on-abort, buffer-stuck watchdog design, auto-cooling duty
  cycle), and several algorithm names/behaviors (dithering algorithm
  list, vendor-sniffing welcome-banner patterns in
  `src/protocol/uvendorsniff.pas`) were read directly from LaserGRBL's
  real source and ported as design/behavior references. As this module
  grows (see the project's own phased plan), later phases are expected
  to port LaserGRBL algorithms more closely in places (e.g. a Potrace-
  based vectorizer, an SVG import path, a Hershey-font engraver) —
  this notice will be kept up to date as that happens.
- Phase 16 (test-pattern generator) ported LaserGRBL algorithms more
  literally than the rest of this notice's entries: `src/core/uhershey.pas`
  is a line-for-line translation of `Hershey/Hershey.cs`'s real
  `CreateString`/`MeasureString`/`ApplyOffset` (the `hor` horizontal-text
  glyph table itself — 95 glyphs, ASCII 32-126 — is machine-extracted
  verbatim into `src/core/hershey_data.inc`; the `ver` vertical-text table
  was deliberately not ported, see that unit's own header comment), and
  `src/core/ulasertestgen.pas` closely follows `GrblFile.cs`'s real
  `GenerateCuttingTest`, `GenerateGreyscaleTest`, `GenerateShakeTest` and
  `GenerateShakeTest2` (same coordinate math and g-code shape, adapted to
  this project's own `TStrings`-based generator style).

## Second source wave — CNC/laser sender peers (plan-stage references, Phases 12/21/24-26)

Surveyed after the original 22-phase Laser module plan was drafted, while looking for
practical features/approaches to fold in. **Not yet implemented** as of this writing —
each entry below names the specific phase(s) in the project's own plan file that will
draw on it, so this notice is accurate ahead of time rather than needing to be
reconstructed later.

### Universal-G-Code-Sender / UGS (GPL-3.0)

- Project: <https://github.com/winder/Universal-G-Code-Sender>
- License: GPL-3.0 — confirmed via UGS's own `COPYING` file.
- What's referenced: the `ugs-designer` module's vector-object actions (align/flip/
  group/boolean) are a design reference for Phase 12's SVG-editing UI, not ported code —
  UGS is Java/NetBeans-Platform, structurally unrelated to this project. Phase 23's
  `src/core/udepthmap.pas` ports the *concept* (not the code) of its
  `AbstractOnnxDepthModel.java`/`DepthAnythingModel.java` - same preprocessing
  (resize/normalize/CHW layout), same ONNX Runtime C API call shape, same hand-rolled
  bilinear resize-back for the output - read directly from those two files, not guessed.
  See the ONNX Runtime and depth-anything-v2-small entries below for the actual
  redistributed dependencies this pulled in.

### Candle (GPL-3.0)

- Project: <https://github.com/Denvi/Candle> (mirrored/forked at
  `github.com/candle-cnc/candle`)
- License: GPL-3.0 — confirmed via Candle's own `LICENSE` file.
- What's referenced: `frmchecklist` (pre-flight checklist dialog) is a design reference
  for Phase 25; `connections/telnetconnection.cpp` + `websocketconnection.cpp` inform
  Phase 21's revised scope (a plain host:port network connection option is planned
  before the original UDP-scan/HTTP-config design). Candle is C++/Qt, the closest
  tech-stack peer to this project of anything surveyed — still a design reference only,
  no code copied.

### OpenBuilds CONTROL (GPL-3.0)

- Project: <https://github.com/OpenBuilds/OpenBuilds-CONTROL>
- License: GPL-3.0 — confirmed via its own `LICENSE` file.
- What's referenced: its axis/servo calibration wizard (`app/img/calibrate/`) is the
  design reference for the new Phase 24 (no equivalent existed in this project or the
  original plan); `js/grbl-settings-templates.js` informs Phase 26's known-board
  settings-template feature. OpenBuilds CONTROL is Electron/JavaScript — again a design
  reference only, no code copied (nor could it be, directly, given the language gap).

## Gerber/PCB isolation-routing references (Phase 33, plan-stage)

### FlatCAM (MIT)

- Project: <https://github.com/JuanoVenegas/flatcam> (fork of the original
  `bitbucket.org/jpcgt/flatcam` by Juan Pablo Caram)
- License: **MIT** — confirmed via the repo's own `LICENSE` file content (Copyright
  2014-2018 Juan Pablo Caram), not just GitHub's detected-license field.
- What's referenced: primary algorithm/parser reference for Phase 33 (native Gerber
  import + isolation-routing toolpath generation) — its `camlib.py` (offset/geometry
  core), Gerber/DXF/SVG parsers, and G-code post-processors. MIT is maximally permissive
  and poses no compatibility question with this project's GPL-3.0-or-later even if
  algorithmic approaches are adapted (not code copy — Python-to-Pascal reimplementation,
  same discipline as every ported reference in this file).

### Visolate (GPL-3.0)

- Project: <https://github.com/Traumflug/Visolate> (also mirrored at
  `github.com/bert/visolate`)
- License: GPL-3.0 — confirmed by fetching the repo's actual `LICENSE.txt` content
  directly (`gh api repos/Traumflug/Visolate/contents/LICENSE.txt`), not just GitHub's
  license-detection field.
- What's referenced: secondary algorithm reference for Phase 33 (isolation-milling
  toolpath concept — offset boundary around copper). Its own project page discloses a
  real limitation: Gerber polygon/region apertures are "not yet supported" — noted so
  this project doesn't inherit that gap silently if this reference is used.

### pcb2gcode (GPL-3.0)

- Project: <https://github.com/pcb2gcode/pcb2gcode>
- License: GPL-3.0 — confirmed via the repo's own `COPYING` file content.
- What's referenced: secondary reference for Phase 33's Gerber region-aperture parsing
  specifically (an area FlatCAM's own ground-plane-clearing feature suggests it handles
  better than Visolate, though not yet confirmed by reading either parser closely).

## Depth-map / relief-engraving (Phase 23)

### ONNX Runtime (MIT)

- Project: <https://github.com/microsoft/onnxruntime>
- Copyright (c) Microsoft Corporation
- License: MIT — confirmed via the project's own `LICENSE` file (v1.30.0 tag checked
  directly, not assumed).
- What's used: `src/core/uonnxruntime.pas` dynamically loads the prebuilt
  `libonnxruntime.so` (official Linux x64 release asset, not built from source) via
  FPC's `dynlibs` and binds its C API (`onnxruntime_c_api.h`) - just the ~14 functions
  Phase 23's single-input/single-output inference call needs. The C API is one flat
  struct of function pointers with no individually-exported symbols, so struct field
  *order* is the ABI; `src/core/uonnxruntime_api.inc`'s 426-member `TOrtApi` record was
  generated from the real header (`tools/onnxruntime/generate_ortapi_record.py`, not
  hand-transcribed) to guarantee every field lands at its correct byte offset. Verified
  end-to-end: a real depth-estimation model run through this binding was compared
  byte-for-byte against the same model run through Python's own `onnxruntime` package on
  an identical input tensor (max abs diff: 0.0). **Distribution:** bundled directly
  inside the AppImage at `usr/bin/onnx-models/libonnxruntime.so` by
  `packaging/appimage/build-appimage.sh` (downloaded fresh from ONNX Runtime's own
  official GitHub release asset, cached under `tools/onnxruntime/cache/` - gitignored,
  not re-downloaded on every build) - never vendored into this git repository itself. A
  plain (non-AppImage) dev build looks for the same `onnx-models/` folder next to its
  own executable (`udepthmap.pas`'s `DefaultOnnxRuntimeLibPath`), so it's a manual
  one-time copy for anyone building from source directly.

### depth-anything-v2-small (Apache-2.0)

- Project: <https://huggingface.co/depth-anything/Depth-Anything-V2-Small> (original
  checkpoint) / <https://huggingface.co/onnx-community/depth-anything-v2-small> (the
  ONNX export this project actually downloads and runs, `onnx/model.onnx`)
- License: Apache License 2.0 — confirmed via both HuggingFace model cards' own license
  metadata directly, not assumed (checked specifically because Depth Anything V2's
  larger Base/Large checkpoints are CC-BY-NC-4.0 - non-commercial - while only the Small
  variant used here is Apache-2.0; this distinction was verified before writing any code
  against this model, per Phase 23's own "resolve the license before bundling" gate in
  the plan file).
- What's used: `src/core/udepthmap.pas` runs this exact ONNX model (input tensor
  `pixel_values` `[1,3,518,518]` float32, output `predicted_depth` `[1,518,518]`
  float32 - shapes verified directly from the `.onnx` file's own graph via Python's
  `onnx` package, not guessed) for monocular depth estimation. The model weights
  (~99MB) are a runtime dependency, not vendored into this git repository. **Distribution:**
  same mechanism as ONNX Runtime above - bundled at
  `usr/bin/onnx-models/depth-anything-v2-small.onnx` by `build-appimage.sh` (fetched
  from HuggingFace, cached locally), or a manual one-time copy into the same
  `onnx-models/` folder for a plain dev build.

### MiDaS (MIT) / GIMP-ML (third-party GIMP plugin, license varies by fork)

- Projects: <https://github.com/isl-org/MiDaS>,
  <https://github.com/kritiksoman/GIMP-ML> (original),
  <https://github.com/yantoz/GIMP-ML-Hub> and
  <https://github.com/UserUnknownFactor/GIMP3-ML> (GIMP-3-compatible forks)
- License: MiDaS itself is MIT (Copyright (c) 2019 Intel ISL). The GIMP-ML forks are not
  individually re-verified per fork as of this writing (flagged, not assumed).
- What's referenced: before Phase 23's native pipeline above existed, installing this
  third-party plugin inside GIMP and using this project's own Phase 28 bridge (original
  code) to send its MiDaS-based depth-map output into Phase 10's raster import was the
  documented path for "photo → real depth-map". Still a valid alternative (no native
  ONNX Runtime/model dependency to install), now optional rather than the only route.
  Not compiled into or distributed with this project either way.

## grblHAL (GPL-3.0-or-later)

- Project: <https://github.com/grblHAL>
- Copyright (c) 2016-2021 Terje Io; (c) 2011-2016 Sungeun K. Jeon for
  Gnea Research LLC; (c) 2009-2011 Simen Svale Skogsrud; (c) 2011 Jens
  Geisler
- License: GPL-3.0-or-later — confirmed via `grblHAL-core`'s own
  `COPYING` file.
- What was used: this project's Firmware Builder feature (see
  `src/core/ufirmwareboards.pas`, `ufirmwarebuildconfig.pas`) parses
  and programmatically patches real grblHAL board-map header files
  (`boardmap_*.h`) and `my_machine.h`-style config files from cloned
  grblHAL driver repositories to enable a dual-drive/auto-squared axis,
  then invokes PlatformIO to build them. No grblHAL source is compiled
  into or distributed with this project itself — the parser/patcher
  understands grblHAL's file format and operates on the user's own
  local clone of the driver repo they choose to build against.
  grblHAL's own settings/status-report protocol (`$$`, `$I`, `$ES`,
  `<...>` status reports) was also studied directly against the
  `report.c` source to implement this project's settings grid and rich
  setting descriptions — protocol facts/wire formats are not
  copyrightable, only the reference implementation's own source is.

## µCNC / uCNC (GPL-3.0-or-later)

- Project: <https://github.com/Paciente8159/uCNC>
- License: GPL-3.0-or-later — confirmed via `uCNC`'s own `LICENSE` file.
- What was used: same situation as grblHAL above — the Firmware Builder
  parses and patches real `cnc_hal_config.h`/`boardmap_*.h` files from
  a cloned uCNC repository to enable dual-drive axes, then builds via
  PlatformIO. No uCNC source is compiled into or distributed with this
  project.

## FluidNC (GPL-3.0-or-later)

- Project: <https://github.com/bdring/FluidNC>
- License: GPL-3.0-or-later — confirmed via FluidNC's own `LICENSE`
  file ("either version 3 of the License, or (at your option) any
  later version").
- What was used: `src/protocol/uxmodem.pas` (XMODEM file transfer, used
  to upload/download FluidNC's `config.yaml`) was written against
  FluidNC's real `xmodem.cpp` (fetched from the upstream repository),
  matching its exact framing (SOH/STX/EOT/ACK/NAK/CAN bytes, CRC-16/
  XMODEM table, CTRLZ padding convention) so this project's transfers
  are wire-compatible with a real FluidNC board. `src/core/
  ufluidncaxes.pas`'s `axes:` block parser was built against FluidNC's
  own published `config_items.yaml` schema. No FluidNC source is
  compiled into this project.

## TLazSerial (LGPL-2.0-or-later, modified/"linking exception" style)

- Vendored, project-local copy at `packages/TLazSerial/`.
- License: per its own `.ctpkg` license field — "GNU Library General
  Public License … version 2 … or (at your option) any later version",
  the standard Lazarus-package "modified LGPL" style (same linking
  exception convention as the Lazarus LCL itself — see below).
- What was used: this component is used as-is (adapted for CodeTyphon's
  package-name conventions during the Typhon conversion, not
  functionally rewritten) as the serial-port component registered in
  the IDE. LGPL permits this kind of linking without imposing GPL terms
  on the rest of this project.

## Synapse / Ararat Synapse (BSD-3-Clause style)

- Project: <http://www.ararat.cz/synapse/> (bundled as CodeTyphon's own
  `pl_Synapse` package)
- License: a permissive BSD-3-Clause-style license — confirmed directly
  from the real license header in `blcksock.pas` itself ("Copyright
  (c)1999-2021, Lukas Gebauer. All rights reserved. Redistribution and
  use in source and binary forms... provided that..." - the standard
  3-clause BSD text, not paraphrased). Synapse is actually tri-licensed
  upstream (MPL 1.1 / LGPL 2.1 / this BSD-style option, user's choice) -
  this notice cites the option actually shown in the bundled source,
  the most permissive of the three and unambiguously GPL-3.0-compatible.
- What was used: `TLazSerial`'s own `SynSer` field was ALREADY a
  Synapse `TBlockSerial` from Phase 1 onward (used indirectly, via
  TLazSerial's own wrapper); Phase 21 (WiFi/telnet direct-connect) is
  the first place this project's own code calls Synapse directly -
  `src/io/userial.pas`'s TCP backend and `src/protocol/
  uwifidiscovery.pas`'s LAN port-scanner both use `blcksock.pas`'s
  `TTCPBlockSocket` for real (registered as an explicit
  `RequiredPackages` entry in the `.ctpr` for the first time this phase -
  confirmed genuinely load-bearing, not just declared: the build failed
  outright with "Can't find unit blcksock" before this entry was added,
  and linked cleanly once it was).

## Free Pascal (FPC) / Lazarus LCL / CodeTyphon

- Projects: <https://www.freepascal.org/>, <https://www.lazarus-ide.org/>,
  CodeTyphon Studio (<https://www.pilotlogic.com/>)
- License: modified LGPL (LGPL with a static-linking exception,
  confirmed via `COPYING.modifiedLGPL.txt` shipped with both FPC and
  Lazarus/CodeTyphon on this build machine) — the standard FPC/Lazarus
  licensing arrangement that explicitly permits distributing compiled
  binaries linked against the RTL/LCL without those binaries having to
  be (L)GPL themselves.
- What was used: this is the compiler, runtime library, and widget-set
  framework the whole project is built with and against. Not bundled —
  end users/builders install their own copy of CodeTyphon.

## BGRABitmap (modified LGPL)

- Project: <https://github.com/bgrabitmap/bgrabitmap>
- License: modified LGPL — confirmed via `COPYING.modifiedLGPL.txt`
  shipped alongside the package in this CodeTyphon installation, same
  linking-exception convention as FPC/Lazarus itself.
- What was used (planned, Laser module Phase 10+): PNG/JPEG image
  decoding and SVG parsing for the raster/vector import features. Not
  bundled — a CodeTyphon package dependency, installed separately by
  whoever builds this project.

## External tools invoked as separate processes (not linked, not bundled)

These are never compiled into or distributed with this project — it
only shells out to whatever copy the user already has installed, via
`src/protocol/uprocessrunner.pas`. Their licenses therefore don't
affect this project's own licensing at all, but are listed here for
completeness:

- **PlatformIO** (Firmware Builder's build/upload backend) — Apache
  License 2.0.
- **avrdude** (AVR firmware flashing, invoked by PlatformIO) — GPL-2.0.
- **autotrace** (planned, Laser module centerline-tracing mode) — GPL
  (exact version not yet pinned down — will be confirmed when that
  phase is implemented).
- **GNU Global** (`global`/`gtags`) — used only by the developer's own
  VSCode Pascal-extension code-navigation setup, not by this project's
  build or runtime at all.

## Extension/plugin bridge targets (Phases 27-32, plan-stage) — original code only

Different in kind from every project above: these are external design/CAD programs
this project's own small, **original** extension/plugin/macro files (Python/JS/
ECMAScript, written from scratch by this project) will run *inside*, using each
program's own public scripting API, to hand a design off to this app's SVG/raster
import via a small local socket/FIFO. No source code from any of the six projects
below is copied into, adapted into, or distributed with this project — so none of
their licenses actually constrain this project's own code. Listed anyway, for
completeness and courtesy, since the bridge files are written specifically against
each program's real API (verified via each project's own docs before any bridge file
is written):

- **Inkscape** — GPL-2.0-or-later, with a few GIMP-derived files under GPL-3.0-only
  making the overall binary GPL-3.0-or-later in practice (confirmed via
  `inkscape.org/about/license` and its GitLab `LICENSES/` folder). Bridge target for
  Phase 27, via its `inkex`/`.inx` extension API.
- **GIMP** — GPL-3.0-or-later. Bridge target for Phase 28, via its GIMP-3
  GObject-Introspection Python plugin API (`Gimp.PlugIn`).
- **Krita** — GPL-3.0-or-later (KDE project). Bridge target for Phase 29, via its
  PyKrita/`libkis` plugin API.
- **QCAD** (Community Edition) — GPL-3.0-or-later with exceptions permitting
  independent plugins/scripts (confirmed via `qcad.org`'s own license page). Bridge
  target for Phase 30, via its ECMAScript/JavaScript scripting interface.
- **FreeCAD** — LGPL-2.1-or-later/BSD (GPL-free since its 0.14 release). Bridge target
  for Phase 31, via its Python macro system.
- **KiCad** — GPL-3.0-or-later (dual-licensed with CC-BY-3.0-or-later for non-code
  assets, per KiCad's own docs). Bridge target for Phase 32, via its `pcbnew` Python
  Action Plugin API.

Two small community example-script repos were also pulled in as API-usage references
for the bridges above (not the official projects themselves):

- **`FreeCAD/FreeCAD-macros`** (<https://github.com/FreeCAD/FreeCAD-macros>) — **no
  repository-level `LICENSE`/`COPYING` file was found** (checked directly, not
  assumed). Individual macro files in that repo may carry their own per-file license
  headers; if any specific macro from it is ever adapted rather than just read for API
  usage patterns, that file's own header must be checked first, not inferred from this
  notice.
- **`gregdavill/kicadScripts`** (<https://github.com/gregdavill/kicadScripts>) —
  Apache License 2.0, confirmed via the repo's own `LICENSE` file content.

## CNC/laser machine catalog data

`src/core/uboardcatalog.pas` and `src/core/umachinecatalog.pas` contain
factual specifications (travel dimensions, drive type, etc.) sourced
from manufacturers' own published product pages. Facts and measurements
are not copyrightable; no text or code was copied from any
manufacturer's materials.

## G/M-code reference documentation (not code, no license implications)

Three PDF references kept in `references/` (gitignored, not distributed with this
project) for filling out future help-text tables like `src/core/usettinghelp.pas`:
a DrufelCNC g-code reference, a Centroid G&M-code reference, and the CNC Cookbook
G-code course. These are documentation, not source code — nothing has been copied
from them yet; if/when specific wording is ever transcribed into this project's own
help text, that will be noted at the point it happens, same as every other entry in
this file.

---

*This project itself is licensed under GPL-3.0-or-later — see `LICENSE`
in the repository root. This is a hobby/test project published as-is,
without warranty; see the disclaimer in `README.md`.*
