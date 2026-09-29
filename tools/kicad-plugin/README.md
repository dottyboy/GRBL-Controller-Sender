# GRBL Controller Sender - KiCad bridge

Sends a plotted PCB layer (copper, silkscreen, or the board outline)
straight into GRBL Controller Sender's "SVG / Vectorize" tab, for
laser-engraving or CNC-isolation-milling a board's own artwork - no
manual Plot + File>Open round trip.

## Install

Copy the plugin into KiCad's user scripting plugin directory (Linux,
KiCad 7+):

```
cp grbl_sender_bridge.py ~/.local/share/kicad/<version>/scripting/plugins/
```

(replace `<version>` with your installed KiCad version, e.g. `10.0`).
Then in the PCB Editor: **Tools > External Plugins > Refresh Plugins**.
"GRBL Sender Bridge - Export Layer" appears in the same menu (and, since
`show_toolbar_button` is set, as a toolbar icon) - KiCad's own standard
Action Plugin mechanism.

## Use

With a board open in the PCB Editor, run the plugin. A small dialog asks
which layer to export (front/back copper, front/back silkscreen, or the
board outline). It plots that layer to a temp SVG file via KiCad's own
`PLOT_CONTROLLER` API.

If GRBL Controller Sender is already running, it automatically switches to
its "SVG / Vectorize" tab and loads the exported file - works whether or
not it's connected to a controller yet. If it isn't running, a dialog
gives the exported file's path to open there manually.

## How it works

The plugin is a `pcbnew.ActionPlugin` subclass - KiCad's own Python
scripting entry point, listed under Tools > External Plugins. On run, it
plots the chosen layer to SVG via KiCad's real `PLOT_CONTROLLER` (the same
API KiCad's own bundled `plot_board.py` example script uses), then writes
a one-line `IMPORT_SVG:<path>` message to GRBL Controller Sender's own
Unix FIFO at `~/.config/GRBL-Controller-Sender/sincrostart.fifo` - the
same mechanism its own multi-instance "SincroStart" trigger uses (see
`src/protocol/usincrostart.pas` in the main repo), and the exact same
message tag the Inkscape/GIMP/Krita/QCAD/FreeCAD bridges already send -
KiCad is just another sender of the identical message.

Verified against a real, installed KiCad 10.0.6 (not just docs): plotted a
real copper track on a real board to SVG via `PLOT_CONTROLLER`, confirmed
the file is genuinely valid, then sent it through the real FIFO to the
real running app - it correctly switched to "SVG / Vectorize" and loaded
the layer ("1 shapes").
