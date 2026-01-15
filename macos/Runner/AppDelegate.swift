import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate, NSWindowDelegate {
  private var statusItem: NSStatusItem?
  private var statusMenu: NSMenu?
  private weak var mainWindow: NSWindow?
  private var isTerminating: Bool = false

  private func log(_ message: String) {
    // NSLog(message)
    // print(message)
  }

  override func applicationDidFinishLaunching(_ aNotification: Notification) {
    super.applicationDidFinishLaunching(aNotification)
  }

  override func awakeFromNib() {
    super.awakeFromNib()

    log("AppDelegate awakeFromNib")

    NSApp.setActivationPolicy(.regular)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      NSApp.activate(ignoringOtherApps: true)
      self?.mainFlutterWindow?.makeKeyAndOrderFront(nil)
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
      self?.log("AppDelegate creating status item")
      self?.setupStatusItem()
      
      if let window = self?.mainFlutterWindow {
        self?.bindMainWindow(window)
      }
    }
  }

  func bindMainWindow(_ window: NSWindow) {
    self.mainWindow = window
    window.delegate = self
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    if isTerminating {
      return true
    }

    self.mainWindow = sender
    sender.orderOut(nil)
    NSApp.setActivationPolicy(.accessory)
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    showMainWindow()
    return true
  }

  private func fallbackStatusImage() -> NSImage {
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size)
    image.lockFocus()

    let text = "S3" as NSString
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
      .foregroundColor: NSColor.black,
      .paragraphStyle: paragraph,
    ]
    text.draw(in: NSRect(x: 0, y: 3, width: size.width, height: size.height), withAttributes: attributes)

    image.unlockFocus()
    image.isTemplate = true
    return image
  }

  private func setupStatusItem() {
    if statusItem != nil {
      log("setupStatusItem skipped: already created")
      return
    }

    log("setupStatusItem creating NSStatusItem")

    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item.isVisible = true
    self.statusItem = item

    if let button = item.button {
      button.title = "S3"
      button.image = nil
    } else {
      log("statusItem button is nil")
    }

    let menu = NSMenu()
    let openItem = NSMenuItem(title: "打开应用", action: #selector(showMainWindow), keyEquivalent: "")
    openItem.target = self
    menu.addItem(openItem)
    menu.addItem(NSMenuItem.separator())
    let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)

    self.statusMenu = menu
    item.menu = menu
  }

  @objc private func showMainWindow() {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    let window = mainWindow ?? NSApplication.shared.windows.first
    window?.makeKeyAndOrderFront(nil)
  }

  @objc private func quitApp() {
    isTerminating = true
    NSApp.terminate(nil)
  }
}
