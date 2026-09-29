# GRBL Controller Sender - Inkscape bridge

Sends the current Inkscape document straight into GRBL Controller Sender's
"SVG / Vectorize" tab, without a manual Export + File>Open round trip.

## Install

Copy both files into Inkscape's user extensions folder, then restart
Inkscape:

```
cp grbl_sender_bridge.py grbl_sender_bridge.inx ~/.config/inkscape/extensions/
```

Requires Inkscape 1.0 or newer (uses the modern `inkex.EffectExtension`
API).

## Use

Design your artwork in Inkscape as usual, then:

**Extensions > GRBL Sender > Send to GRBL Sender**

If GRBL Controller Sender is already running, it automatically switches to
its "SVG / Vectorize" tab and loads the exported file - works whether or
not it's connected to a controller yet. If it isn't running, the SVG is
still exported to `/tmp/grbl_sender_bridge.svg`; open it there manually.

## How it works

The extension exports the current document to a fixed temp file, then
writes a one-line `IMPORT_SVG:<path>` message to GRBL Controller Sender's
own Unix FIFO at `~/.config/GRBL-Controller-Sender/sincrostart.fifo` - the
exact same mechanism its own multi-instance "SincroStart" trigger uses
(`src/protocol/usincrostart.pas` in the main repo). No network, no second
IPC mechanism - this extension is just another sender of that one
message (the QCAD bridge sends the exact same `IMPORT_SVG:` tag; the
GIMP/Krita bridges send the raster equivalent, `IMPORT_RASTER:`).
