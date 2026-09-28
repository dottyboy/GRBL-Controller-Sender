# User Guide

What actually works today, briefly. See the top-level `README.md` first
for the "test project, no warranty" disclaimer — it applies to
everything below.

## Connecting

**Control** tab, top row: pick a **Port**, hit **Scan** to refresh the
list, pick a **Baud** rate (115200 is grbl's usual default) and a
**Controller** (GRBL 1.x for modern grbl/grblHAL boards, GRBL 0.9 for
older ones, or Smoothieware/g2core), then **Open**. Once connected, the
board info line shows what was detected; **Refresh Info** re-queries it.
The **Profile** dropdown lets you pick a known machine from the built-in
catalog to fill in travel limits — see "Send Travel Limits" further
down.

## Control tab

- **DRO** (top-left): live machine/work position for X/Y/Z (and any
  further configured axes).
- **Jog pad**: click a direction to move that step. Step size for X/Y
  and Z are set separately via the two dropdowns. The four diagonal
  arrows (↖↗↙↘) move X and Y together in one command.
- **Keyboard jog**: works anywhere in the app (not just this tab) once
  connected — NumPad 8/2/4/6 = N/S/W/E, NumPad 7/9/1/3 = the diagonals,
  NumPad +/- = Z up/down, NumPad \*// = increase/decrease the X/Y step.
  Ctrl+H = Home, Ctrl+U = Unlock, F6 = Feed Hold, F7 = Resume, Ctrl+X =
  Soft Reset. These are fixed for now — there's no in-app way to rebind
  them yet, but you can hand-edit `hotkeys.ini` in the app's config
  directory if you want different keys.
- **Home / Unlock / Hold / Resume / Reset**: the standard grbl realtime
  controls.

## Editor tab

Open, edit and save plain g-code files. **Send** streams the loaded
file to the controller; **Stop** aborts and clears the queue.

## 3D View tab

Renders the currently loaded g-code as a toolpath (rapids dim, feed
moves bright). Left-drag to orbit, scroll to zoom. Updates automatically
whenever the Editor's content changes.

## Probe tab

Two independent tools:

- **Grid scan**: define a rectangular area and spacing, run a
  boustrophedon (back-and-forth) height-map scan, save/load the result.
  Useful for PCB-style surface leveling.
- **Touch probe**: Z-only zero, corner/center finding, or edge-finder
  probing with a tool-diameter offset — pick the mode, fill in the
  relevant fields, hit Probe.

## Tools tab

A simple end-mill/bit table (diameter, flutes, length, stepover,
comments), persisted between sessions.

## Settings ($$) tab

Shows every `$N=value` the board reports. **Refresh** re-reads them;
**Apply** sends back only the rows you actually changed. **Fetch
Descriptions** pulls rich per-setting descriptions from the board if it
supports grblHAL's `$ES` extension; otherwise standard grbl 1.1 settings
still get a human-readable description from a built-in table.

## Spoilboard tab

Generates g-code for three spoilboard-prep operations — surfacing
(facing), a peg-hole drilling grid, and T-track channels — from
parametric fields (work area, tool diameter, depths, spacing). Pick a
**Machine preset** to auto-fill the work area from a real known
machine's travel, and **Send Travel Limits** to push that machine's
travel as `$130`/`$131`/`$132` to the connected controller (it
deliberately does NOT touch soft-limit/homing enable settings — turn
those on yourself in the Settings tab once you've confirmed your limit
switches are actually wired).

## Firmware Builder tab

For building custom grblHAL or µCNC firmware with a dual-drive
(auto-squared) axis enabled — pick your board, add an axis with a free
motor/limit slot, Generate the patched project, Build (needs
[PlatformIO](https://platformio.org/) installed), and Upload. This is
independent of any live connection.

## FluidNC Config tab

Only appears when a connected board identifies itself as FluidNC.
Download/edit/upload its `config.yaml` directly (raw YAML editor, or use
**Edit Axes...** for a structured axes/motors/homing dialog instead of
hand-editing YAML).

## Language

**Language** menu: English, Hrvatski, Deutsch. Switches immediately,
persists across restarts. Coverage is thorough but not perfect — a few
fields are still sized for English text and may clip slightly in
Croatian or German.

## What's not here yet

The in-progress laser-engraving module (image/SVG import, laser-safe
job control, material presets, etc.) has real work landed underneath
the hood but no visible tab yet — nothing to use directly today. Don't
assume a feature exists just because a source file mentions "laser";
if in doubt, open an issue and ask.
