import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:minio/minio.dart';
import 'package:path/path.dart' as p;

import 'config.dart';

/// Creates a Minio client from server config
Minio createMinioClient(ServerConfig config) {
  final uri = Uri.parse(config.address);
  final isR2 = uri.host.contains('r2.cloudflarestorage.com');

  final endPoint = uri.host;
  final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
  final useSSL = uri.scheme == 'https';
  final region = isR2
      ? (config.region ?? 'auto')
      : (config.region ?? 'us-east-1');

  return Minio(
    endPoint: endPoint,
    port: port,
    accessKey: config.accessKeyId,
    secretKey: config.secretAccessKey,
    useSSL: useSSL,
    region: region,
  );
}

/// Build the file URL after upload
String buildFileUrl(ServerConfig config, String key) {
  if (config.cdnUrl != null && config.cdnUrl!.isNotEmpty) {
    var url = config.cdnUrl!;
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return '$url/$key';
  }
  var baseUrl = config.address;
  if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
  return '$baseUrl/$key';
}

/// Generate a random filename based on naming rule
String resolveFileName(String filePath, String namingRule) {
  final originalName = p.basename(filePath);
  if (namingRule == 'original') return originalName;

  final dotIndex = originalName.lastIndexOf('.');
  final extension = dotIndex > 0 ? originalName.substring(dotIndex) : '';
  final now = DateTime.now();
  final timestamp =
      '${now.year}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}-'
      '${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}';
  final rand = math.Random();
  final uuid =
      '${rand.nextInt(0x7FFFFFFF).toRadixString(36)}-'
      '${rand.nextInt(0x7FFFFFFF).toRadixString(36)}';
  return '$timestamp-$uuid$extension';
}

/// Normalize upload prefix (ensure trailing slash)
String normalizePrefix(String prefix) {
  if (prefix.isEmpty) return '';
  return prefix.endsWith('/') ? prefix : '$prefix/';
}

/// Upload result
class UploadResult {
  final String filePath;
  final String key;
  final String url;
  final bool success;
  final String? error;

  UploadResult({
    required this.filePath,
    required this.key,
    required this.url,
    required this.success,
    this.error,
  });
}

/// Upload files to S3
Future<List<UploadResult>> uploadFiles({
  required ServerConfig server,
  required List<String> filePaths,
  required String prefix,
  required String namingRule,
  bool verbose = false,
}) async {
  final client = createMinioClient(server);
  final normalizedPrefix = normalizePrefix(prefix);
  final results = <UploadResult>[];

  for (final filePath in filePaths) {
    final file = File(filePath);
    if (!file.existsSync()) {
      results.add(UploadResult(
        filePath: filePath,
        key: '',
        url: '',
        success: false,
        error: 'File not found',
      ));
      continue;
    }

    final fileName = resolveFileName(filePath, namingRule);
    final key = normalizedPrefix.isEmpty ? fileName : '$normalizedPrefix$fileName';
    final url = buildFileUrl(server, key);

    if (verbose) {
      stderr.writeln('Uploading: ${p.basename(filePath)} → $key');
    }

    try {
      final stream = file.openRead().cast<Uint8List>();
      final size = await file.length();
      await client.putObject(server.bucket, key, stream, size: size);

      results.add(UploadResult(
        filePath: filePath,
        key: key,
        url: url,
        success: true,
      ));

      if (verbose) {
        stderr.writeln('  ✓ $url');
      }
    } catch (e) {
      results.add(UploadResult(
        filePath: filePath,
        key: key,
        url: url,
        success: false,
        error: e.toString(),
      ));

      if (verbose) {
        stderr.writeln('  ✗ $e');
      }
    }
  }

  return results;
}

/// Check if a file is an image
bool isImageFile(String filePath) {
  final ext = p.extension(filePath).toLowerCase().replaceFirst('.', '');
  const imageExts = {
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg',
    'tif', 'tiff', 'heic', 'heif', 'ico',
  };
  return imageExts.contains(ext);
}
