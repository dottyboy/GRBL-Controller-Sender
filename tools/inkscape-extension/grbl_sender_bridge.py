#!/usr/bin/env python3
"""GRBL Controller Sender bridge - Inkscape extension (plan Phase 27).

Exports the current document to a fixed temp SVG file, then signals
GRBL Controller Sender (if running) to load it straight into its own SVG
import tab - via the same tagged Unix-FIFO message its own multi-instance
"SincroStart" trigger already defines ("IMPORT_SVG:<path>", see
src/protocol/usincrostart.pas in the main GRBL-Controller-Sender repo).
No network, no second IPC mechanism - this bridge is just another sender
of that one message.
"""

import os
import inkex

SINCROSTART_FIFO = os.path.expanduser(
    '~/.config/GRBL-Controller-Sender/sincrostart.fifo')
EXPORT_PATH = '/tmp/grbl_sender_bridge.svg'


def send_sincrostart_message(line):
    """Non-blocking FIFO write, mirroring usincrostart.pas's own
    SendSincroStartMessage exactly: a plain blocking open would hang
    forever if GRBL Controller Sender isn't running (a FIFO write blocks
    until a reader appears), so open O_NONBLOCK and just give up if
    there's no reader (ENXIO) or no FIFO at all (ENOENT)."""
    try:
        fd = os.open(SINCROSTART_FIFO, os.O_WRONLY | os.O_NONBLOCK)
    except OSError:
        return False
    try:
        os.write(fd, (line + '\n').encode('utf-8'))
        return True
    finally:
        os.close(fd)


class GrblSenderBridge(inkex.EffectExtension):
    def effect(self):
        with open(EXPORT_PATH, 'wb') as f:
            self.save(f)

        if send_sincrostart_message('IMPORT_SVG:' + EXPORT_PATH):
            inkex.utils.debug(
                'Sent to GRBL Controller Sender: ' + EXPORT_PATH)
        else:
            inkex.utils.debug(
                'GRBL Controller Sender is not running (or its '
                'sincrostart.fifo is missing) - exported to ' +
                EXPORT_PATH + ' anyway, open it there manually via '
                '"Open SVG...".')


if __name__ == '__main__':
    GrblSenderBridge().run()
