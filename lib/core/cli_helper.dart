import 'dart:io';

import 'package:path/path.dart' as p;

/// Helper for locating and installing the bundled CLI tool.
class CliHelper {
  /// Returns the real user home directory on macOS.
  ///
  /// Sandboxed apps may see HOME as a container path like:
  /// /Users/username/Library/Containers/app-bundle-id/Data
  ///
  /// For CLI installation we want the actual user home, e.g. /Users/username.
  static String get userHomePath {
    final home = Platform.environment['HOME'] ?? '';

    if (Platform.isMacOS && home.contains('/Library/Containers/')) {
      final user =
          Platform.environment['USER'] ?? Platform.environment['LOGNAME'] ?? '';
      if (user.isNotEmpty) {
        final realHome = p.join('/Users', user);
        if (Directory(realHome).existsSync()) {
          return realHome;
        }
      }
    }

    return home;
  }

  /// Install to ~/.local/bin (user-writable, no admin needed).
  static String get defaultInstallPath {
    return p.join(userHomePath, '.local', 'bin', 'ploys3');
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

  /// Whether a CLI entry already exists in ~/.local/bin.
  static bool get hasLocalCliInstall =>
      FileSystemEntity.typeSync(defaultInstallPath) !=
      FileSystemEntityType.notFound;

  /// The path users should use in the terminal.
  ///
  /// - If ~/.local/bin/ploys3 already exists, prefer that path.
  /// - Otherwise show the bundled app path.
  static String get effectiveCliPath =>
      hasLocalCliInstall ? defaultInstallPath : bundledCliPath;

  /// Whether the CLI is available for terminal use.
  static bool get isCliInstalled => hasLocalCliInstall;

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
      final existingType = FileSystemEntity.typeSync(target);
      if (existingType == FileSystemEntityType.link) {
        Link(target).deleteSync();
      } else if (existingType == FileSystemEntityType.file) {
        File(target).deleteSync();
      }

      // Create symlink
      Link(target).createSync(cliPath);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Uninstall the CLI entry from ~/.local/bin.
  static Future<String?> uninstallCli() async {
    try {
      final target = defaultInstallPath;
      final existingType = FileSystemEntity.typeSync(target);
      if (existingType == FileSystemEntityType.link) {
        Link(target).deleteSync();
      } else if (existingType == FileSystemEntityType.file) {
        File(target).deleteSync();
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
