import 'package:flutter/material.dart';
import 'language_manager.dart';

/// 本地化扩展
extension Localization on BuildContext {
  String loc(String key, [List<String>? args]) {
    String text = LanguageManager.instance.getLocalized(key);

    if (args != null) {
      for (var i = 0; i < args.length; i++) {
        text = text.replaceFirst('%s', args[i]);
      }
    }

    return text;
  }
}