# GRBL Controller Sender - GIMP bridge

Sends the current GIMP image straight into GRBL Controller Sender's
Raster Import tab, without a manual Export + File>Open round trip.

**GIMP 3.0 only** - not 2.10. GIMP 3.0's plug-in API moved to GObject
Introspection and is different enough from 2.10's Script-Fu/Python-Fu API
that supporting both cheaply isn't practical. GIMP 2.10 users lose
nothing critical: hand-export a PNG and use Raster Import's plain
"Open Image..." instead.

## Install

GIMP 3.0 plug-ins each live in their own subfolder named after the script:

```
mkdir -p ~/.config/GIMP/3.0/plug-ins/grbl_sender_bridge
cp grbl_sender_bridge.py ~/.config/GIMP/3.0/plug-ins/grbl_sender_bridge/
chmod +x ~/.config/GIMP/3.0/plug-ins/grbl_sender_bridge/grbl_sender_bridge.py
```

Restart GIMP.

## Use

**File > Export > Send to GRBL Sender**

If GRBL Controller Sender is already running, it automatically switches to
its "Raster Import" tab and loads the exported PNG - works whether or not
it's connected to a controller yet. If it isn't running, the PNG is still
exported to `/tmp/grbl_sender_bridge.png`; open it there manually.

No image-processing logic is duplicated here - GIMP's own crop/level
tools stay in GIMP; dithering, scan-direction and g-code generation are
still entirely GRBL Controller Sender's own Raster Import pipeline.

## Depth-map note (photo -> relief carving)

Combine this bridge with the third-party **GIMP-ML** plugin (MiDaS-based
monocular depth estimation, MIT-licensed model): run GIMP-ML's depth
filter on a photo inside GIMP, then use this bridge to send the resulting
depth-map PNG straight into Raster Import. This covers "photo to real
depth relief" today with zero native code on the app's side.

## How it works

The plugin exports the flattened image to a fixed temp file, then writes
a one-line `IMPORT_RASTER:<path>` message to GRBL Controller Sender's own
Unix FIFO at `~/.config/GRBL-Controller-Sender/sincrostart.fifo` - the
same mechanism its own multi-instance "SincroStart" trigger uses (see
`src/protocol/usincrostart.pas` in the main repo). The Krita bridge sends
the exact same message tag; the Inkscape/QCAD bridges send the vector
equivalent, `IMPORT_SVG:`.
