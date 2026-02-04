import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ploys3/core/platform.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:ploys3/models/s3_server_config.dart';
import 'package:ploys3/s3_config_page.dart';
import 'package:ploys3/s3_browser_page.dart';
import 'package:ploys3/settings_page.dart';
import 'package:ploys3/core/design_system.dart';
import 'package:ploys3/core/theme_manager.dart';
import 'package:ploys3/core/language_manager.dart';
import 'package:ploys3/core/localization.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:ploys3/widgets/window_title_bar.dart';
import 'package:ploys3/core/mcp/mcp_settings_manager.dart';
import 'package:ploys3/core/menubar_settings_manager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ploys3/core/upload_manager.dart';
import 'package:ploys3/core/storage/s3_storage_service.dart';
import 'package:ploys3/image_bed_settings_page.dart';
import 'package:path/path.dart' as p;
import 'package:ploys3/widgets/upload_queue_ui.dart';

/// Method channel for macOS menu bar communication
const MethodChannel _menuBarChannel = MethodChannel('com.ploys3/menubar');

final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
final ValueNotifier<UploadManager?> _imageBedUploadManagerNotifier = ValueNotifier<UploadManager?>(null);
UploadManager? _imageBedUploadManager;
String? _imageBedUploadServerId;

/// 全局导航 key，用于从菜单栏打开设置页面
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 打开设置页面的回调函数
VoidCallback? onOpenSettingsCallback;

/// Placeholder function for handling files dropped on menu bar icon.
Future<void> onMenuBarFilesDropped(List<String> filePaths) async {
  if (filePaths.isEmpty) return;
  final config = await _loadImageBedConfig();
  if (config == null) {
    await _promptConfigureImageBed();
    return;
  }
  await _uploadImageBedFiles(filePaths, config);
}

Future<void> _initLocalNotifications() async {
  final DarwinInitializationSettings darwinSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
    notificationCategories: <DarwinNotificationCategory>[
      DarwinNotificationCategory(
        UploadManager.copyMarkdownCategoryId,
        actions: <DarwinNotificationAction>[
          DarwinNotificationAction.plain(
            UploadManager.copyMarkdownActionId,
            LanguageManager.instance.getLocalized('copy_markdown'),
          ),
        ],
      ),
    ],
  );
  const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const WindowsInitializationSettings windowsSettings = WindowsInitializationSettings(
    appName: 'Ploy S3',
    appUserModelId: 'PloyS3.PloyS3',
    guid: '54e1f5c6-1a3b-4d64-9a6b-7b8f47d59f1e',
  );
  const LinuxInitializationSettings linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');
  final InitializationSettings initSettings = InitializationSettings(
    macOS: darwinSettings,
    android: androidSettings,
    windows: windowsSettings,
    linux: linuxSettings,
  );
  await _localNotifications.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: _handleNotificationResponse,
  );
  UploadManager.initializeNotifications(_localNotifications);
}

class _ImageBedConfig {
  _ImageBedConfig({required this.server, required this.uploadDir, required this.namingRule});

  final S3ServerConfig server;
  final String uploadDir;
  final ImageBedNamingRule namingRule;
}

Future<_ImageBedConfig?> _loadImageBedConfig() async {
  final prefs = await SharedPreferences.getInstance();
  final serverId = prefs.getString('image_bed_server_id') ?? '';
  if (serverId.isEmpty) return null;

  final serverConfigs = prefs.getStringList('server_configs') ?? [];
  final servers = serverConfigs.map((config) => S3ServerConfig.fromJson(json.decode(config))).toList();
  final server = servers.cast<S3ServerConfig?>().firstWhere((s) => s?.id == serverId, orElse: () => null);
  if (server == null) return null;

  final uploadDir = prefs.getString('image_bed_upload_dir') ?? '';
  final namingRuleRaw = prefs.getString('image_bed_naming_rule') ?? 'original';
  final namingRule = namingRuleRaw == 'random' ? ImageBedNamingRule.random : ImageBedNamingRule.original;

  return _ImageBedConfig(server: server, uploadDir: uploadDir, namingRule: namingRule);
}

Future<void> _promptConfigureImageBed() async {
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return;

  final shouldOpen = await showDialog<bool>(
    context: ctx,
    builder: (context) {
      return AlertDialog(
        title: Text(context.loc('image_bed_settings')),
        content: Text(context.loc('image_bed_config_required')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.loc('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.loc('image_bed_go_config'))),
        ],
      );
    },
  );

  if (shouldOpen == true && ctx.mounted) {
    Navigator.push(ctx, MaterialPageRoute(builder: (context) => const ImageBedSettingsPage()));
  }
}

Future<void> _uploadImageBedFiles(List<String> filePaths, _ImageBedConfig config) async {
  final uploadManager = _getOrCreateImageBedUploadManager(config);

  final targetPrefix = _normalizeUploadPrefix(config.uploadDir);
  uploadManager.addToQueueWithNameResolver(
    filePaths,
    targetPrefix,
    (path) => _resolveImageBedFileName(path, config.namingRule),
  );
}

String _normalizeUploadPrefix(String uploadDir) {
  if (uploadDir.isEmpty) return '';
  return uploadDir.endsWith('/') ? uploadDir : '$uploadDir/';
}

String _resolveImageBedFileName(String filePath, ImageBedNamingRule namingRule) {
  final originalName = p.basename(filePath);
  if (namingRule == ImageBedNamingRule.original) {
    return originalName;
  }

  final dotIndex = originalName.lastIndexOf('.');
  final extension = dotIndex > 0 ? originalName.substring(dotIndex) : '';
  final now = DateTime.now();
  final timestamp =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  final uuid =
      '${math.Random().nextInt(0x7FFFFFFF).toRadixString(36)}-${math.Random().nextInt(0x7FFFFFFF).toRadixString(36)}';
  return '$timestamp-$uuid$extension';
}

UploadManager _getOrCreateImageBedUploadManager(_ImageBedConfig config) {
  final serverId = config.server.id;
  if (_imageBedUploadManager != null && _imageBedUploadServerId == serverId) {
    return _imageBedUploadManager!;
  }
  final service = S3StorageService(config.server);
  _imageBedUploadManager = UploadManager(service: service, cdnUrl: config.server.cdnUrl);
  _imageBedUploadServerId = serverId;
  _imageBedUploadManagerNotifier.value = _imageBedUploadManager;
  return _imageBedUploadManager!;
}

void _setupMenuBarChannel() {
  _menuBarChannel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'onFilesDropped':
        final List<String> filePaths = (call.arguments as List).cast<String>();
        await onMenuBarFilesDropped(filePaths);
        break;
      case 'openSettings':
        // 从菜单栏打开设置页面
        onOpenSettingsCallback?.call();
        break;
      default:
        throw PlatformException(code: 'Unimplemented', details: 'Method ${call.method} not implemented');
    }
  });
}

void _handleNotificationResponse(NotificationResponse response) {
  if (response.actionId != UploadManager.copyMarkdownActionId) {
    return;
  }
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;
  try {
    final data = json.decode(payload) as Map<String, dynamic>;
    final markdown = data['markdown']?.toString() ?? '';
    final hasMarkdown = data['hasMarkdown'] == true;
    if (!Platform.isDesktop || !hasMarkdown) return;
    if (markdown.isEmpty) return;
    Clipboard.setData(ClipboardData(text: markdown));
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup menu bar channel for macOS
  _setupMenuBarChannel();
  await _initLocalNotifications();

  // 初始化菜单栏设置（仅 macOS）
  if (Platform.isMacOS) {
    // 延迟初始化，确保 Flutter 通道已建立
    Future.delayed(const Duration(milliseconds: 1500), () {
      MenuBarSettingsManager.instance.initialize();
    });
  }

  // 设置系统UI样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const App());

  if (Platform.isDesktop) {
    doWhenWindowReady(() {
      const initialSize = Size(960, 700);
      appWindow.minSize = const Size(800, 600);
      appWindow.size = initialSize;
      appWindow.alignment = Alignment.center;
      appWindow.title = LanguageManager.instance.getLocalized('s3_manager');
      appWindow.show();
    });
  }
}

/// 主应用
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([ThemeManager.instance, LanguageManager.instance]),
      builder: (context, child) {
        return MaterialApp(
          title: LanguageManager.instance.getLocalized('app_name_s3'),
          theme: ThemeManager.instance.currentTheme,
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          home: const LanguageProvider(child: ThemeProvider(child: AppShell())),
        );
      },
    );
  }
}

/// 应用外壳
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  List<S3ServerConfig> _serverConfigs = [];
  S3ServerConfig? _selectedServerConfig;
  bool _isSidebarExtended = true;
  bool _isImageBedDragging = false;
  double _sidebarWidth = 220.0;
  bool _isHoveringResizeHandle = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadConfigs();
    McpSettingsManager.instance.initialize();

    // 注册从菜单栏打开设置页面的回调
    onOpenSettingsCallback = _openSettingsPage;
  }

  @override
  void dispose() {
    // 清除回调
    if (onOpenSettingsCallback == _openSettingsPage) {
      onOpenSettingsCallback = null;
    }
    super.dispose();
  }

  void _openSettingsPage() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SettingsPage()));
  }

  Future<void> _loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> serverConfigsStrings = prefs.getStringList('server_configs') ?? [];
    setState(() {
      _serverConfigs = serverConfigsStrings.map((config) => S3ServerConfig.fromJson(json.decode(config))).toList();
    });
  }

  Future<void> _deleteServer(S3ServerConfig server) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> serverConfigsStrings = prefs.getStringList('server_configs') ?? [];
    serverConfigsStrings.removeWhere((configStr) {
      final config = S3ServerConfig.fromJson(json.decode(configStr));
      return config.id == server.id;
    });
    await prefs.setStringList('server_configs', serverConfigsStrings);
    // Clear selection if deleted server was selected
    if (_selectedServerConfig?.id == server.id) {
      setState(() {
        _selectedServerConfig = null;
      });
    }
    await _loadConfigs();
  }

  void _showServerContextMenu(BuildContext context, Offset position, S3ServerConfig server) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [const Icon(Icons.edit, size: 18), const SizedBox(width: 8), Text(context.loc('edit_server'))],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 18, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              Text(context.loc('delete'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'edit') {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                S3ConfigPage(existingConfig: server, onSave: _loadConfigs),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const curve = Curves.easeOutQuart;
              var scaleAnimation = Tween(
                begin: 0.0,
                end: 1.0,
              ).animate(CurvedAnimation(parent: animation, curve: curve));
              var fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: animation, curve: curve));
              return ScaleTransition(
                scale: scaleAnimation,
                alignment: Alignment.topLeft,
                child: FadeTransition(opacity: fadeAnimation, child: child),
              );
            },
            transitionDuration: const Duration(milliseconds: 400),
            reverseTransitionDuration: const Duration(milliseconds: 300),
          ),
        );
      } else if (value == 'delete') {
        _showDeleteConfirmation(context, server);
      }
    });
  }

  void _showDeleteConfirmation(BuildContext context, S3ServerConfig server) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.loc('delete_server_title')),
        content: Text(context.loc('delete_server_message').replaceAll('{name}', server.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.loc('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text(context.loc('delete')),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        _deleteServer(server);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDrawer = Platform.isMobile;

        // Auto-collapse if width is small
        if (!useDrawer && constraints.maxWidth < 600 && _isSidebarExtended) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isSidebarExtended = false;
              });
            }
          });
        }

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          drawer: useDrawer
              ? Drawer(
                  width: math.min(constraints.maxWidth * 0.85, 320),
                  child: SafeArea(
                    child: _buildSidebar(
                      context,
                      isSidebarExtended: true,
                      sidebarWidth: math.min(constraints.maxWidth * 0.85, 320),
                      isDrawer: true,
                      onDrawerClose: () => _scaffoldKey.currentState?.closeDrawer(),
                    ),
                  ),
                )
              : null,
          body: Column(
            children: [
              // Custom Title Bar
              const WindowTitleBar(),
              Expanded(
                child: useDrawer
                    ? _buildContentArea(
                        context,
                        margin: const EdgeInsets.all(0),
                        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                      )
                    : Row(
                        children: [
                          _buildSidebar(context, isSidebarExtended: _isSidebarExtended, sidebarWidth: _sidebarWidth),

                          // Resize Handle
                          if (!useDrawer)
                            MouseRegion(
                              cursor: SystemMouseCursors.resizeColumn,
                              onEnter: (_) => setState(() => _isHoveringResizeHandle = true),
                              onExit: (_) => setState(() => _isHoveringResizeHandle = false),
                              child: GestureDetector(
                                onHorizontalDragUpdate: (details) {
                                  setState(() {
                                    // Only resize if extended
                                    if (!_isSidebarExtended) {
                                      if (details.delta.dx > 5) {
                                        _isSidebarExtended = true;
                                      }
                                      return;
                                    }

                                    _sidebarWidth += details.delta.dx;
                                    if (_sidebarWidth < 200) _sidebarWidth = 200;
                                    if (_sidebarWidth > 400) _sidebarWidth = 400;
                                  });
                                },
                                child: Container(
                                  width: 8,
                                  height: double.infinity,
                                  color: Colors.transparent,
                                  child: Center(
                                    child: Container(
                                      width: 2,
                                      color: _isHoveringResizeHandle
                                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                                          : Colors.transparent,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          Expanded(child: _buildContentArea(context, margin: const EdgeInsets.fromLTRB(0, 0, 8, 8))),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(
    BuildContext context, {
    required bool isSidebarExtended,
    required double sidebarWidth,
    bool isDrawer = false,
    VoidCallback? onDrawerClose,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isSidebarExtended ? sidebarWidth : 80,
      margin: isDrawer ? EdgeInsets.zero : const EdgeInsets.fromLTRB(8, 0, 0, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDrawer
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: NavigationRail(
          extended: isSidebarExtended,
          minExtendedWidth: sidebarWidth,
          backgroundColor: Colors.transparent,
          leading: Column(
            children: [
              if (isSidebarExtended)
                SizedBox(
                  height: Platform.isMobile ? 80 : 60,
                  width: sidebarWidth,
                  child: Stack(
                    children: [
                      // Logo - Vertically aligned
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.secondary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.cloud_outlined, size: Platform.isMobile ? 40 : 20, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context.loc('app_name_s3'),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: Platform.isMobile ? AppFontSizes.xxxl : AppFontSizes.lg,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Collapse Button - Absolute Top Right
                      if (!isDrawer)
                        Positioned(
                          top: 15,
                          right: 4,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.menu_open_rounded,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _isSidebarExtended = false;
                              });
                            },
                            tooltip: context.loc('collapse'),
                          ),
                        ),
                      if (isDrawer)
                        Positioned(
                          top: 25,
                          right: 30,
                          child: Center(
                            child: Tooltip(
                              message: context.loc('add_new_server'),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () {
                                      onDrawerClose?.call();
                                      Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          pageBuilder: (context, animation, secondaryAnimation) =>
                                              S3ConfigPage(onSave: _loadConfigs),
                                        ),
                                      );
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(Icons.add, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else
                // Collapsed: Toggle acts as logo
                Container(
                  height: 60,
                  alignment: Alignment.center,
                  child: Tooltip(
                    message: context.loc('expand'),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setState(() {
                              _isSidebarExtended = true;
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.cloud_outlined, size: 24, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              // Add Server Button
              if (!isDrawer && isSidebarExtended)
                SizedBox(
                  width: sidebarWidth - 32,
                  child: AppComponents.primaryButton(
                    text: context.loc('add_new_server'),
                    icon: Icons.add,
                    onPressed: () {
                      onDrawerClose?.call();
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => S3ConfigPage(onSave: _loadConfigs),
                        ),
                      );
                    },
                  ),
                ),
              if (!isSidebarExtended)
                Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Tooltip(
                      message: context.loc('add_new_server'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              onDrawerClose?.call();
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) =>
                                      S3ConfigPage(onSave: _loadConfigs),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.add, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          indicatorColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
          indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          destinations: [
            NavigationRailDestination(
              icon: Icon(
                Icons.home_outlined,
                size: 25,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              selectedIcon: Icon(Icons.home_filled, size: 25, color: Theme.of(context).colorScheme.primary),
              label: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: sidebarWidth - 80, // Prevent overflow
                ),
                child: Text(
                  context.loc('home'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFontSizes.md,
                    fontWeight: _selectedServerConfig == null ? FontWeight.w600 : FontWeight.normal,
                    color: _selectedServerConfig == null
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            ..._serverConfigs.map((server) {
              final isSelected = _selectedServerConfig?.id == server.id;
              return NavigationRailDestination(
                icon: Icon(
                  Icons.cloud_outlined,
                  size: 25,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                selectedIcon: Icon(Icons.cloud_done, size: 25, color: Theme.of(context).colorScheme.primary),
                label: GestureDetector(
                  onSecondaryTapDown: (details) {
                    _showServerContextMenu(context, details.globalPosition, server);
                  },
                  onLongPressStart: (details) {
                    _showServerContextMenu(context, details.globalPosition, server);
                  },
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: sidebarWidth - 80, // Prevent overflow
                    ),
                    child: Text(
                      server.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFontSizes.md,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              );
            }),
          ],
          trailing: Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Settings Button
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        onDrawerClose?.call();
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => const SettingsPage(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: isSidebarExtended
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.settings_outlined, size: 20),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      context.loc('settings'),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              )
                            : Icon(Icons.settings_outlined, size: 24),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          onDestinationSelected: (index) {
            setState(() {
              _selectedServerConfig = index <= 0 ? null : _serverConfigs[index - 1];
            });
            onDrawerClose?.call();
          },
          selectedIndex: _selectedServerConfig != null && _serverConfigs.isNotEmpty
              ? _serverConfigs.indexWhere((s) => s.id == _selectedServerConfig!.id) + 1
              : 0,
        ),
      ),
    );
  }

  Widget _buildContentArea(BuildContext context, {required EdgeInsets margin, VoidCallback? onOpenDrawer}) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _selectedServerConfig != null
            ? S3BrowserPage(
                serverConfig: _selectedServerConfig!,
                onEditServer: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          S3ConfigPage(existingConfig: _selectedServerConfig!, onSave: _loadConfigs),
                    ),
                  );
                },
                onOpenDrawer: onOpenDrawer,
              )
            : Stack(
                children: [
                  Scaffold(
                    appBar: onOpenDrawer != null
                        ? AppBar(
                            title: Text(context.loc("s3_manager")),
                            centerTitle: true,
                            leading: IconButton(icon: const Icon(Icons.menu), onPressed: onOpenDrawer),
                            elevation: 0,
                            scrolledUnderElevation: 0,
                            actions: [
                              IconButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) =>
                                          S3ConfigPage(onSave: _loadConfigs),
                                    ),
                                  );
                                },
                                icon: Icon(Icons.add),
                              ),
                            ],
                          )
                        : null,
                    body: _serverConfigs.isEmpty ? _buildEmptyState(context) : _buildServerPicker(context),
                  ),
                  ValueListenableBuilder<UploadManager?>(
                    valueListenable: _imageBedUploadManagerNotifier,
                    builder: (context, manager, child) {
                      if (manager == null || manager.queue.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return UploadQueueUI(uploadManager: manager);
                    },
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return AppComponents.emptyState(
      icon: Icons.cloud_off_outlined,
      title: context.loc('no_server_selected'),
      subtitle: context.loc('select_server_to_start'),
      onAction: () {
        Navigator.push(
          context,
          PageRouteBuilder(pageBuilder: (context, animation, secondaryAnimation) => S3ConfigPage(onSave: _loadConfigs)),
        );
      },
      actionText: context.loc('add_new_server'),
    );
  }

  Widget _buildServerPicker(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageBedModule(context),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.all(10),
            child: Text(
              context.loc('select_server_to_start'),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _serverConfigs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final server = _serverConfigs[index];
                return AppComponents.card(
                  onTap: () {
                    setState(() {
                      _selectedServerConfig = server;
                    });
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.cloud_outlined, color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              server.name,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              server.bucket,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageBedModule(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = _isImageBedDragging
        ? theme.colorScheme.primary
        : theme.colorScheme.outline.withValues(alpha: 0.35);
    final backgroundColor = _isImageBedDragging
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

    final hintColor = theme.colorScheme.onSurface.withValues(alpha: 0.7);
    Widget uploadArea = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _pickAndUploadFiles,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(12)),
        child: CustomPaint(
          foregroundPainter: _DashedBorderPainter(
            color: borderColor,
            radius: 12,
            dashWidth: 6,
            dashSpace: 4,
            strokeWidth: 1,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Icon(Icons.cloud_upload_outlined, size: 28, color: hintColor),
              const SizedBox(height: 8),
              Text(
                context.loc('image_bed_upload_hint'),
                style: theme.textTheme.bodyMedium?.copyWith(color: hintColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (Platform.isDesktop) {
      uploadArea = DropTarget(
        onDragEntered: (details) {
          setState(() {
            _isImageBedDragging = true;
          });
        },
        onDragExited: (details) {
          setState(() {
            _isImageBedDragging = false;
          });
        },
        onDragDone: (details) async {
          setState(() {
            _isImageBedDragging = false;
          });
          final paths = details.files.map((file) => file.path).whereType<String>().toList();
          if (paths.isEmpty) return;
          await onMenuBarFilesDropped(paths);
        },
        child: uploadArea,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 10),
          child: Text(context.loc('image_bed'), style: theme.textTheme.bodyMedium?.copyWith(color: hintColor)),
        ),
        SizedBox(width: double.infinity, child: uploadArea),
      ],
    );
  }

  Future<void> _pickAndUploadFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;
    final paths = result.files.map((file) => file.path).whereType<String>().toList();
    if (paths.isEmpty) return;
    await onMenuBarFilesDropped(paths);
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.dashWidth,
    required this.dashSpace,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final length = dashWidth.clamp(0, metric.length - distance);
        canvas.drawPath(metric.extractPath(distance, distance + length), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return color != oldDelegate.color ||
        radius != oldDelegate.radius ||
        dashWidth != oldDelegate.dashWidth ||
        dashSpace != oldDelegate.dashSpace ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}
