# User Guide

What actually works today, with real screenshots of the actual running
app. See the top-level `README.md` first for the "test project, no
warranty" disclaimer — it applies to everything below.

**Coverage note**: this guide is being filled in group by group. The
**Machine** group (this file's main content right now) is fully
illustrated. The **Laser** and **Settings & Tools** groups still have
their older, screenshot-free descriptions further down — those get the
same treatment in a later pass.

## The three tab groups

The bottom of the window has three group tabs — **Machine**, **Laser**,
**Settings & Tools** — each holding its own row of tabs. Everything in
this section lives under **Machine**.

## Connecting

**Control** tab, top row: pick a **Port** (or `Emulator` to try the app
without real hardware — a built-in fake GRBL board for exactly this),
hit **Scan** to refresh the list, pick a **Baud** rate (115200 is grbl's
usual default) and a **Controller** (GRBL 1.x for modern grbl/grblHAL
boards, GRBL 0.9 for older ones, or Smoothieware/g2core), then **Open**.
Once connected, the board info line shows what was detected; **Refresh
Info** re-queries it. The **Profile** dropdown lets you pick a known
machine from the built-in catalog to fill in travel limits — see
"Send Travel Limits" under Spoilboard, further down.

## Control tab

![Control tab](screenshots/control-tab.png)

- **DRO** (top-left): live machine/work position for X/Y/Z (and any
  further configured axes).
- **Jog pad**: click a direction to move that step. Step size for X/Y
  and Z are set separately via the two dropdowns. The four diagonal
  arrows (↖↗↙↘) move X and Y together in one command.
- **Keyboard jog**: works anywhere in the app (not just this tab) once
  connected — NumPad 8/2/4/6 = N/S/W/E, NumPad 7/9/1/3 = the diagonals,
  NumPad +/- = Z up/down, NumPad \*// = increase/decrease the X/Y step.
  Ctrl+H = Home, Ctrl+U = Unlock, F6 = Feed Hold, F7 = Resume, Ctrl+X =
  Soft Reset. Rebindable from the **Hotkeys** tab (Settings & Tools
  group) — no more hand-editing `hotkeys.ini` required.
- **Home / Unlock / Hold / Resume / Reset**: the standard grbl realtime
  controls.
- The status bar at the very bottom of the window (visible in every
  screenshot on this page) always shows: the currently loaded file,
  connection/machine state, job progress, and a live clock.

## Editor tab

![Editor tab](screenshots/editor-tab.png)

Open, edit and save plain g-code files. **Send Program** streams the
loaded file to the controller; **Stop** aborts and clears the queue.
The **Header/Footer** row lets you pick a named preset (a built-in set
covering common GRBL startup/park sequences, plus your own saved ones)
and, if **Apply on Send** is checked, prepends/appends it automatically
— the same mechanism the Laser Control tab uses, available here for
plain CNC jobs too. Any custom macro button (Settings & Tools → Macros)
flagged "run on job start/end" fires automatically here as well, no
click needed.

The screenshot above happens to show a real isolation-routing program
(loaded via Gerber Import, further down this page) rather than a blank
editor — that's what "the currently loaded program" looks like once
something has actually been generated.

## 3D View tab

![3D View tab](screenshots/3dview-tab.png)

Renders the currently loaded g-code as a toolpath (rapids dim, feed
moves bright — the white lines above are rapids, the yellow outline is
the actual cutting path). Left-drag to orbit, scroll to zoom. Updates
automatically whenever the Editor's content changes; **Refresh from
Editor** re-parses on demand if you ever need to force it, **Reset
View** returns to the default camera angle.

## Probe tab

![Probe tab](screenshots/probe-tab.png)

Two independent tools:

- **Grid scan** (top section): define a rectangular area (X/Y min/max),
  a grid resolution, probe clearance/safe-Z/feed, **Start Scan** runs a
  boustrophedon (back-and-forth) height-map scan, **Save.../Load...**
  persists the result, **Zero at Current** treats the current Z as the
  reference plane. Useful for PCB-style surface leveling.
- **Touch probe** (bottom section): pick a **Probe type** (Z touch-off,
  corner/center finding, or edge-finding), fill in the tip/feature
  diameter, offset and search distance, hit **Probe**.

## Spoilboard tab

![Spoilboard tab](screenshots/spoilboard-tab.png)

Generates g-code for three spoilboard-prep operations — **Facing/
Surfacing**, a **Peg Holes Grid**, and **T-Track Channels** — from
parametric fields (work area, tool diameter, depths, spacing), each
section independently enabled via its own checkbox. Pick a **Machine
preset** to auto-fill the work area from a real known machine's travel,
and **Send Travel Limits** to push that machine's travel as `$130`/
`$131`/`$132` to the connected controller (it deliberately does NOT
touch soft-limit/homing-enable settings — turn those on yourself in the
Settings tab once you've confirmed your limit switches are actually
wired). **Profile** (top row) saves/loads/deletes your own named
parameter sets, separately from the read-only machine-travel presets.
**Generate G-Code** builds the combined program (always facing first,
then T-tracks, then peg holes) and hands it to the Editor/3D View.

## Gerber Import tab

![Gerber Import tab](screenshots/gerber-import-tab.png)

CNC-milling PCB machining from a real Gerber (RS-274X) file — **Open
Gerber...** loads one, then pick:

- **Tool**: CNC mill or Laser (the laser path shares the same geometry,
  just emits `M3 S<power>`/`M5` instead of Z-plunge g-code — no Z axis
  at all).
- **Strategy**: **Isolate** (mills a thin channel around each trace,
  leaving the copper otherwise untouched) or **Draw**, CNC-only (follows
  the trace/pad centerlines directly — a pen or engraving-tip job, not a
  milling one). Picking Laser while Draw is active snaps back to
  Isolate automatically, since laser+Draw isn't a real combination.
  A third strategy, clearing all copper except the traces, is planned
  but not built yet (needs a second board-outline Gerber layer and a
  fill-hatching toolpath generator, neither of which exist yet).
- The usual CNC fields (tool diameter, isolation gap, passes/stepover,
  cut depth, feed/plunge rate, spindle RPM) or laser fields (power,
  feed) depending on **Tool**, then **Generate G-Code**.

**Double-sided registration** (its own section, CNC-only): drills 1-2
small tooling holes at explicit XY positions via **Generate
Registration Holes** — its own small standalone program, separate from
the main toolpath, meant to be run once before machining either side.
Flip the board around dowel pins pushed through those same holes for
the second side, and check **Mirror before generating** (with the right
**Mirror axis X**) before regenerating that side's own toolpath, so it
lands correctly once physically flipped.

## Terminal tab

![Terminal tab](screenshots/terminal-tab.png)

Raw view of what the connected board actually sends back (its own
welcome banner, status reports, `ok`/error responses) — useful for
seeing exactly what's happening at the protocol level, or for sending a
one-off manual command via the **Send** field at the bottom. Only shows
RECEIVED traffic, not lines this app sends out — check the Editor's own
status area or the relevant tab's own status message for confirmation
that something was actually sent.

## Tools tab

A simple end-mill/bit table (diameter, flutes, length, stepover,
comments), persisted between sessions. **Load preset...** fills a row
from a built-in catalog (real FreeCAD Tool Bit Editor defaults — common
endmill/V-bit/drill sizes); **Parametric tool...** opens a small wizard
that builds a fully-specified tool from a shape template (Endmill/Ball
End/Bull Nose/V-Bit/Drill/Chamfer) plus its own real parameters instead
of picking from a fixed size list.

## Settings ($$) tab

Shows every `$N=value` the board reports. **Refresh** re-reads them;
**Apply** sends back only the rows you actually changed. **Fetch
Descriptions** pulls rich per-setting descriptions from the board if it
supports grblHAL's `$ES` extension; otherwise standard grbl 1.1 settings
still get a human-readable description from a built-in table.

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

## Macros tab

Custom buttons, each enqueuing its own saved g-code when clicked. Two
grid columns (click a cell to toggle) flag a button to also fire
automatically at job **Start**/**End** — for any job, laser or plain
CNC — without a manual click.

## Hotkeys tab

Rebind the keyboard-jog shortcuts listed under the Control tab above,
without hand-editing `hotkeys.ini`.

## Laser group

Raster Import, SVG / Vectorize, Laser Test Patterns, Laser Control and
Materials — the laser-engraving side of this app, fully built (image
import + dithering, SVG import/vectorize/centerline tracing with
color-filtered layers, holding tabs for cutouts, named header/footer
presets, power/feed/rapid overrides, auto-cooling). Not yet illustrated
with screenshots in this guide — a later pass covers this group the
same way the Machine group is covered above.

## Language

**Language** menu: English, Hrvatski, Deutsch. Switches immediately,
persists across restarts. Coverage is thorough but not perfect — a few
fields are still sized for English text and may clip slightly in
Croatian or German (visible in a couple of the screenshots above too —
e.g. Probe's "Probe fee[d]" and Gerber Import's field-label overlap at
this window size, both real, both cosmetic).

## What's not here yet

- The PCB "clear all copper except traces" strategy (Gerber Import tab)
  — needs a board-outline Gerber layer and a fill-hatching toolpath
  generator, neither built yet.
- This guide's own Laser and Settings & Tools group screenshots — text
  descriptions above are accurate, just not yet illustrated.

If something else seems undocumented or behaves differently than
described here, don't assume it's intentional — open an issue and ask.
