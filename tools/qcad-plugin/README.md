# GRBL Controller Sender - QCAD bridge

Sends the active QCAD drawing straight into GRBL Controller Sender's
"SVG / Vectorize" tab, without a manual Export + File>Open round trip.

Uses QCAD's SVG export (native, not just DXF) - deliberately reuses the
same `IMPORT_SVG:` message the Inkscape bridge sends, not a DXF-specific
one. Native DXF import is a separate, not-yet-built capability in GRBL
Controller Sender itself; this bridge sticks to the cheap SVG-export
path, same as the Inkscape/FreeCAD/KiCad bridges.

## Install

Copy the folder into QCAD's `scripts` directory (inside your QCAD
installation, or your user scripts directory if you've set one up):

```
cp -r GrblSenderBridge /path/to/qcad/scripts/
```

Restart QCAD, or use **Script > Reload Scripts** if available in your
version.

## Use

The action registers under QCAD's "Misc" menu by default: **Misc > Send
to GRBL Sender**. If it doesn't appear there in your QCAD version, open
`GrblSenderBridge/GrblSenderBridge.js` and change the `setWidgetNames`
line near the bottom to match an existing menu id in your install (check
another installed script's own `init()` function for a working example).

If GRBL Controller Sender is already running, it automatically switches to
its "SVG / Vectorize" tab and loads the exported file - works whether or
not it's connected to a controller yet. If it isn't running, the SVG is
still exported to `/tmp/grbl_sender_bridge.svg`; open it there manually.

## How it works

The script exports the active drawing via QCAD's own
`RDocumentInterface.exportFile(path, "SVG")` call to a fixed temp file,
then writes a one-line `IMPORT_SVG:<path>` message to GRBL Controller
Sender's own Unix FIFO at
`~/.config/GRBL-Controller-Sender/sincrostart.fifo` (the same mechanism
its own multi-instance "SincroStart" trigger uses - see
`src/protocol/usincrostart.pas` in the main repo), via a short
`timeout`-guarded shell helper since QtScript has no direct non-blocking
file-write API of its own.

**Disclosed limitation:** this script is adapted directly from QCAD's own
documented scripting API (RGuiAction/EAction/RDocumentInterface), but
wasn't run against a real QCAD installation while writing it - the exact
menu registration (`setWidgetNames`) may need the one-line adjustment
described above depending on your QCAD version.
