import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ploys3/core/language_manager.dart';
import 'package:ploys3/core/platform.dart';
import 'package:ploys3/core/upload_manager.dart';

/// Method channel for macOS menu bar communication.
const MethodChannel _menuBarChannel = MethodChannel('com.ploys3/menubar');

/// 菜单栏图标状态枚举
enum MenuBarIconState {
  normal, // 默认状态
  ready, // 准备上传状态（用户正在拖拽文件）
  hover, // 悬停状态（文件拖到图标上方）
  uploading, // 上传中状态
}

/// 菜单栏图标控制器 - 用于从 Flutter 端控制菜单栏图标状态
class MenuBarIconController {
  /// 设置菜单栏图标状态
  ///
  /// 当设置为非 normal 状态时，原生端的自动拖拽检测会被暂停，
  /// 直到状态被设置回 normal。
  static Future<void> setIconState(MenuBarIconState state) async {
    if (!Platform.isMacOS) return;

    try {
      await _menuBarChannel.invokeMethod('setIconState', state.name);
    } catch (e) {
      debugPrint('Failed to set menu bar icon state: $e');
    }
  }

  /// 获取当前菜单栏图标状态
  static Future<MenuBarIconState> getIconState() async {
    if (!Platform.isMacOS) return MenuBarIconState.normal;

    try {
      final String? stateString = await _menuBarChannel.invokeMethod('getIconState');
      return MenuBarIconState.values.firstWhere(
        (s) => s.name == stateString,
        orElse: () => MenuBarIconState.normal,
      );
    } catch (e) {
      debugPrint('Failed to get menu bar icon state: $e');
      return MenuBarIconState.normal;
    }
  }

  /// 设置为上传中状态
  static Future<void> setUploading() => setIconState(MenuBarIconState.uploading);

  /// 重置为默认状态
  static Future<void> resetToNormal() => setIconState(MenuBarIconState.normal);

  /// 设置菜单栏功能是否启用
  ///
  /// 当设置为 false 时，菜单栏图标和拖拽上传窗口都会被隐藏。
  /// 当设置为 true 时，菜单栏图标和拖拽上传功能会被恢复。
  ///
  /// [enabled] - true 启用菜单栏功能，false 禁用菜单栏功能
  static Future<void> setMenuBarEnabled(bool enabled) async {
    if (!Platform.isMacOS) return;

    try {
      await _menuBarChannel.invokeMethod('setMenuBarEnabled', enabled);
    } catch (e) {
      debugPrint('Failed to set menu bar enabled: $e');
    }
  }

  /// 获取菜单栏功能是否启用
  static Future<bool> isMenuBarEnabled() async {
    if (!Platform.isMacOS) return false;

    try {
      final bool? enabled = await _menuBarChannel.invokeMethod('getMenuBarEnabled');
      return enabled ?? true;
    } catch (e) {
      debugPrint('Failed to get menu bar enabled: $e');
      return true;
    }
  }

  /// 显示菜单栏图标
  static Future<void> show() => setMenuBarEnabled(true);

  /// 隐藏菜单栏图标
  static Future<void> hide() => setMenuBarEnabled(false);

  /// 设置快捷上传功能是否启用
  ///
  /// 当设置为 false 时，拖拽文件时不会显示上传窗口。
  /// 当设置为 true 时，拖拽文件时会显示上传窗口。
  /// 注意：只有在菜单栏图标启用时，此设置才生效。
  ///
  /// [enabled] - true 启用快捷上传，false 禁用快捷上传
  static Future<void> setQuickUploadEnabled(bool enabled) async {
    if (!Platform.isMacOS) return;

    try {
      await _menuBarChannel.invokeMethod('setQuickUploadEnabled', enabled);
    } catch (e) {
      debugPrint('Failed to set quick upload enabled: $e');
    }
  }

  /// 获取快捷上传功能是否启用
  static Future<bool> isQuickUploadEnabled() async {
    if (!Platform.isMacOS) return false;

    try {
      final bool? enabled = await _menuBarChannel.invokeMethod('getQuickUploadEnabled');
      return enabled ?? true;
    } catch (e) {
      debugPrint('Failed to get quick upload enabled: $e');
      return true;
    }
  }

  static Future<void> showNotification({required String title, required String body}) async {
    if (!Platform.isMacOS) return;

    try {
      await _menuBarChannel.invokeMethod('showNotification', {'title': title, 'body': body});
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }
}

void setupMenuBarChannel({
  required Future<void> Function(List<String>) onFilesDropped,
  required VoidCallback onOpenSettings,
}) {
  _menuBarChannel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'onFilesDropped':
        final List<String> filePaths = (call.arguments as List).cast<String>();
        await onFilesDropped(filePaths);
        break;
      case 'openSettings':
        onOpenSettings();
        break;
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'Method ${call.method} not implemented',
        );
    }
  });
}

class MenuBarUploadCoordinator {
  MenuBarUploadCoordinator._();

  static final MenuBarUploadCoordinator instance = MenuBarUploadCoordinator._();

  UploadManager? _uploadManager;
  String _targetPrefix = '';
  final Set<String> _menuBarUploadPaths = {};
  final Map<String, UploadStatus> _statusCache = {};
  bool _isUploading = false;

  void registerUploadContext({required UploadManager? uploadManager, required String targetPrefix}) {
    final isSameManager = _uploadManager == uploadManager;
    if (isSameManager && _targetPrefix == targetPrefix) {
      return;
    }

    _targetPrefix = targetPrefix;
    if (isSameManager) {
      return;
    }

    _uploadManager?.removeListener(_handleUploadUpdate);
    _uploadManager = uploadManager;
    _statusCache.clear();
    _menuBarUploadPaths.clear();

    if (_uploadManager != null) {
      for (final item in _uploadManager!.queue) {
        _statusCache[item.id] = item.status;
      }
      _uploadManager!.addListener(_handleUploadUpdate);
      _handleUploadUpdate();
    }
  }

  void unregisterUploadContext(UploadManager? uploadManager) {
    if (_uploadManager != uploadManager) {
      return;
    }

    _uploadManager?.removeListener(_handleUploadUpdate);
    _uploadManager = null;
    _targetPrefix = '';
    _statusCache.clear();
    _menuBarUploadPaths.clear();
    _setUploadingState(false);
  }

  Future<void> handleFilesDropped(List<String> filePaths) async {
    if (filePaths.isEmpty) {
      return;
    }

    if (_uploadManager == null) {
      final title = LanguageManager.instance.getLocalized('upload');
      final body = LanguageManager.instance.getLocalized('menu_bar_no_target');
      await MenuBarIconController.showNotification(title: title, body: body);
      return;
    }

    _menuBarUploadPaths.addAll(filePaths);
    _uploadManager!.addToQueue(filePaths, _targetPrefix);
  }

  void _handleUploadUpdate() {
    final manager = _uploadManager;
    if (manager == null) return;

    final queue = manager.queue;
    final queueIds = queue.map((item) => item.id).toSet();
    _statusCache.removeWhere((id, _) => !queueIds.contains(id));
    _menuBarUploadPaths.removeWhere((path) => queue.every((item) => item.filePath != path));

    for (final item in queue) {
      final previousStatus = _statusCache[item.id];
      if (previousStatus != item.status) {
        _statusCache[item.id] = item.status;

        if (_menuBarUploadPaths.contains(item.filePath)) {
          _handleMenuBarStatusChange(item);
        }
      }
    }

    final hasActiveMenuBarUploads = queue.any(
      (item) =>
          _menuBarUploadPaths.contains(item.filePath) &&
          (item.status == UploadStatus.pending || item.status == UploadStatus.uploading),
    );
    _setUploadingState(hasActiveMenuBarUploads);
  }

  void _setUploadingState(bool uploading) {
    if (_isUploading == uploading) return;
    _isUploading = uploading;
    if (uploading) {
      MenuBarIconController.setUploading();
    } else {
      MenuBarIconController.resetToNormal();
    }
  }

  Future<void> _handleMenuBarStatusChange(UploadItem item) async {
    if (item.status == UploadStatus.success) {
      final title = LanguageManager.instance.getLocalized('upload');
      final body = LanguageManager.instance.getLocalized('upload_success').replaceFirst('%s', item.fileName);
      await MenuBarIconController.showNotification(title: title, body: body);
      if (item.resultUrl != null && item.resultUrl!.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: item.resultUrl!));
      }
      _menuBarUploadPaths.remove(item.filePath);
    } else if (item.status == UploadStatus.failed) {
      final title = LanguageManager.instance.getLocalized('upload');
      final errorText = item.errorMessage?.isNotEmpty == true
          ? '${item.fileName} (${item.errorMessage})'
          : item.fileName;
      final body = LanguageManager.instance.getLocalized('upload_failed').replaceFirst('%s', errorText);
      await MenuBarIconController.showNotification(title: title, body: body);
      _menuBarUploadPaths.remove(item.filePath);
    }
  }
}
