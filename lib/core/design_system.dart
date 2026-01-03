import 'package:flutter/material.dart';

/// 设计系统 - 统一的主题管理和UI组件
class AppTheme {
  /// 深色主题
  static ThemeData darkTheme() {
    const primaryColor = Color(0xFF6366F1);
    const secondaryColor = Color(0xFF8B5CF6);
    const backgroundColor = Color(0xFF0F0F0F);
    const surfaceColor = Color(0xFF1A1A1A);
    const cardColor = Color(0xFF242424);

    return ThemeData(
      fontFamily: 'AlibabaPuHuiTi',
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      canvasColor: backgroundColor,
      cardColor: cardColor,

      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFFE4E4E7),
      ),

      // AppBar 主题
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: Color(0xFFE4E4E7), fontSize: AppFontSizes.xxl, fontWeight: FontWeight.w600),
        iconTheme: IconThemeData(color: Color(0xFFA1A1AA)),
      ),

      // Text 主题
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: AppFontSizes.display, fontWeight: FontWeight.bold, color: Color(0xFFE4E4E7)),
        displayMedium: TextStyle(fontSize: AppFontSizes.xxxl, fontWeight: FontWeight.bold, color: Color(0xFFE4E4E7)),
        displaySmall: TextStyle(fontSize: AppFontSizes.xxl, fontWeight: FontWeight.bold, color: Color(0xFFE4E4E7)),
        headlineMedium: TextStyle(fontSize: AppFontSizes.xl, fontWeight: FontWeight.w600, color: Color(0xFFE4E4E7)),
        headlineSmall: TextStyle(fontSize: AppFontSizes.lg, fontWeight: FontWeight.w600, color: Color(0xFFE4E4E7)),
        titleLarge: TextStyle(fontSize: AppFontSizes.xl, fontWeight: FontWeight.w600, color: Color(0xFFE4E4E7)),
        titleMedium: TextStyle(fontSize: AppFontSizes.lg, fontWeight: FontWeight.w500, color: Color(0xFFE4E4E7)),
        titleSmall: TextStyle(fontSize: AppFontSizes.md, fontWeight: FontWeight.w500, color: Color(0xFFE4E4E7)),
        bodyLarge: TextStyle(fontSize: AppFontSizes.lg, color: Color(0xFFE4E4E7)),
        bodyMedium: TextStyle(fontSize: AppFontSizes.md, color: Color(0xFFA1A1AA)),
        bodySmall: TextStyle(fontSize: AppFontSizes.sm, color: Color(0xFF71717A)),
        labelLarge: TextStyle(fontSize: AppFontSizes.md, fontWeight: FontWeight.w500, color: Color(0xFFE4E4E7)),
        labelMedium: TextStyle(fontSize: AppFontSizes.sm, fontWeight: FontWeight.w500, color: Color(0xFFE4E4E7)),
        labelSmall: TextStyle(fontSize: AppFontSizes.xs, fontWeight: FontWeight.w500, color: Color(0xFFE4E4E7)),
      ),

      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3F3F46)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3F3F46)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFFA1A1AA)),
        hintStyle: const TextStyle(color: Color(0xFF71717A)),
      ),

      // 按钮主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: AppFontSizes.md, fontWeight: FontWeight.w500),
        ),
      ),

      // 文本按钮主题
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: AppFontSizes.md, fontWeight: FontWeight.w500),
        ),
      ),

      // 卡片主题
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF3F3F46), width: 1),
        ),
      ),

      // 分割线主题
      dividerTheme: const DividerThemeData(color: Color(0xFF3F3F46), thickness: 1),

      // 图标主题
      iconTheme: const IconThemeData(color: Color(0xFFA1A1AA), size: 20),

      // 对话框主题
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // 下拉菜单主题
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 8,
      ),
    );
  }

  /// 浅色主题
  static ThemeData lightTheme() {
    const primaryColor = Color(0xFF5B5BFF);
    const secondaryColor = Color(0xFF8B5CF6);
    const backgroundColor = Color(0xFFF8F9FC);
    const surfaceColor = Colors.white;
    const cardColor = Colors.white;

    return ThemeData(
      fontFamily: 'AlibabaPuHuiTi',
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      canvasColor: backgroundColor,
      cardColor: cardColor,

      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF1F2937),
      ),

      // AppBar 主题
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: Color(0xFF1F2937), fontSize: AppFontSizes.xxl, fontWeight: FontWeight.w600),
        iconTheme: IconThemeData(color: Color(0xFF6B7280)),
      ),

      // Text 主题
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: AppFontSizes.display, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
        displayMedium: TextStyle(fontSize: AppFontSizes.xxxl, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
        displaySmall: TextStyle(fontSize: AppFontSizes.xxl, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
        headlineMedium: TextStyle(fontSize: AppFontSizes.xl, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
        headlineSmall: TextStyle(fontSize: AppFontSizes.lg, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
        titleLarge: TextStyle(fontSize: AppFontSizes.xl, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
        titleMedium: TextStyle(fontSize: AppFontSizes.lg, fontWeight: FontWeight.w500, color: Color(0xFF1F2937)),
        titleSmall: TextStyle(fontSize: AppFontSizes.md, fontWeight: FontWeight.w500, color: Color(0xFF1F2937)),
        bodyLarge: TextStyle(fontSize: AppFontSizes.lg, color: Color(0xFF1F2937)),
        bodyMedium: TextStyle(fontSize: AppFontSizes.md, color: Color(0xFF6B7280)),
        bodySmall: TextStyle(fontSize: AppFontSizes.sm, color: Color(0xFF9CA3AF)),
        labelLarge: TextStyle(fontSize: AppFontSizes.md, fontWeight: FontWeight.w500, color: Color(0xFF1F2937)),
        labelMedium: TextStyle(fontSize: AppFontSizes.sm, fontWeight: FontWeight.w500, color: Color(0xFF1F2937)),
        labelSmall: TextStyle(fontSize: AppFontSizes.xs, fontWeight: FontWeight.w500, color: Color(0xFF1F2937)),
      ),

      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF6B7280)),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      ),

      // 按钮主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: AppFontSizes.md, fontWeight: FontWeight.w500),
        ),
      ),

      // 文本按钮主题
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: AppFontSizes.md, fontWeight: FontWeight.w500),
        ),
      ),

      // 卡片主题
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),

      // 分割线主题
      dividerTheme: const DividerThemeData(color: Color(0xFFE5E7EB), thickness: 1),

      // 图标主题
      iconTheme: const IconThemeData(color: Color(0xFF6B7280), size: 20),

      // 对话框主题
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // 下拉菜单主题
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 8,
      ),
    );
  }
}

/// 通用UI组件
class AppComponents {
  /// 卡片组件
  static Widget card({
    required Widget child,
    EdgeInsetsGeometry? padding,
    Color? color,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color, borderRadius: borderRadius ?? BorderRadius.circular(12)),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, borderRadius: borderRadius ?? BorderRadius.circular(12), child: card),
      );
    }

    return card;
  }

  /// 按钮组件
  static Widget primaryButton({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
    bool loading = false,
  }) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading) ...[
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
          ],
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: AppFontSizes.sm),
            ),
          ),
        ],
      ),
    );
  }

  /// 次要按钮组件
  static Widget secondaryButton({required String text, required VoidCallback onPressed, IconData? icon}) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  /// 加载状态组件
  static Widget loadingWidget({String? message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(strokeWidth: 3),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(fontSize: AppFontSizes.md)),
          ],
        ],
      ),
    );
  }

  /// 空状态组件
  static Widget emptyState({
    required String title,
    String? subtitle,
    IconData? icon,
    VoidCallback? onAction,
    String? actionText,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon ?? Icons.inbox_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: AppFontSizes.xxl, fontWeight: FontWeight.w500),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: AppFontSizes.md, color: Colors.grey.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
          ],
          if (onAction != null && actionText != null) ...[
            const SizedBox(height: 24),
            primaryButton(text: actionText, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// 间距常量
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// 圆角常量
class AppRadius {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 24;
}

/// 动画常量
class AppAnimation {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);

  static Curve get curve => Curves.easeInOutCubic;
}

/// 字体大小常量
class AppFontSizes {
  static const double xs = 12.0;
  static const double sm = 14.0;
  static const double md = 16.0;
  static const double lg = 18.0;
  static const double xl = 20.0;
  static const double xxl = 22.0;
  static const double xxxl = 24.0;
  static const double display = 32.0;
}
