"""GRBL Controller Sender bridge - KiCad PCB Editor action plugin (plan Phase 32).

Plots one PCB layer (copper, silkscreen or the board outline) of the
currently open board to a fixed-name temp SVG file via KiCad's own real
`PLOT_CONTROLLER` API, then signals GRBL Controller Sender (if running) to
load it straight into its own SVG import tab - via the same tagged
Unix-FIFO message the Inkscape/GIMP/Krita/QCAD/FreeCAD bridges already
define ("IMPORT_SVG:<path>", see src/protocol/usincrostart.pas in the main
GRBL-Controller-Sender repo). Reuses that exact message tag, no new import
path needed.

Targets PCB fabrication artwork for laser-engraving or CNC-isolation-
milling a board's copper/silkscreen - not schematic export, which has no
laser/CNC-2D equivalent.
"""

import os
import tempfile

import pcbnew
import wx

SINCROSTART_FIFO = os.path.expanduser(
    '~/.config/GRBL-Controller-Sender/sincrostart.fifo')

# (menu label, KiCad layer id) - the layers that make sense to mill/engrave.
LAYER_CHOICES = [
    ('Front copper (F.Cu)', pcbnew.F_Cu),
    ('Back copper (B.Cu)', pcbnew.B_Cu),
    ('Front silkscreen (F.SilkS)', pcbnew.F_SilkS),
    ('Back silkscreen (B.SilkS)', pcbnew.B_SilkS),
    ('Board outline (Edge.Cuts)', pcbnew.Edge_Cuts),
]


def send_sincrostart_message(line):
    """Non-blocking FIFO write - see the Inkscape/GIMP/Krita/FreeCAD
    bridges' own copy of this same function for why (a blocking write
    would freeze KiCad's UI thread if GRBL Controller Sender isn't
    running)."""
    try:
        fd = os.open(SINCROSTART_FIFO, os.O_WRONLY | os.O_NONBLOCK)
    except OSError:
        return False
    try:
        os.write(fd, (line + '\n').encode('utf-8'))
        return True
    finally:
        os.close(fd)


class GrblSenderBridge(pcbnew.ActionPlugin):
    def defaults(self):
        self.name = 'GRBL Sender Bridge - Export Layer'
        self.category = 'Export'
        self.description = (
            'Plot a PCB layer to SVG and send it to GRBL Controller Sender')
        self.show_toolbar_button = True
        self.icon_file_name = ''

    def Run(self):
        board = pcbnew.GetBoard()
        if board is None:
            wx.MessageBox('No board is open.', 'GRBL Sender Bridge')
            return

        labels = [choice[0] for choice in LAYER_CHOICES]
        dlg = wx.SingleChoiceDialog(
            None, 'Layer to export to GRBL Controller Sender:',
            'GRBL Sender Bridge', labels)
        if dlg.ShowModal() != wx.ID_OK:
            dlg.Destroy()
            return
        label, layer_id = LAYER_CHOICES[dlg.GetSelection()]
        dlg.Destroy()

        out_dir = tempfile.mkdtemp(prefix='grbl_sender_bridge_')

        plot_controller = pcbnew.PLOT_CONTROLLER(board)
        plot_options = plot_controller.GetPlotOptions()
        plot_options.SetOutputDirectory(out_dir)
        plot_options.SetPlotFrameRef(False)
        plot_options.SetMirror(False)
        plot_options.SetNegative(False)

        plot_controller.SetLayer(layer_id)
        plot_controller.OpenPlotfile('layer', pcbnew.PLOT_FORMAT_SVG, label)
        plot_controller.PlotLayer()
        svg_path = plot_controller.GetPlotFileName()
        plot_controller.ClosePlot()

        if send_sincrostart_message('IMPORT_SVG:' + svg_path):
            wx.LogMessage(
                'GRBL Sender Bridge: sent to GRBL Controller Sender: '
                + svg_path)
        else:
            wx.MessageBox(
                'GRBL Controller Sender is not running - exported to\n'
                + svg_path + '\nopen it there manually.',
                'GRBL Sender Bridge')


GrblSenderBridge().register()
