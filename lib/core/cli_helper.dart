import 'dart:io';

import 'package:path/path.dart' as p;

/// Helper for locating and installing the bundled CLI tool.
class CliHelper {
  /// Install to ~/.local/bin (user-writable, no admin needed).
  static String get defaultInstallPath {
    final home = Platform.environment['HOME'] ?? '';
    return p.join(home, '.local', 'bin', 'ploys3');
  }

  /// Returns the path to the CLI executable inside the app bundle.
  ///
  /// Layout: PloyS3.app/Contents/MacOS/PloyS3  (Flutter executable)
  ///         PloyS3.app/Contents/Resources/bin/ploys3  (CLI)
  static String get bundledCliPath {
    final execPath = Platform.resolvedExecutable;
    // execPath = .../PloyS3.app/Contents/MacOS/PloyS3
    final contentsDir = p.dirname(p.dirname(execPath));
    return p.join(contentsDir, 'Resources', 'bin', 'ploys3');
  }

  /// Whether the CLI binary exists in the app bundle.
  static bool get isCliAvailable => File(bundledCliPath).existsSync();

  /// Whether the CLI is installed at the default path.
  static bool get isCliInstalled {
    try {
      final link = Link(defaultInstallPath);
      if (!link.existsSync()) return false;
      final target = link.targetSync();
      return target == bundledCliPath;
    } catch (_) {
      return false;
    }
  }

  /// Install the CLI by creating a symlink at ~/.local/bin/ploys3.
  /// Returns null on success, or an error message on failure.
  static Future<String?> installCli() async {
    final cliPath = bundledCliPath;
    final target = defaultInstallPath;

    if (!File(cliPath).existsSync()) {
      return 'CLI binary not found in app bundle.';
    }

    try {
      // Ensure ~/.local/bin exists
      final dir = Directory(p.dirname(target));
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      // Remove existing file/link if present
      final existing = Link(target);
      if (existing.existsSync()) {
        existing.deleteSync();
      } else if (File(target).existsSync()) {
        File(target).deleteSync();
      }

      // Create symlink
      Link(target).createSync(cliPath);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Uninstall the CLI symlink.
  static Future<String?> uninstallCli() async {
    try {
      final link = Link(defaultInstallPath);
      if (link.existsSync()) {
        link.deleteSync();
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// The sudo command users can run to install to /usr/local/bin instead.
  static String get manualInstallCommand =>
      'sudo ln -sf "$bundledCliPath" /usr/local/bin/ploys3';
}
