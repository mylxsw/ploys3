import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers
import UserNotifications

// MARK: - Menu Bar Icon State
// 菜单栏图标状态枚举
enum MenuBarIconState: String {
  case normal = "normal"           // 默认状态
  case ready = "ready"             // 准备上传状态（用户正在拖拽文件）
  case hover = "hover"             // 悬停状态（文件拖到图标上方）
  case uploading = "uploading"     // 上传中状态（Flutter 端控制）
}

// MARK: - Drop Zone File Filter Configuration
// 拖拽上传支持的文件类型配置 - 修改这里可以自定义支持的文件扩展名
struct DropZoneFileFilter {
  // 支持的文件扩展名列表（小写，不带点）
  // 设置为空数组 [] 表示支持所有文件类型
  static let allowedExtensions: Set<String> = [
    // 图片格式
    "jpg", "jpeg", "png", "gif", "bmp", "webp", "svg", "tiff", "tif", "ico", "heic", "heif",
    // 其它格式
    "pdf", "doc", "docx", "txt", "md", "mp4", "mov", "mp3", "wav"
  ]
  
  // 检查文件是否符合过滤条件
  static func isFileAllowed(_ filePath: String) -> Bool {
    // 如果允许的扩展名为空，则支持所有文件
    if allowedExtensions.isEmpty { return true }
    
    let ext = (filePath as NSString).pathExtension.lowercased()
    return allowedExtensions.contains(ext)
  }
  
  // 检查文件列表中是否有符合条件的文件
  static func hasAllowedFiles(_ filePaths: [String]) -> Bool {
    return filePaths.contains { isFileAllowed($0) }
  }
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
  static let uploadingSymbolAlt = "arrow.up.circle.fill"
  
  // 旧版 macOS 的后备文本（不支持 SF Symbols 时使用）
  static let normalFallbackText = "S3"
  static let readyFallbackText = "↑"
  static let hoverFallbackText = "⬆"
  static let uploadingFallbackText = "..."
  static let uploadingFallbackTextAlt = "⬆"
  
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

// MARK: - Drop Zone Window
// 文件上传拖放窗口
class DropZoneWindow: NSWindow {
  weak var appDelegate: AppDelegate?
  
  init() {
    // 创建一个紧凑的圆角矩形窗口
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: 160, height: 100),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    
    self.isOpaque = false
    self.backgroundColor = .clear
    self.level = .floating
    self.hasShadow = true
    self.isReleasedWhenClosed = false
    self.ignoresMouseEvents = false
    
    // 设置内容视图
    let dropView = DropZoneView(frame: NSRect(x: 0, y: 0, width: 160, height: 100))
    dropView.dropWindow = self
    self.contentView = dropView
  }
  
  func positionBelowStatusItem(_ statusItem: NSStatusItem?) {
    guard let button = statusItem?.button,
          let buttonWindow = button.window else { return }
    
    // 获取菜单栏图标的屏幕位置
    let buttonFrame = button.convert(button.bounds, to: nil)
    let screenFrame = buttonWindow.convertToScreen(buttonFrame)
    
    // 计算窗口位置（在图标下方居中）
    let windowWidth = self.frame.width
    let x = screenFrame.midX - windowWidth / 2
    let y = screenFrame.minY - self.frame.height - 5
    
    self.setFrameOrigin(NSPoint(x: x, y: y))
  }
}

// 拖放区域视图
class DropZoneView: NSView {
  weak var dropWindow: DropZoneWindow?
  private var isHovering = false
  
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    registerForDraggedTypes([.fileURL])
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    registerForDraggedTypes([.fileURL])
  }
  
  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    drawDropZone(in: self.bounds)
  }
  
  // 检测当前是否为深色模式
  private var isDarkMode: Bool {
    if #available(macOS 10.14, *) {
      return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
    return false
  }
  
  private func drawDropZone(in bounds: NSRect) {
    let cornerRadius: CGFloat = 12
    let padding: CGFloat = 2
    let darkMode = isDarkMode
    
    // 外层背景
    let outerRect = bounds.insetBy(dx: padding, dy: padding)
    let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: cornerRadius, yRadius: cornerRadius)
    
    // 根据主题和状态设置颜色
    let bgColor: NSColor
    let borderColor: NSColor
    let dashColor: NSColor
    let contentColor: NSColor
    
    if isHovering {
      bgColor = NSColor.systemBlue.withAlphaComponent(0.95)
      borderColor = NSColor.white.withAlphaComponent(0.5)
      dashColor = NSColor.white.withAlphaComponent(0.8)
      contentColor = NSColor.white
    } else if darkMode {
      bgColor = NSColor(white: 0.15, alpha: 0.95)
      borderColor = NSColor.white.withAlphaComponent(0.2)
      dashColor = NSColor.white.withAlphaComponent(0.4)
      contentColor = NSColor.white
    } else {
      bgColor = NSColor(white: 0.98, alpha: 0.95)
      borderColor = NSColor.black.withAlphaComponent(0.15)
      dashColor = NSColor.black.withAlphaComponent(0.3)
      contentColor = NSColor.black.withAlphaComponent(0.8)
    }
    
    bgColor.setFill()
    outerPath.fill()
    
    // 边框
    borderColor.setStroke()
    outerPath.lineWidth = 1.5
    outerPath.stroke()
    
    // 虚线边框区域
    let innerRect = outerRect.insetBy(dx: 10, dy: 10)
    let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: 8, yRadius: 8)
    
    dashColor.setStroke()
    innerPath.lineWidth = 2
    innerPath.setLineDash([6, 4], count: 2, phase: 0)
    innerPath.stroke()
    
    let centerX = bounds.midX
    let centerY = bounds.midY
    
    // 上传图标
    if #available(macOS 11.0, *) {
      let symbolName = isHovering ? "arrow.up.circle.fill" : "icloud.and.arrow.up"
      if let icon = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
        let config = NSImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        if let configuredIcon = icon.withSymbolConfiguration(config) {
          let iconSize: CGFloat = 32
          let iconRect = NSRect(
            x: centerX - iconSize / 2,
            y: centerY + 5,
            width: iconSize,
            height: iconSize
          )
          // 将图标着色为对应颜色
          let tintedIcon = configuredIcon.copy() as! NSImage
          tintedIcon.lockFocus()
          contentColor.set()
          NSRect(origin: .zero, size: tintedIcon.size).fill(using: .sourceAtop)
          tintedIcon.unlockFocus()
          tintedIcon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
      }
    }
    
    // 提示文字
    let text = isHovering ? "Release to Upload" : "Drop Here"
    let textAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 12, weight: .medium),
      .foregroundColor: contentColor.withAlphaComponent(0.9)
    ]
    let textSize = (text as NSString).size(withAttributes: textAttributes)
    let textRect = NSRect(
      x: centerX - textSize.width / 2,
      y: centerY - 25,
      width: textSize.width,
      height: textSize.height
    )
    (text as NSString).draw(in: textRect, withAttributes: textAttributes)
  }
  
  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    isHovering = true
    dropWindow?.appDelegate?.setIconState(.hover)
    needsDisplay = true
    return .copy
  }
  
  override func draggingExited(_ sender: NSDraggingInfo?) {
    isHovering = false
    dropWindow?.appDelegate?.setIconState(.ready)
    needsDisplay = true
  }
  
  override func draggingEnded(_ sender: NSDraggingInfo) {
    isHovering = false
    dropWindow?.appDelegate?.setIconState(.normal)
    dropWindow?.appDelegate?.hideDropZoneWindow()
    needsDisplay = true
  }
  
  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    isHovering = false
    dropWindow?.appDelegate?.setIconState(.normal)
    dropWindow?.appDelegate?.hideDropZoneWindow()
    
    guard let items = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
      return false
    }
    
    let filePaths = items.map { $0.path }
    dropWindow?.appDelegate?.handleDroppedFiles(filePaths)
    return true
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
    NSLog("[S3Manager] DraggableStatusBarView draggingEntered")
    appDelegate?.setIconState(.hover)
    return .copy
  }
  
  override func draggingExited(_ sender: NSDraggingInfo?) {
    NSLog("[S3Manager] DraggableStatusBarView draggingExited")
    appDelegate?.setIconState(.ready)
  }
  
  override func draggingEnded(_ sender: NSDraggingInfo) {
    NSLog("[S3Manager] DraggableStatusBarView draggingEnded")
    appDelegate?.setIconState(.normal)
  }
  
  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    NSLog("[S3Manager] DraggableStatusBarView performDragOperation")
    appDelegate?.setIconState(.normal)
    
    guard let items = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
      NSLog("[S3Manager] DraggableStatusBarView: No files found in pasteboard")
      return false
    }
    
    let filePaths = items.map { $0.path }
    NSLog("[S3Manager] DraggableStatusBarView: Dropped files: \(filePaths)")
    appDelegate?.handleDroppedFiles(filePaths)
    return true
  }
}

@main
class AppDelegate: FlutterAppDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
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
  private var dropZoneWindow: DropZoneWindow?
  private var isMenuBarEnabled: Bool = true  // 菜单栏图标是否启用
  private var isQuickUploadEnabled: Bool = true  // 快捷上传功能是否启用
  private var dragMonitorTimer: Timer?  // 拖拽监控定时器引用
  private var uploadAnimationTimer: Timer?
  private var uploadAnimationPhase: Bool = false
  private var notificationAuthorizationRequested: Bool = false
  private var notificationAuthorized: Bool = false

  private func log(_ message: String) {
    NSLog("[S3Manager] \(message)")
  }

  override func applicationDidFinishLaunching(_ aNotification: Notification) {
    super.applicationDidFinishLaunching(aNotification)
    log("applicationDidFinishLaunching called")
    // 注意：setupFlutterChannel 和 setupGlobalDragMonitoring 已移至 awakeFromNib 中
  }
  
  private func setupGlobalDragMonitoring() {
    // 使用定时器轮询检查拖拽状态，这是最可靠的方法
    dragMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
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
  
  // MARK: - Menu Bar Visibility Control
  
  /// 设置菜单栏图标是否显示
  func setMenuBarEnabled(_ enabled: Bool) {
    log("setMenuBarEnabled: \(enabled)")
    isMenuBarEnabled = enabled
    
    if enabled {
      // 启用菜单栏图标
      if statusItem == nil {
        setupStatusItem()
      }
      // 如果快捷上传也启用，则启动拖拽监控
      if isQuickUploadEnabled && dragMonitorTimer == nil {
        setupGlobalDragMonitoring()
      }
    } else {
      // 禁用菜单栏图标
      hideDropZoneWindow()
      
      // 移除状态栏图标
      if let item = statusItem {
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
      }
      
      // 停止拖拽监控（菜单栏关闭时，快捷上传也不可用）
      dragMonitorTimer?.invalidate()
      dragMonitorTimer = nil
    }
  }
  
  /// 获取菜单栏图标是否显示
  func getMenuBarEnabled() -> Bool {
    return isMenuBarEnabled
  }
  
  /// 设置快捷上传功能是否启用
  func setQuickUploadEnabled(_ enabled: Bool) {
    log("setQuickUploadEnabled: \(enabled)")
    isQuickUploadEnabled = enabled
    
    // 只有在菜单栏图标启用时，快捷上传设置才生效
    if isMenuBarEnabled {
      if enabled {
        if dragMonitorTimer == nil {
          setupGlobalDragMonitoring()
        }
      } else {
        hideDropZoneWindow()
        dragMonitorTimer?.invalidate()
        dragMonitorTimer = nil
      }
    }
  }
  
  /// 获取快捷上传功能是否启用
  func getQuickUploadEnabled() -> Bool {
    return isQuickUploadEnabled
  }
  
  /// 打开设置页面
  func openSettings() {
    log("openSettings called")
    // 激活应用
    NSApp.activate(ignoringOtherApps: true)
    showMainWindow()
    // 通知 Flutter 跳转到设置页面
    flutterChannel?.invokeMethod("openSettings", arguments: nil)
  }
  
  private var lastDragLogTime: Date = Date.distantPast
  private var lastPasteboardChangeCount: Int = 0
  private var dragStartChangeCount: Int = -1  // 记录拖拽开始时的 changeCount
  private var lastMouseDownState: Bool = false
  
  private func checkForFileDrag() {
    // 如果 Flutter 正在控制图标状态，不要干扰
    if isFlutterControlled { return }
    
    // 检查鼠标是否按下（正在拖拽）
    let mouseDown = NSEvent.pressedMouseButtons & 1 != 0
    
    // 检测鼠标按下的边沿（从未按下变为按下）
    let mouseJustPressed = mouseDown && !lastMouseDownState
    lastMouseDownState = mouseDown
    
    if !mouseDown { return }
    
    // 检查拖拽剪贴板是否有文件
    let dragPasteboard = NSPasteboard(name: .drag)
    let types = dragPasteboard.types ?? []
    
    // 如果剪贴板为空，直接返回
    if types.isEmpty { return }
    
    // 获取当前剪贴板变化计数
    let currentChangeCount = dragPasteboard.changeCount
    
    // 关键：只有当剪贴板在鼠标按下后发生变化时，才认为是真正的拖拽
    // 这样可以避免仅仅选中文件就触发的问题
    if mouseJustPressed {
      // 记录鼠标刚按下时的 changeCount
      dragStartChangeCount = currentChangeCount
      return  // 第一次检测时不触发，等待下一次检测
    }
    
    // 如果 changeCount 没有变化（与拖拽开始时相同），说明不是新的拖拽操作
    if currentChangeCount == dragStartChangeCount {
      return
    }
    
    // 如果已经处理过这个 changeCount，跳过
    if currentChangeCount == lastPasteboardChangeCount {
      return
    }
    
    // 检查当前活动的应用是否是 Finder
    let frontApp = NSWorkspace.shared.frontmostApplication
    let isFinderActive = frontApp?.bundleIdentifier == "com.apple.finder"
    
    // 只有当 Finder 是当前活动应用时才检测
    if !isFinderActive { return }
    
    // 检查是否有文件 URL
    let hasFileURLs = types.contains(.fileURL) || 
                      types.contains(NSPasteboard.PasteboardType("public.file-url")) ||
                      types.contains(NSPasteboard.PasteboardType("NSFilenamesPboardType"))
    
    // 检查是否来自 Finder
    let isFromFinder = types.contains(NSPasteboard.PasteboardType("com.apple.finder.node"))
    
    // 检查拖拽的文件是否符合过滤条件（扩展名）
    var hasAllowedFiles = false
    if hasFileURLs {
      if let urls = dragPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
        let filePaths = urls.map { $0.path }
        hasAllowedFiles = DropZoneFileFilter.hasAllowedFiles(filePaths)
      }
    }
    
    let shouldShowDropZone = isFromFinder && hasFileURLs && hasAllowedFiles
    
    if shouldShowDropZone && currentIconState == .normal {
      lastPasteboardChangeCount = currentChangeCount
      log("Detected Finder file drag, showing drop zone")
      setIconState(.ready)
      showDropZoneWindow()
    }
  }
  
  private func resetDragState() {
    // 如果 Flutter 正在控制图标状态，不要干扰
    if isFlutterControlled { return }
    
    if currentIconState == .ready || currentIconState == .hover {
      setIconState(.normal)
      hideDropZoneWindow()
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
  
  private var channelRetryCount = 0
  private let maxChannelRetries = 20
  
  private func setupFlutterChannel() {
    log("setupFlutterChannel: Attempting to setup (retry \(channelRetryCount)/\(maxChannelRetries))")
    
    // 尝试多种方式获取 FlutterViewController
    var controller: FlutterViewController?
    
    // 方法1: 从 mainFlutterWindow 获取
    if let c = mainFlutterWindow?.contentViewController as? FlutterViewController {
      controller = c
      log("setupFlutterChannel: Got controller from mainFlutterWindow")
    }
    
    // 方法2: 从所有窗口中查找
    if controller == nil {
      for window in NSApplication.shared.windows {
        if let c = window.contentViewController as? FlutterViewController {
          controller = c
          log("setupFlutterChannel: Got controller from window search")
          break
        }
      }
    }
    
    guard let flutterController = controller else {
      channelRetryCount += 1
      if channelRetryCount < maxChannelRetries {
        log("setupFlutterChannel: FlutterViewController not available yet, will retry in 0.5s...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
          self?.setupFlutterChannel()
        }
      } else {
        log("setupFlutterChannel: ERROR - Max retries reached, giving up!")
      }
      return
    }
    
    log("setupFlutterChannel: Setting up Flutter channel successfully")
    flutterChannel = FlutterMethodChannel(
      name: "com.ploys3/menubar",
      binaryMessenger: flutterController.engine.binaryMessenger
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
      case "setMenuBarEnabled":
        if let enabled = call.arguments as? Bool {
          self?.setMenuBarEnabled(enabled)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected bool argument", details: nil))
        }
      case "getMenuBarEnabled":
        result(self?.getMenuBarEnabled())
      case "setQuickUploadEnabled":
        if let enabled = call.arguments as? Bool {
          self?.setQuickUploadEnabled(enabled)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected bool argument", details: nil))
        }
      case "getQuickUploadEnabled":
        result(self?.getQuickUploadEnabled())
      case "showNotification":
        if let payload = call.arguments as? [String: String],
           let title = payload["title"],
           let body = payload["body"] {
          self?.showNotification(title: title, body: body)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected title/body", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func awakeFromNib() {
    super.awakeFromNib()

    log("AppDelegate awakeFromNib")

    NSApp.setActivationPolicy(.regular)
    UNUserNotificationCenter.current().delegate = self

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      NSApp.activate(ignoringOtherApps: true)
      self?.mainFlutterWindow?.makeKeyAndOrderFront(nil)
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
      self?.log("AppDelegate creating status item")
      self?.setupFlutterChannel()  // 在这里初始化 Flutter 通道
      self?.setupGlobalDragMonitoring()
      self?.setupStatusItem()
      
      if let window = self?.mainFlutterWindow {
        self?.bindMainWindow(window)
      }
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.alert, .sound])
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
  
  private func fallbackStatusImage(for state: MenuBarIconState, overrideText: String? = nil) -> NSImage {
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size)
    image.lockFocus()
    
    let text = (overrideText ?? MenuBarIconConfig.fallbackText(for: state)) as NSString
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
    
    if state == .uploading {
      startUploadAnimation()
      return
    }

    stopUploadAnimation()
    let symbolName = MenuBarIconConfig.symbol(for: state)
    if let image = createStatusImage(symbolName: symbolName) {
      button.image = image
      button.title = ""
    } else {
      button.image = fallbackStatusImage(for: state)
      button.title = ""
    }
  }

  private func startUploadAnimation() {
    updateUploadIcon()
    uploadAnimationTimer?.invalidate()
    uploadAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
      self?.uploadAnimationPhase.toggle()
      self?.updateUploadIcon()
    }
  }

  private func stopUploadAnimation() {
    uploadAnimationTimer?.invalidate()
    uploadAnimationTimer = nil
    uploadAnimationPhase = false
  }

  private func updateUploadIcon() {
    guard let button = statusItem?.button else { return }
    let symbolName = uploadAnimationPhase
      ? MenuBarIconConfig.uploadingSymbolAlt
      : MenuBarIconConfig.uploadingSymbol
    let fallbackText = uploadAnimationPhase
      ? MenuBarIconConfig.uploadingFallbackTextAlt
      : MenuBarIconConfig.uploadingFallbackText

    if let image = createStatusImage(symbolName: symbolName) {
      button.image = image
      button.title = ""
    } else {
      button.image = fallbackStatusImage(for: .uploading, overrideText: fallbackText)
      button.title = ""
    }
  }

  private func requestNotificationAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
    if notificationAuthorizationRequested {
      completion(notificationAuthorized)
      return
    }

    notificationAuthorizationRequested = true
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
      self?.notificationAuthorized = granted
      completion(granted)
    }
  }

  private func showNotification(title: String, body: String) {
    requestNotificationAuthorizationIfNeeded { granted in
      guard granted else { return }
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body

      let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
      UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
  }
  
  func handleDroppedFiles(_ filePaths: [String]) {
    log("handleDroppedFiles called with: \(filePaths)")
    hideDropZoneWindow()
    if let channel = flutterChannel {
      log("Invoking Flutter method onFilesDropped")
      channel.invokeMethod("onFilesDropped", arguments: filePaths)
    } else {
      log("ERROR: flutterChannel is nil!")
    }
  }
  
  func showDropZoneWindow() {
    if dropZoneWindow == nil {
      dropZoneWindow = DropZoneWindow()
      dropZoneWindow?.appDelegate = self
    }
    
    dropZoneWindow?.positionBelowStatusItem(statusItem)
    dropZoneWindow?.orderFront(nil)
  }
  
  func hideDropZoneWindow() {
    dropZoneWindow?.orderOut(nil)
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
      // 注意：DraggableStatusBarView 需要能接收拖拽事件
      let draggableView = DraggableStatusBarView(frame: button.bounds)
      draggableView.appDelegate = self
      draggableView.autoresizingMask = [.width, .height]
      button.addSubview(draggableView)
      self.draggableView = draggableView
      
      log("DraggableStatusBarView added to button, frame: \(draggableView.frame)")
      
      // 设置按钮点击动作（右键显示菜单）
      button.action = #selector(statusBarButtonClicked(_:))
      button.target = self
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    } else {
      log("statusItem button is nil")
    }

    // 创建菜单但不直接设置到 statusItem，这样拖拽事件才能正常工作
    let menu = NSMenu()
    let openItem = NSMenuItem(title: "Open App", action: #selector(showMainWindow), keyEquivalent: "")
    openItem.target = self
    menu.addItem(openItem)
    
    let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
    settingsItem.target = self
    menu.addItem(settingsItem)
    
    menu.addItem(NSMenuItem.separator())
    let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)

    self.statusMenu = menu
    // 不设置 item.menu，改为手动弹出菜单，这样拖拽事件才能正常接收
    // item.menu = menu
  }

  @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
    // 左键或右键点击都显示菜单
    if let menu = statusMenu, let button = statusItem?.button {
      menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
    }
  }
  
  @objc private func showMainWindow() {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    let window = mainWindow ?? NSApplication.shared.windows.first
    window?.makeKeyAndOrderFront(nil)
  }
  
  @objc private func openSettingsFromMenu() {
    openSettings()
  }

  @objc private func quitApp() {
    isTerminating = true
    NSApp.terminate(nil)
  }
}
