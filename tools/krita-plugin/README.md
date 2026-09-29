# GRBL Controller Sender - Krita bridge

Sends the active Krita document straight into GRBL Controller Sender's
Raster Import tab, without a manual Export + File>Open round trip.

## Install

Copy the `.desktop` file and the plugin folder into Krita's `pykrita`
resource directory:

```
mkdir -p ~/.local/share/krita/pykrita
cp grbl_sender_bridge.desktop ~/.local/share/krita/pykrita/
cp -r grbl_sender_bridge ~/.local/share/krita/pykrita/
```

Then in Krita: **Settings > Configure Krita > Python Plugin Manager**,
tick "GRBL Sender Bridge", and restart Krita.

## Use

**Tools > Scripts > Send to GRBL Sender**

If GRBL Controller Sender is already running, it automatically switches to
its "Raster Import" tab and loads the exported PNG - works whether or not
it's connected to a controller yet. If it isn't running, the PNG is still
exported to `/tmp/grbl_sender_bridge.png`; open it there manually.

## How it works

The plugin exports the active document (flattened) via `libkis`'s own
`Document.exportImage(path, InfoObject())` call to a fixed temp file, then
writes a one-line `IMPORT_RASTER:<path>` message to GRBL Controller
Sender's own Unix FIFO at
`~/.config/GRBL-Controller-Sender/sincrostart.fifo` - **the exact same
message format the GIMP bridge already defines**, so GRBL Controller
Sender's own listener needed no changes to support this bridge too; GIMP
and Krita are just two different senders of the identical message.
