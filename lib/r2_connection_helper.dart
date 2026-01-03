import 'package:minio/minio.dart' as minio;
import 'package:ploys3/models/s3_server_config.dart';
import 'package:ploys3/core/language_manager.dart';

class R2ConnectionHelper {
  /// Creates a properly configured MinIO client for Cloudflare R2
  static minio.Minio createR2Client(S3ServerConfig config) {
    final uri = Uri.parse(config.address);

    // R2 specific adjustments
    var endPoint = uri.host;
    var port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    var useSSL = uri.scheme == 'https';

    // For R2, we might need to use path-style addressing
    // and ensure the endpoint is correct

    print('R2 Connection Helper:');
    print('  Original URL: ${config.address}');
    print('  Endpoint: $endPoint');
    print('  Port: $port');
    print('  SSL: $useSSL');
    print('  Region: ${config.region ?? 'auto'}');
    print('  Bucket: ${config.bucket}');

    // Try different configurations for R2

    // Configuration 1: Standard setup
    try {
      return minio.Minio(
        endPoint: endPoint,
        port: port,
        accessKey: config.accessKeyId,
        secretKey: config.secretAccessKey,
        useSSL: useSSL,
        region: config.region ?? 'auto',
      );
    } catch (e) {
      print('Standard config failed: $e');

      // Configuration 2: Try with us-east-1 region
      try {
        return minio.Minio(
          endPoint: endPoint,
          port: port,
          accessKey: config.accessKeyId,
          secretKey: config.secretAccessKey,
          useSSL: useSSL,
          region: 'us-east-1',
        );
      } catch (e2) {
        print('us-east-1 config failed: $e2');

        // Re-throw the original error
        throw e;
      }
    }
  }

  /// Tests different R2 endpoint formats
  static Map<String, String> getR2EndpointFormats(
    String accountId,
    String bucketName,
  ) {
    return {
      'Format 1': 'https://$accountId.r2.cloudflarestorage.com',
      'Format 2': 'https://$accountId.r2.cloudflarestorage.com/$bucketName',
      'Format 3': 'https://$bucketName.$accountId.r2.cloudflarestorage.com',
      'Format 4': 'https://r2.cloudflarestorage.com/$accountId/$bucketName',
    };
  }

  /// Validates R2 configuration
  static List<String> validateR2Config(S3ServerConfig config) {
    final issues = <String>[];
    final lang = LanguageManager.instance;

    if (!config.address.contains('r2.cloudflarestorage.com')) {
      issues.add(lang.getLocalized('r2_validation_endpoint'));
    }

    if (config.accessKeyId.isEmpty) {
      issues.add(lang.getLocalized('r2_validation_ak'));
    }

    if (config.secretAccessKey.isEmpty) {
      issues.add(lang.getLocalized('r2_validation_sk'));
    }

    if (config.bucket.isEmpty) {
      issues.add(lang.getLocalized('r2_validation_bucket'));
    }

    // Check for common R2 URL format issues
    final uri = Uri.parse(config.address);
    if (!uri.hasScheme) {
      issues.add(lang.getLocalized('r2_validation_scheme'));
    }

    return issues;
  }
}
