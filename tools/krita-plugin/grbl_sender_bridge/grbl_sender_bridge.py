"""GRBL Controller Sender bridge - Krita (PyKrita) plugin (plan Phase 29).

Exports the active document as PNG to a fixed temp path, then signals
GRBL Controller Sender (if running) to load it straight into its own
Raster Import tab - via the same tagged Unix-FIFO message the GIMP
bridge already defines ("IMPORT_RASTER:<path>", see
src/protocol/usincrostart.pas in the main GRBL-Controller-Sender repo).
Reuses that exact message format rather than inventing a second one -
GIMP and Krita are just two different senders of the identical message.
"""

import os

from krita import Extension, Krita, InfoObject
from PyQt5.QtWidgets import QMessageBox

SINCROSTART_FIFO = os.path.expanduser(
    '~/.config/GRBL-Controller-Sender/sincrostart.fifo')
EXPORT_PATH = '/tmp/grbl_sender_bridge.png'


def send_sincrostart_message(line):
    """Non-blocking FIFO write - see the Inkscape/GIMP bridges' own copy
    of this same function for why (a blocking write would freeze Krita's
    UI thread if GRBL Controller Sender isn't running)."""
    try:
        fd = os.open(SINCROSTART_FIFO, os.O_WRONLY | os.O_NONBLOCK)
    except OSError:
        return False
    try:
        os.write(fd, (line + '\n').encode('utf-8'))
        return True
    finally:
        os.close(fd)


class GrblSenderBridge(Extension):
    def __init__(self, parent):
        super().__init__(parent)

    def setup(self):
        pass

    def createActions(self, window):
        action = window.createAction(
            'grbl_sender_bridge', 'Send to GRBL Sender', 'tools/scripts')
        action.triggered.connect(self.send_to_grbl_sender)

    def send_to_grbl_sender(self):
        doc = Krita.instance().activeDocument()
        if doc is None:
            return
        doc.exportImage(EXPORT_PATH, InfoObject())

        if send_sincrostart_message('IMPORT_RASTER:' + EXPORT_PATH):
            msg = 'Sent to GRBL Controller Sender: ' + EXPORT_PATH
        else:
            msg = ('GRBL Controller Sender is not running - exported to '
                   + EXPORT_PATH + ' anyway, open it there manually.')

        window = Krita.instance().activeWindow()
        parent = window.qwindow() if window is not None else None
        QMessageBox.information(parent, 'GRBL Sender Bridge', msg)
