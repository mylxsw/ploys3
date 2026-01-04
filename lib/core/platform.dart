import 'package:flutter/foundation.dart';

class Platform {
  /// Checks if the current platform is a mobile platform (iOS or Android).
  static bool get isMobile {
    return const [TargetPlatform.iOS, TargetPlatform.android].contains(defaultTargetPlatform);
  }

  static bool get isDesktop {
    return const [TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux].contains(defaultTargetPlatform);
  }

  /// Checks if the current platform is a web platform.
  static bool get isWeb {
    return kIsWeb;
  }
}
