import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ploys3/core/platform.dart';
import 'package:ploys3/main.dart';

/// 菜单栏设置管理器
/// 
/// 用于管理菜单栏图标和快捷上传功能的显示状态
class MenuBarSettingsManager extends ChangeNotifier {
  static MenuBarSettingsManager? _instance;
  static MenuBarSettingsManager get instance => _instance ??= MenuBarSettingsManager._internal();

  MenuBarSettingsManager._internal();

  static const String _menuBarEnabledKey = 'menubar_enabled';
  static const String _quickUploadEnabledKey = 'menubar_quick_upload_enabled';

  bool _initialized = false;
  bool _menuBarEnabled = true;  // 菜单栏图标是否显示，默认启用
  bool _quickUploadEnabled = true;  // 快捷上传功能是否启用，默认启用

  /// 菜单栏图标是否显示
  bool get menuBarEnabled => _menuBarEnabled;
  
  /// 快捷上传功能是否启用
  bool get quickUploadEnabled => _quickUploadEnabled;

  /// 初始化设置管理器
  /// 
  /// 应在应用启动时调用
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await _loadSettings();
    await _applyState();
  }

  /// 设置菜单栏图标是否显示
  Future<void> setMenuBarEnabled(bool enabled) async {
    _menuBarEnabled = enabled;
    await _saveSetting(_menuBarEnabledKey, enabled);
    await _applyMenuBarState();
    notifyListeners();
  }
  
  /// 设置快捷上传功能是否启用
  Future<void> setQuickUploadEnabled(bool enabled) async {
    _quickUploadEnabled = enabled;
    await _saveSetting(_quickUploadEnabledKey, enabled);
    await _applyQuickUploadState();
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _menuBarEnabled = prefs.getBool(_menuBarEnabledKey) ?? true;
    _quickUploadEnabled = prefs.getBool(_quickUploadEnabledKey) ?? true;
    notifyListeners();
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _applyState() async {
    await _applyMenuBarState();
    await _applyQuickUploadState();
  }
  
  Future<void> _applyMenuBarState() async {
    if (!Platform.isMacOS) return;
    
    try {
      await MenuBarIconController.setMenuBarEnabled(_menuBarEnabled);
    } catch (error) {
      debugPrint('Failed to apply menu bar state: $error');
    }
  }
  
  Future<void> _applyQuickUploadState() async {
    if (!Platform.isMacOS) return;
    
    try {
      await MenuBarIconController.setQuickUploadEnabled(_quickUploadEnabled);
    } catch (error) {
      debugPrint('Failed to apply quick upload state: $error');
    }
  }
}
