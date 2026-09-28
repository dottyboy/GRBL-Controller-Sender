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

## CNC/laser machine catalog data

`src/core/uboardcatalog.pas` and `src/core/umachinecatalog.pas` contain
factual specifications (travel dimensions, drive type, etc.) sourced
from manufacturers' own published product pages. Facts and measurements
are not copyrightable; no text or code was copied from any
manufacturer's materials.

---

*This project itself is licensed under GPL-3.0-or-later — see `LICENSE`
in the repository root. This is a hobby/test project published as-is,
without warranty; see the disclaimer in `README.md`.*
