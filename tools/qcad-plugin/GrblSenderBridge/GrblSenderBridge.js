include("scripts/EAction.js");

/**
 * GRBL Controller Sender bridge - QCAD script action (plan Phase 30).
 *
 * Exports the active drawing to a fixed temp SVG file, then signals
 * GRBL Controller Sender (if running) to load it straight into its own
 * SVG import tab - via the same tagged Unix-FIFO message the Inkscape
 * bridge already defines ("IMPORT_SVG:<path>", see
 * src/protocol/usincrostart.pas in the main GRBL-Controller-Sender
 * repo). Reuses that exact message tag rather than inventing a
 * DXF-specific one - QCAD just becomes a second sender of the identical
 * message Inkscape already produces.
 */

function GrblSenderBridge(guiAction) {
    EAction.call(this, guiAction);
}

GrblSenderBridge.prototype = new EAction();

GrblSenderBridge.EXPORT_PATH = "/tmp/grbl_sender_bridge.svg";

// Non-blocking FIFO write via a short shell helper - QtScript has no
// direct O_NONBLOCK file API, so this shells out to a "timeout"-guarded
// redirect instead. The timeout matters: a FIFO write blocks until a
// reader appears, and GRBL Controller Sender's own listener is the only
// reader - without the timeout, this would hang QCAD's UI thread forever
// if the app isn't running.
GrblSenderBridge.sendSincroStartMessage = function(line) {
    var fifoPath = QDir.homePath() + "/.config/GRBL-Controller-Sender/sincrostart.fifo";
    var proc = new QProcess();
    proc.start("timeout", ["1", "sh", "-c", "printf '%s\\n' \"$1\" > \"$2\"", "sh", line, fifoPath]);
    proc.waitForFinished(1500);
    return proc.exitCode() === 0;
};

GrblSenderBridge.prototype.beginEvent = function() {
    EAction.prototype.beginEvent.call(this);

    var doc = this.getDocument();
    if (isNull(doc)) {
        this.terminate();
        return;
    }

    var di = this.getDocumentInterface();
    di.exportFile(GrblSenderBridge.EXPORT_PATH, "SVG");

    if (GrblSenderBridge.sendSincroStartMessage("IMPORT_SVG:" + GrblSenderBridge.EXPORT_PATH)) {
        print("Sent to GRBL Controller Sender: " + GrblSenderBridge.EXPORT_PATH);
    } else {
        print("GRBL Controller Sender is not running - exported to " +
              GrblSenderBridge.EXPORT_PATH + " anyway, open it there manually.");
    }

    this.terminate();
};

GrblSenderBridge.init = function(basePath) {
    var action = new RGuiAction(qsTr("&Send to GRBL Sender"), RMainWindowQt.getMainWindow());
    action.setRequiresDocument(true);
    action.setScriptFile(basePath + "/GrblSenderBridge.js");
    action.setGroupSortOrder(100000);
    action.setSortOrder(0);
    // "MiscMenu" is QCAD's existing miscellaneous-scripts menu. If your
    // QCAD version registers community scripts under a different menu
    // id, change this line to match (see this folder's README).
    action.setWidgetNames(["MiscMenu"]);
};
