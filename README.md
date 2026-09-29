# GRBL-Controller-Sender

A native, cross-controller CNC/laser sender for Linux, written in Object
Pascal (Free Pascal / Lazarus, built with CodeTyphon Studio). Talks to
GRBL 0.9.x, GRBL 1.1 / grblHAL, Smoothieware and g2core over serial, with
g-code streaming, 3D toolpath preview, probing, a universal `$$`
settings grid, a firmware builder (grblHAL/µCNC dual-drive axis
config + PlatformIO build/flash), FluidNC `config.yaml` editing, and an
in-progress laser-engraving module.

See [`docs/USER-GUIDE.md`](docs/USER-GUIDE.md) for a short tab-by-tab
guide to what actually works today.

## ⚠️ Status: test project, provided as-is, no warranty

This is a personal/hobby project published publicly so others can look
at it, use it, or build on it — **not** a finished, vetted, production
product. In particular:

- It drives real motors, spindles and (once the laser module lands)
  real lasers. **A bug here can cause real physical damage or injury.**
  Read the code, test on a machine you're prepared to lose, and don't
  trust it blindly around people or material you can't afford to
  damage.
- It is licensed under GPL-3.0-or-later (see `LICENSE`) and, per that
  license's own terms (sections 15-16), comes with **absolutely no
  warranty**, express or implied.
- Development happens phase-by-phase; not every advertised feature is
  finished, and some features are compiled in but not yet wired into
  the UI (see the project's own planning notes for current status —
  ask in an issue if you want to know where a specific feature stands).
- **Linux only, for now.** The only build/test environment available
  while developing this is Linux — there is no Windows machine to build
  or test a Windows target on, so no Windows binaries are provided and
  Windows compatibility is unverified. CodeTyphon/Lazarus/FPC can in
  principle target Windows too, but that path has not been exercised
  for this project at all.

If any of that is a problem for your use case, this probably isn't the
right tool for you yet.

## License

GPL-3.0-or-later. See `LICENSE` for the full text.

This project was built by studying (and in places fairly closely
porting the architecture/protocol logic of) several other open-source
CNC/laser sender projects — **see `THIRD-PARTY-NOTICES.md` before you
redistribute this**, it lists exactly what was used from where, under
what license, and discloses one real open licensing question (a
GPL-2.0-only source ported alongside several GPL-3.0-or-later sources)
that hasn't been given a formal legal opinion.

## Building (Linux)

### Prerequisites

- **CodeTyphon Studio 9.00** (Qt5 "Big IDE" build), which bundles its
  own Free Pascal Compiler and Lazarus-derived IDE/LCL — install it
  first; this project depends on CodeTyphon's own package set (package
  names like `adLCL`, `bs_SynEdit`, `lz_OpenGL` are CodeTyphon-specific
  remappings of the stock Lazarus packages, not the stock names).
- Qt5 widgetset selected as the active CodeTyphon widgetset.
- The vendored `packages/TLazSerial/` package (ships with this repo,
  built automatically as part of the project build).
- For the Firmware Builder tab: [PlatformIO](https://platformio.org/)
  (`pio` on `PATH`) and, for AVR targets, `avrdude`.
- For the (in-progress) laser module's raster/SVG import: the
  `pl_BGRAbitmap` CodeTyphon package (ships with CodeTyphon Studio).

### Build

From the project root:

```sh
typhonbuild64 -B --ws=qt5 GRBL-Controller-Sender.ctpr
```

(`typhonbuild64` is CodeTyphon's own CLI build tool — note the `64`
suffix; there is no plain `typhonbuild` binary on a typical CodeTyphon
Linux install.) This produces the `GRBL-Controller-Sender` executable
in the project root.

To open it in the IDE instead:

```sh
QT_QPA_PLATFORMTHEME=qt5ct typhon-ide64 GRBL-Controller-Sender.ctpr
```

### Development machine this was built/tested on

Given for transparency, not as a hard requirement — other reasonably
current Linux distributions with CodeTyphon 9.00 installed should work
equally well, but this is the only combination actually exercised:

- Linux Mint 22.3 (Zena), Ubuntu/Debian-based
- Kernel 6.14, x86_64
- Qt5 widgetset (via `qt5ct` for consistent theming)
- CodeTyphon Studio 9.00 "Big IDE"

## What's inside

- `src/core/` — controller-agnostic logic: g-code parsing/preview,
  probing, board/machine catalogs, app config, i18n (hand-rolled
  EN/HR/DE, no gettext), the laser module's core units as they land.
- `src/protocol/` — the serial streaming engine and per-controller
  protocol implementations (GRBL0/GRBL1/Smoothie/g2core).
- `src/io/` — low-level serial port handling.
- `src/ui/` — one `TFrame` (paired `.pas`+`.frm`) per tab/dialog.
- `packages/TLazSerial/` — vendored serial-port LCL component.
- `tools/` — optional bridge plugins for external design tools
  (Inkscape, GIMP 3.0, Krita, QCAD, FreeCAD), each a small plain-file
  extension/plugin you install into that program yourself (not built by
  the main app). Each sends its export straight into this app's SVG or
  Raster Import tab over the same Unix-FIFO trigger the app's own
  multi-instance "SincroStart" feature uses — see each subfolder's own
  README for install steps.

## Contributing / questions

This is currently developed solo, phase-by-phase, against a personal
plan file that isn't part of the repository. Open an issue if something
is unclear, broken, or you want to know whether a given feature is
actually finished yet before you rely on it.
