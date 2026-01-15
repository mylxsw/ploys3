import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

// MARK: - Menu Bar Icon State
// 菜单栏图标状态枚举
enum MenuBarIconState: String {
  case normal = "normal"           // 默认状态
  case ready = "ready"             // 准备上传状态（用户正在拖拽文件）
  case hover = "hover"             // 悬停状态（文件拖到图标上方）
  case uploading = "uploading"     // 上传中状态（Flutter 端控制）
}

// MARK: - Menu Bar Icon Configuration
// 菜单栏图标配置 - 修改这里可以一键更换图标
struct MenuBarIconConfig {
  // 默认状态的 SF Symbol 名称
  static let normalSymbol = "externaldrive.fill.badge.icloud"
  // 准备上传状态的 SF Symbol 名称（用户正在拖拽文件）
  static let readySymbol = "arrow.up.to.line.circle"
  // 悬停状态的 SF Symbol 名称（文件拖到图标上方）
  static let hoverSymbol = "arrow.up.to.line.circle.fill"
  // 上传中状态的 SF Symbol 名称（Flutter 端控制）
  static let uploadingSymbol = "icloud.and.arrow.up"
  
  // 旧版 macOS 的后备文本（不支持 SF Symbols 时使用）
  static let normalFallbackText = "S3"
  static let readyFallbackText = "↑"
  static let hoverFallbackText = "⬆"
  static let uploadingFallbackText = "..."
  
  static func symbol(for state: MenuBarIconState) -> String {
    switch state {
    case .normal: return normalSymbol
    case .ready: return readySymbol
    case .hover: return hoverSymbol
    case .uploading: return uploadingSymbol
    }
  }
  
  static func fallbackText(for state: MenuBarIconState) -> String {
    switch state {
    case .normal: return normalFallbackText
    case .ready: return readyFallbackText
    case .hover: return hoverFallbackText
    case .uploading: return uploadingFallbackText
    }
  }
}

// Custom view for status bar button that supports drag and drop
class DraggableStatusBarView: NSView {
  weak var appDelegate: AppDelegate?
  
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    registerForDraggedTypes([.fileURL])
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    registerForDraggedTypes([.fileURL])
  }
  
  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    appDelegate?.setIconState(.hover)
    return .copy
  }
  
  override func draggingExited(_ sender: NSDraggingInfo?) {
    appDelegate?.setIconState(.ready)
  }
  
  override func draggingEnded(_ sender: NSDraggingInfo) {
    appDelegate?.setIconState(.normal)
  }
  
  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    appDelegate?.setIconState(.normal)
    
    guard let items = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
      return false
    }
    
    let filePaths = items.map { $0.path }
    appDelegate?.handleDroppedFiles(filePaths)
    return true
  }
}

@main
class AppDelegate: FlutterAppDelegate, NSWindowDelegate {
  private var statusItem: NSStatusItem?
  private var statusMenu: NSMenu?
  private weak var mainWindow: NSWindow?
  private var isTerminating: Bool = false
  private var flutterChannel: FlutterMethodChannel?
  private var draggableView: DraggableStatusBarView?
  private var globalDragMonitor: Any?
  private var globalMouseUpMonitor: Any?
  private var currentIconState: MenuBarIconState = .normal
  private var isFlutterControlled: Bool = false  // Flutter 是否正在控制图标状态

  private func log(_ message: String) {
    // NSLog(message)
    // print(message)
  }

  override func applicationDidFinishLaunching(_ aNotification: Notification) {
    super.applicationDidFinishLaunching(aNotification)
    setupFlutterChannel()
    setupGlobalDragMonitoring()
  }
  
  private func setupGlobalDragMonitoring() {
    // 使用定时器轮询检查拖拽状态，这是最可靠的方法
    Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      self?.checkForFileDrag()
    }
    
    // Monitor for mouse up to reset the icon
    globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
      self?.resetDragState()
    }
    
    NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
      self?.resetDragState()
      return event
    }
  }
  
  private func checkForFileDrag() {
    // 如果 Flutter 正在控制图标状态，不要干扰
    if isFlutterControlled { return }
    
    // Check if there's a file being dragged by checking the dragging pasteboard
    let pasteboard = NSPasteboard(name: .drag)
    let hasFiles = pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
    
    // 检查鼠标是否按下（正在拖拽）
    let mouseDown = NSEvent.pressedMouseButtons & 1 != 0
    
    if hasFiles && mouseDown && currentIconState == .normal {
      setIconState(.ready)
    }
  }
  
  private func resetDragState() {
    // 如果 Flutter 正在控制图标状态，不要干扰
    if isFlutterControlled { return }
    
    if currentIconState == .ready {
      setIconState(.normal)
    }
  }
  
  deinit {
    if let monitor = globalDragMonitor {
      NSEvent.removeMonitor(monitor)
    }
    if let monitor = globalMouseUpMonitor {
      NSEvent.removeMonitor(monitor)
    }
  }
  
  private func setupFlutterChannel() {
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      return
    }
    
    flutterChannel = FlutterMethodChannel(
      name: "com.ploys3/menubar",
      binaryMessenger: controller.engine.binaryMessenger
    )
    
    // 设置 Flutter 调用的处理器
    flutterChannel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "setIconState":
        if let stateString = call.arguments as? String,
           let state = MenuBarIconState(rawValue: stateString) {
          self?.isFlutterControlled = (state != .normal)
          self?.setIconState(state)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid state", details: nil))
        }
      case "getIconState":
        result(self?.currentIconState.rawValue)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
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

  private func createStatusImage(symbolName: String) -> NSImage? {
    if #available(macOS 11.0, *) {
      if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let configuredImage = image.withSymbolConfiguration(config)
        configuredImage?.isTemplate = true
        return configuredImage
      }
    }
    return nil
  }
  
  private func fallbackStatusImage(for state: MenuBarIconState) -> NSImage {
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size)
    image.lockFocus()
    
    let text = MenuBarIconConfig.fallbackText(for: state) as NSString
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let fontSize: CGFloat = state == .normal ? 10 : 14
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
      .foregroundColor: NSColor.black,
      .paragraphStyle: paragraph,
    ]
    let yOffset: CGFloat = state == .normal ? 3 : 1
    text.draw(in: NSRect(x: 0, y: yOffset, width: size.width, height: size.height), withAttributes: attributes)
    
    image.unlockFocus()
    image.isTemplate = true
    return image
  }
  
  func setIconState(_ state: MenuBarIconState) {
    guard currentIconState != state else { return }
    currentIconState = state
    
    guard let button = statusItem?.button else { return }
    
    let symbolName = MenuBarIconConfig.symbol(for: state)
    if let image = createStatusImage(symbolName: symbolName) {
      button.image = image
      button.title = ""
    } else {
      button.image = fallbackStatusImage(for: state)
      button.title = ""
    }
  }
  
  func handleDroppedFiles(_ filePaths: [String]) {
    flutterChannel?.invokeMethod("onFilesDropped", arguments: filePaths)
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
      // Use SF Symbol for the icon (with fallback for older macOS)
      if let image = createStatusImage(symbolName: MenuBarIconConfig.normalSymbol) {
        button.image = image
        button.title = ""
      } else {
        button.image = fallbackStatusImage(for: .normal)
        button.title = ""
      }
      
      // Setup draggable view for drag-and-drop support
      let draggableView = DraggableStatusBarView(frame: button.bounds)
      draggableView.appDelegate = self
      draggableView.autoresizingMask = [.width, .height]
      button.addSubview(draggableView)
      self.draggableView = draggableView
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
