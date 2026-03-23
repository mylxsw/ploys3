import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Server configuration model (mirrors the Flutter app's S3ServerConfig)
class ServerConfig {
  final String id;
  final String name;
  final String serverType;
  final String address;
  final String bucket;
  final String accessKeyId;
  final String secretAccessKey;
  final String? region;
  final String? cdnUrl;
  final String localPath;
  final String host;
  final int port;
  final String username;
  final String password;
  final String privateKey;
  final String remotePath;

  ServerConfig({
    required this.id,
    required this.name,
    this.serverType = 's3',
    required this.address,
    required this.bucket,
    required this.accessKeyId,
    required this.secretAccessKey,
    this.region,
    this.cdnUrl,
    this.localPath = '',
    this.host = '',
    this.port = 0,
    this.username = '',
    this.password = '',
    this.privateKey = '',
    this.remotePath = '',
  });

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    return ServerConfig(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      serverType: json['serverType'] as String? ?? 's3',
      address: json['address'] as String? ?? '',
      bucket: json['bucket'] as String? ?? '',
      accessKeyId: json['accessKeyId'] as String? ?? '',
      secretAccessKey: json['secretAccessKey'] as String? ?? '',
      region: json['region'] as String?,
      cdnUrl: json['cdnUrl'] as String?,
      localPath: json['localPath'] as String? ?? '',
      host: json['host'] as String? ?? '',
      port: json['port'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      privateKey: json['privateKey'] as String? ?? '',
      remotePath: json['remotePath'] as String? ?? '',
    );
  }
}

/// Image bed configuration
class ImageBedConfig {
  final String serverId;
  final String uploadDir;
  final String namingRule; // 'original' or 'random'

  ImageBedConfig({
    required this.serverId,
    required this.uploadDir,
    required this.namingRule,
  });

  factory ImageBedConfig.fromJson(Map<String, dynamic> json) {
    return ImageBedConfig(
      serverId: json['server_id'] as String? ?? '',
      uploadDir: json['upload_dir'] as String? ?? '',
      namingRule: json['naming_rule'] as String? ?? 'original',
    );
  }
}

/// Full CLI configuration
class CliConfig {
  final List<ServerConfig> servers;
  final ImageBedConfig? imageBed;

  CliConfig({required this.servers, this.imageBed});

  factory CliConfig.fromJson(Map<String, dynamic> json) {
    final serversJson = json['servers'] as List<dynamic>? ?? [];
    final servers = serversJson
        .map((s) => ServerConfig.fromJson(s as Map<String, dynamic>))
        .toList();

    ImageBedConfig? imageBed;
    if (json['image_bed'] != null) {
      imageBed = ImageBedConfig.fromJson(
        json['image_bed'] as Map<String, dynamic>,
      );
    }

    return CliConfig(servers: servers, imageBed: imageBed);
  }

  /// Find a server by ID or name (case-insensitive partial match)
  ServerConfig? findServer(String query) {
    // Try exact ID match first
    for (final s in servers) {
      if (s.id == query) return s;
    }
    // Try exact name match
    for (final s in servers) {
      if (s.name.toLowerCase() == query.toLowerCase()) return s;
    }
    // Try partial name match
    final lowerQuery = query.toLowerCase();
    for (final s in servers) {
      if (s.name.toLowerCase().contains(lowerQuery)) return s;
    }
    return null;
  }

  /// Get the image bed server config
  ServerConfig? get imageBedServer {
    if (imageBed == null || imageBed!.serverId.isEmpty) return null;
    return findServer(imageBed!.serverId);
  }
}

/// macOS sandbox container bundle ID
const String _macBundleId = 'com.example.s3Ui';

/// All candidate config file paths, in priority order.
List<String> get configSearchPaths {
  final home = Platform.environment['HOME'] ?? '';
  return [
    // macOS sandbox container (where the sandboxed app actually writes)
    p.join(home, 'Library', 'Containers', _macBundleId, 'Data',
        '.config', 'ploys3', 'config.json'),
    // Standard path (non-sandboxed or Linux)
    p.join(home, '.config', 'ploys3', 'config.json'),
  ];
}

/// Find the first existing config file path.
String? get configFilePath {
  for (final path in configSearchPaths) {
    if (File(path).existsSync()) return path;
  }
  return null;
}

/// Load config from file
CliConfig loadConfig([String? path]) {
  final resolved = path ?? configFilePath;
  if (resolved == null) {
    throw FileSystemException(
      'Config file not found. Please open the PloyS3 app to generate it.\n'
      'Searched:\n${configSearchPaths.map((p) => '  - $p').join('\n')}',
    );
  }
  final file = File(resolved);
  final content = file.readAsStringSync();
  final json = jsonDecode(content) as Map<String, dynamic>;
  return CliConfig.fromJson(json);
}
