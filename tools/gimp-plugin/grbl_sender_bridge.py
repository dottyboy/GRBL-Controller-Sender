#!/usr/bin/env python3
"""GRBL Controller Sender bridge - GIMP 3.0 plug-in (plan Phase 28).

Exports the current (flattened) image as PNG to a fixed temp path, then
signals GRBL Controller Sender (if running) to load it straight into its
own Raster Import tab - via the same tagged Unix-FIFO message its own
"SincroStart" trigger already defines ("IMPORT_RASTER:<path>", see
src/protocol/usincrostart.pas in the main GRBL-Controller-Sender repo).

GIMP 3.0 only, not 2.10 - 3.0's plugin API moved to GObject Introspection
(Gimp.PlugIn / do_query_procedures / do_create_procedure), a different
shape from 2.10's Script-Fu/Python-Fu API. No image-processing logic
duplicated here - GIMP's own crop/level/dither tools stay in GIMP, this
app's own Raster Import tab still owns dithering/scan-direction/g-code
generation.
"""

import os
import sys

import gi
gi.require_version('Gimp', '3.0')
from gi.repository import Gimp, Gio, GLib

SINCROSTART_FIFO = os.path.expanduser(
    '~/.config/GRBL-Controller-Sender/sincrostart.fifo')
EXPORT_PATH = '/tmp/grbl_sender_bridge.png'


def send_sincrostart_message(line):
    """Non-blocking FIFO write - see the Inkscape bridge's own copy of
    this same function for why (a blocking write would freeze GIMP's UI
    thread if GRBL Controller Sender isn't running)."""
    try:
        fd = os.open(SINCROSTART_FIFO, os.O_WRONLY | os.O_NONBLOCK)
    except OSError:
        return False
    try:
        os.write(fd, (line + '\n').encode('utf-8'))
        return True
    finally:
        os.close(fd)


class GrblSenderBridge(Gimp.PlugIn):
    def do_query_procedures(self):
        return ['grbl-sender-bridge']

    def do_create_procedure(self, name):
        procedure = Gimp.ImageProcedure.new(
            self, name, Gimp.PDBProcType.PLUGIN, self.run, None)
        procedure.set_image_types('*')
        procedure.set_menu_label('Send to GRBL Sender')
        procedure.add_menu_path('<Image>/File/Export/')
        procedure.set_documentation(
            'Send to GRBL Controller Sender',
            'Exports the flattened image as PNG and signals GRBL '
            'Controller Sender to load it into its Raster Import tab.',
            name)
        procedure.set_attribution(
            'GRBL-Controller-Sender project', '', '2026')
        return procedure

    def run(self, procedure, run_mode, image, drawables, config, run_data):
        dup = image.duplicate()
        dup.flatten()
        gfile = Gio.File.new_for_path(EXPORT_PATH)
        Gimp.file_save(Gimp.RunMode.NONINTERACTIVE, dup, gfile, None)
        dup.delete()

        if send_sincrostart_message('IMPORT_RASTER:' + EXPORT_PATH):
            Gimp.message('Sent to GRBL Controller Sender: ' + EXPORT_PATH)
        else:
            Gimp.message(
                'GRBL Controller Sender is not running - exported to ' +
                EXPORT_PATH + ' anyway, open it there manually.')

        return procedure.new_return_values(
            Gimp.PDBStatusType.SUCCESS, GLib.Error())


Gimp.main(GrblSenderBridge.__gtype__, sys.argv)
