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

// MARK: - Bear Drop Zone Window
// 小熊形状的文件上传窗口
class BearDropZoneWindow: NSWindow {
  weak var appDelegate: AppDelegate?
  
  init() {
    // 创建一个无边框、透明背景的窗口
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: 200, height: 220),
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
    let dropView = BearDropZoneView(frame: NSRect(x: 0, y: 0, width: 200, height: 220))
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

// 小熊形状的拖放区域视图
class BearDropZoneView: NSView {
  weak var dropWindow: BearDropZoneWindow?
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
    
    let bounds = self.bounds
    
    // 绘制小熊形状
    drawBearShape(in: bounds)
  }
  
  private func drawBearShape(in bounds: NSRect) {
    let centerX = bounds.midX
    let baseColor = isHovering ? NSColor.systemBlue : NSColor.systemGray
    
    // 小熊头部（主体圆形）
    let headRadius: CGFloat = 70
    let headCenter = NSPoint(x: centerX, y: bounds.height - 90)
    let headRect = NSRect(
      x: headCenter.x - headRadius,
      y: headCenter.y - headRadius,
      width: headRadius * 2,
      height: headRadius * 2
    )
    
    // 绘制耳朵
    let earRadius: CGFloat = 25
    let leftEarCenter = NSPoint(x: centerX - 50, y: bounds.height - 30)
    let rightEarCenter = NSPoint(x: centerX + 50, y: bounds.height - 30)
    
    // 左耳
    let leftEarPath = NSBezierPath(ovalIn: NSRect(
      x: leftEarCenter.x - earRadius,
      y: leftEarCenter.y - earRadius,
      width: earRadius * 2,
      height: earRadius * 2
    ))
    baseColor.withAlphaComponent(0.9).setFill()
    leftEarPath.fill()
    
    // 右耳
    let rightEarPath = NSBezierPath(ovalIn: NSRect(
      x: rightEarCenter.x - earRadius,
      y: rightEarCenter.y - earRadius,
      width: earRadius * 2,
      height: earRadius * 2
    ))
    rightEarPath.fill()
    
    // 头部主体
    let headPath = NSBezierPath(ovalIn: headRect)
    baseColor.withAlphaComponent(0.95).setFill()
    headPath.fill()
    
    // 内耳
    let innerEarRadius: CGFloat = 15
    NSColor.white.withAlphaComponent(0.3).setFill()
    NSBezierPath(ovalIn: NSRect(
      x: leftEarCenter.x - innerEarRadius,
      y: leftEarCenter.y - innerEarRadius,
      width: innerEarRadius * 2,
      height: innerEarRadius * 2
    )).fill()
    NSBezierPath(ovalIn: NSRect(
      x: rightEarCenter.x - innerEarRadius,
      y: rightEarCenter.y - innerEarRadius,
      width: innerEarRadius * 2,
      height: innerEarRadius * 2
    )).fill()
    
    // 眼睛
    let eyeRadius: CGFloat = 8
    let eyeY = headCenter.y + 15
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(
      x: centerX - 25 - eyeRadius,
      y: eyeY - eyeRadius,
      width: eyeRadius * 2,
      height: eyeRadius * 2
    )).fill()
    NSBezierPath(ovalIn: NSRect(
      x: centerX + 25 - eyeRadius,
      y: eyeY - eyeRadius,
      width: eyeRadius * 2,
      height: eyeRadius * 2
    )).fill()
    
    // 眼珠
    let pupilRadius: CGFloat = 4
    NSColor.black.setFill()
    NSBezierPath(ovalIn: NSRect(
      x: centerX - 25 - pupilRadius,
      y: eyeY - pupilRadius,
      width: pupilRadius * 2,
      height: pupilRadius * 2
    )).fill()
    NSBezierPath(ovalIn: NSRect(
      x: centerX + 25 - pupilRadius,
      y: eyeY - pupilRadius,
      width: pupilRadius * 2,
      height: pupilRadius * 2
    )).fill()
    
    // 鼻子区域（椭圆形）
    let snoutWidth: CGFloat = 40
    let snoutHeight: CGFloat = 30
    let snoutY = headCenter.y - 20
    NSColor.white.withAlphaComponent(0.5).setFill()
    NSBezierPath(ovalIn: NSRect(
      x: centerX - snoutWidth / 2,
      y: snoutY - snoutHeight / 2,
      width: snoutWidth,
      height: snoutHeight
    )).fill()
    
    // 鼻子
    let noseWidth: CGFloat = 12
    let noseHeight: CGFloat = 8
    NSColor.black.setFill()
    let nosePath = NSBezierPath(ovalIn: NSRect(
      x: centerX - noseWidth / 2,
      y: snoutY + 2,
      width: noseWidth,
      height: noseHeight
    ))
    nosePath.fill()
    
    // 嘴巴（微笑）
    let smilePath = NSBezierPath()
    smilePath.move(to: NSPoint(x: centerX, y: snoutY - 2))
    smilePath.curve(
      to: NSPoint(x: centerX + 15, y: snoutY - 8),
      controlPoint1: NSPoint(x: centerX + 5, y: snoutY - 8),
      controlPoint2: NSPoint(x: centerX + 10, y: snoutY - 10)
    )
    smilePath.move(to: NSPoint(x: centerX, y: snoutY - 2))
    smilePath.curve(
      to: NSPoint(x: centerX - 15, y: snoutY - 8),
      controlPoint1: NSPoint(x: centerX - 5, y: snoutY - 8),
      controlPoint2: NSPoint(x: centerX - 10, y: snoutY - 10)
    )
    NSColor.black.setStroke()
    smilePath.lineWidth = 2
    smilePath.stroke()
    
    // 绘制提示文字
    let text = isHovering ? "松开即可上传" : "拖拽文件即可上传"
    let textAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 13, weight: .medium),
      .foregroundColor: NSColor.white
    ]
    let textSize = (text as NSString).size(withAttributes: textAttributes)
    let textRect = NSRect(
      x: centerX - textSize.width / 2,
      y: 15,
      width: textSize.width,
      height: textSize.height
    )
    (text as NSString).draw(in: textRect, withAttributes: textAttributes)
    
    // 绘制上传图标（在小熊肚子位置）
    if #available(macOS 11.0, *) {
      if let uploadIcon = NSImage(systemSymbolName: "arrow.up.circle.fill", accessibilityDescription: nil) {
        let iconSize: CGFloat = 30
        let iconRect = NSRect(
          x: centerX - iconSize / 2,
          y: 45,
          width: iconSize,
          height: iconSize
        )
        NSColor.white.set()
        uploadIcon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)
      }
    }
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
  private var dropZoneWindow: BearDropZoneWindow?

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
    
    // 检查鼠标是否按下（正在拖拽）
    let mouseDown = NSEvent.pressedMouseButtons & 1 != 0
    if !mouseDown { return }
    
    // 检查拖拽剪贴板是否有文件
    let dragPasteboard = NSPasteboard(name: .drag)
    
    // 方法1: 检查是否可以读取文件 URL
    let hasFileURLs = dragPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
    
    // 方法2: 检查剪贴板类型是否包含文件相关类型
    let types = dragPasteboard.types ?? []
    let hasFileTypes = types.contains(.fileURL) || 
                       types.contains(NSPasteboard.PasteboardType("public.file-url")) ||
                       types.contains(NSPasteboard.PasteboardType("NSFilenamesPboardType"))
    
    // 方法3: 检查通用剪贴板（有时 Finder 会使用这个）
    let generalPasteboard = NSPasteboard.general
    let generalTypes = generalPasteboard.types ?? []
    let hasGeneralFileTypes = generalTypes.contains(.fileURL) ||
                              generalTypes.contains(NSPasteboard.PasteboardType("public.file-url"))
    
    let hasFiles = hasFileURLs || hasFileTypes || hasGeneralFileTypes
    
    // 调试日志
    if mouseDown && (types.count > 0 || generalTypes.count > 0) {
      log("checkForFileDrag: mouseDown=\(mouseDown), hasFileURLs=\(hasFileURLs), hasFileTypes=\(hasFileTypes), hasGeneralFileTypes=\(hasGeneralFileTypes)")
      log("  dragTypes: \(types.map { $0.rawValue })")
    }
    
    if hasFiles && currentIconState == .normal {
      log("Detected file drag, showing drop zone")
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
      self?.setupFlutterChannel()  // 在这里初始化 Flutter 通道
      self?.setupGlobalDragMonitoring()
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
      dropZoneWindow = BearDropZoneWindow()
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
    let openItem = NSMenuItem(title: "打开应用", action: #selector(showMainWindow), keyEquivalent: "")
    openItem.target = self
    menu.addItem(openItem)
    menu.addItem(NSMenuItem.separator())
    let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
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

  @objc private func quitApp() {
    isTerminating = true
    NSApp.terminate(nil)
  }
}
