from krita import Krita
from .grbl_sender_bridge import GrblSenderBridge

Krita.instance().addExtension(GrblSenderBridge(Krita.instance()))
