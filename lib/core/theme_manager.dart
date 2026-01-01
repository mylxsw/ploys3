import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'design_system.dart';

/// 主题模式枚举
enum AppThemeMode { light, dark, system }

/// 主题管理器
class ThemeManager extends ChangeNotifier {
  static ThemeManager? _instance;
  static ThemeManager get instance => _instance ??= ThemeManager._internal();

  ThemeManager._internal() {
    _loadTheme();
  }

  AppThemeMode _themeMode = AppThemeMode.system;
  bool _isDark = false;

  AppThemeMode get themeMode => _themeMode;
  bool get isDark => _isDark;

  /// 获取当前主题
  ThemeData get currentTheme {
    switch (_themeMode) {
      case AppThemeMode.light:
        return AppTheme.lightTheme();
      case AppThemeMode.dark:
        return AppTheme.darkTheme();
      case AppThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark
            ? AppTheme.darkTheme()
            : AppTheme.lightTheme();
    }
  }

  /// 获取指定主题
  ThemeData getTheme(BuildContext context) {
    if (_themeMode == AppThemeMode.system) {
      return MediaQuery.of(context).platformBrightness == Brightness.dark
          ? AppTheme.darkTheme()
          : AppTheme.lightTheme();
    }
    return _isDark ? AppTheme.darkTheme() : AppTheme.lightTheme();
  }

  /// 刷新主题（用于系统主题改变时）
  void refreshTheme() {
    if (_themeMode == AppThemeMode.system) {
      notifyListeners();
    }
  }

  /// 设置主题模式
  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;

    if (mode != AppThemeMode.system) {
      _isDark = mode == AppThemeMode.dark;
    }

    await _saveTheme();
    notifyListeners();
  }

  /// 切换深色模式
  Future<void> toggleDarkMode() async {
    if (_themeMode == AppThemeMode.system) {
      _themeMode = AppThemeMode.light;
      _isDark = false;
    } else {
      _isDark = !_isDark;
      _themeMode = _isDark ? AppThemeMode.dark : AppThemeMode.light;
    }

    await _saveTheme();
    notifyListeners();
  }

  /// 从SharedPreferences加载主题设置
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt('app_theme_mode') ?? 2; // 默认系统主题
    _themeMode = AppThemeMode.values[themeModeIndex];

    if (_themeMode != AppThemeMode.system) {
      _isDark = _themeMode == AppThemeMode.dark;
    }

    notifyListeners();
  }

  /// 保存主题设置到SharedPreferences
  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_theme_mode', _themeMode.index);
  }
}

/// 主题提供者Widget
class ThemeProvider extends StatefulWidget {
  final Widget child;

  const ThemeProvider({super.key, required this.child});

  @override
  State<ThemeProvider> createState() => _ThemeProviderState();
}

class _ThemeProviderState extends State<ThemeProvider>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    // 系统主题改变时，如果是跟随系统模式，则通知更新
    ThemeManager.instance.refreshTheme();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, child) {
        return Theme(
          data: ThemeManager.instance.getTheme(context),
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}
