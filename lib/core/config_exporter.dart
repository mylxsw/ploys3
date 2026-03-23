import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Exports server configs and image bed settings to a JSON file
/// so that the CLI tool can read them.
class ConfigExporter {
  static const String _configDir = '.config/ploys3';
  static const String _configFile = 'config.json';

  /// Export current configs to ~/.config/ploys3/config.json
  static Future<void> export() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load server configs
      final serverConfigStrings = prefs.getStringList('server_configs') ?? [];
      final servers = serverConfigStrings
          .map((s) => jsonDecode(s) as Map<String, dynamic>)
          .toList();

      // Load image bed config
      final imageBedServerId = prefs.getString('image_bed_server_id') ?? '';
      final imageBedUploadDir = prefs.getString('image_bed_upload_dir') ?? '';
      final imageBedNamingRule =
          prefs.getString('image_bed_naming_rule') ?? 'original';

      // Build export JSON
      final exportData = <String, dynamic>{
        'servers': servers,
      };

      if (imageBedServerId.isNotEmpty) {
        exportData['image_bed'] = {
          'server_id': imageBedServerId,
          'upload_dir': imageBedUploadDir,
          'naming_rule': imageBedNamingRule,
        };
      }

      // Write to file
      final home = Platform.environment['HOME'] ?? '';
      if (home.isEmpty) return;

      final dir = Directory(p.join(home, _configDir));
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final file = File(p.join(dir.path, _configFile));
      final encoder = const JsonEncoder.withIndent('  ');
      file.writeAsStringSync(encoder.convert(exportData));
    } catch (_) {
      // Silently ignore export failures - CLI config is a convenience feature
    }
  }
}
