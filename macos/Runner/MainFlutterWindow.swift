import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let splashColor = NSColor(
      srgbRed: 242.0 / 255.0,
      green: 245.0 / 255.0,
      blue: 249.0 / 255.0,
      alpha: 1.0
    )
    flutterViewController.backgroundColor = splashColor
    self.backgroundColor = splashColor
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
