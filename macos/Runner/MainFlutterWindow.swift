import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Name under which macOS remembers size and position of the window.
  private static let frameName = "MainFlutterWindow"

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // The Flutter template opens at 800 x 600 on every start, which is just
    // above the 768 breakpoint of the desktop layout and forgets how the
    // user left the window. Start at a desktop size that fits the screen,
    // reopen where the window was closed, and do not let it shrink below
    // the narrowest phone layout.
    self.minSize = NSSize(width: 360, height: 560)
    if !self.setFrameUsingName(MainFlutterWindow.frameName) {
      let visible = (self.screen ?? NSScreen.main)?.visibleFrame.size
        ?? NSSize(width: 1280, height: 800)
      self.setContentSize(NSSize(
        width: min(1200, (visible.width * 0.9).rounded()),
        height: min(820, (visible.height * 0.9).rounded())))
      self.center()
    }
    self.setFrameAutosaveName(MainFlutterWindow.frameName)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
