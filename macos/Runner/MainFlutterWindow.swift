import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Finestra scura senza barra del titolo visibile, come il sito.
    self.title = "Trasloco"
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = true
    self.backgroundColor = NSColor(red: 13 / 255, green: 13 / 255, blue: 13 / 255, alpha: 1)
    self.appearance = NSAppearance(named: .darkAqua)

    self.minSize = NSSize(width: 1080, height: 700)
    self.setContentSize(NSSize(width: 1280, height: 820))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
