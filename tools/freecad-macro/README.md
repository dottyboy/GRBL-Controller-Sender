# GRBL Controller Sender - FreeCAD bridge

Sends the active FreeCAD document's 2D geometry (Draft/Sketcher objects)
straight into GRBL Controller Sender's "SVG / Vectorize" tab, without a
manual Export + File>Open round trip.

Targets FreeCAD's 2D drawing side - only objects with a `Shape` (Draft,
Sketch, Part 2D objects) export; parametric 3D solids have no meaningful
laser/CNC-2D equivalent and are silently skipped.

## Install

Copy the macro into FreeCAD's user macro directory (Linux, FreeCAD 0.20+):

```
cp GrblSenderBridge.FCMacro ~/.local/share/FreeCAD/Macro/
```

Then in FreeCAD: **Macro > Macros...**, select `GrblSenderBridge`, and
optionally add it to a toolbar via **Macro > Macros... > Toolbar icon...**
for one-click access.

## Use

Select the objects to export (or select nothing to export the whole
active document), then run the macro (**Macro > Macros... > Execute**, or
its toolbar button if added).

If GRBL Controller Sender is already running, it automatically switches to
its "SVG / Vectorize" tab and loads the exported file - works whether or
not it's connected to a controller yet. If it isn't running, the SVG is
still exported to `/tmp/grbl_sender_bridge.svg`; open it there manually.

## How it works

The macro exports the selection (or the whole document) via FreeCAD's own
real `Draft` module SVG exporter (`importSVG.export(objects, path)`) to a
fixed temp file, then writes a one-line `IMPORT_SVG:<path>` message to GRBL
Controller Sender's own Unix FIFO at
`~/.config/GRBL-Controller-Sender/sincrostart.fifo` - the same mechanism
its own multi-instance "SincroStart" trigger uses (see
`src/protocol/usincrostart.pas` in the main repo), and the exact same
message tag the Inkscape/QCAD bridges already send - FreeCAD is just
another sender of the identical message.

Verified against a real, installed FreeCAD 1.1.3 (not just syntax-checked):
`importSVG.export()` on a real Draft rectangle produces a genuine SVG file,
which GRBL Controller Sender then correctly loads end-to-end.
