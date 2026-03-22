import 'package:flutter/services.dart';
import 'package:ploys3/core/platform.dart';

/// Helper for reading images from the system clipboard.
class ClipboardImageHelper {
  static const _channel = MethodChannel('com.ploys3/menubar');

  /// Reads an image from the system clipboard and saves it to a temporary file.
  /// Returns the temp file path, or null if no image is in the clipboard.
  /// Only supported on desktop platforms.
  static Future<String?> readImageTempFile() async {
    if (!Platform.isDesktop) return null;
    try {
      final result = await _channel.invokeMethod<String?>('readClipboardImage');
      return result;
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
