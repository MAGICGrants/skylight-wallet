import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  // FIDO2 security keys (YubiKit over USB HID) for FHSE wallet-file encryption.
  private var securityKeyChannel: SecurityKeyChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Minimum window size so the two-pane layouts and sidebar stay usable.
    self.minSize = NSSize(width: 900, height: 640)

    RegisterGeneratedPlugins(registry: flutterViewController)
    securityKeyChannel = SecurityKeyChannel(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}
