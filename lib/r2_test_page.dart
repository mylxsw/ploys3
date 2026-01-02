import 'package:flutter/material.dart';
import 'package:s3_ui/models/s3_server_config.dart';
import 'package:s3_ui/r2_connection_helper.dart';
import 'package:s3_ui/core/design_system.dart';
import 'package:s3_ui/core/localization.dart';

class R2TestPage extends StatefulWidget {
  final S3ServerConfig serverConfig;

  const R2TestPage({super.key, required this.serverConfig});

  @override
  State<R2TestPage> createState() => _R2TestPageState();
}

class _R2TestPageState extends State<R2TestPage> {
  String _testResults = '';
  bool _isTesting = false;

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResults = '${context.loc('testing_connection')}\n\n';
    });

    try {
      // First validate the configuration
      final validationIssues = R2ConnectionHelper.validateR2Config(
        widget.serverConfig,
      );
      if (validationIssues.isNotEmpty) {
        _testResults += '${context.loc('config_issues')}\n';
        for (final issue in validationIssues) {
          _testResults += '⚠ $issue\n';
        }
        _testResults += '\n';
      }

      final uri = Uri.parse(widget.serverConfig.address);
      final endPoint = uri.host;
      final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      final useSSL = uri.scheme == 'https';
      final isR2 = endPoint.contains('r2.cloudflarestorage.com');
      final region =
          widget.serverConfig.region ?? (isR2 ? 'auto' : 'us-east-1');

      // Test 1: Basic connection info
      _testResults += '${context.loc('connection_info')}\n';
      _testResults += 'Endpoint: ${widget.serverConfig.address}\n';
      _testResults += 'Parsed Host: $endPoint\n';
      _testResults += 'Port: $port\n';
      _testResults += 'SSL: $useSSL\n';
      _testResults += 'Region: $region\n';
      _testResults += 'Bucket: ${widget.serverConfig.bucket}\n';
      _testResults +=
          'Access Key: ${widget.serverConfig.accessKeyId.substring(0, 5)}...\n\n';

      // Show R2 endpoint format examples if it's R2
      if (isR2) {
        _testResults += '${context.loc('r2_endpoint_formats')}\n';
        final formats = R2ConnectionHelper.getR2EndpointFormats(
          endPoint.split('.')[0], // Extract account ID
          widget.serverConfig.bucket,
        );
        formats.forEach((name, url) {
          _testResults += '$name: $url\n';
        });
        _testResults += '\n';
      }

      // Test 2: Try to initialize MinIO client
      _testResults += '${context.loc('init_minio_client')}\n';
      final minioClient = R2ConnectionHelper.createR2Client(
        widget.serverConfig,
      );
      _testResults += '${context.loc('minio_client_init_success')}\n\n';

      // Test 3: Try to list buckets (R2 might not support this)
      _testResults += '${context.loc('test_list_buckets')}\n';
      try {
        final buckets = await minioClient.listBuckets();
        _testResults += '${context.loc('list_buckets_success')}\n';
        _testResults +=
            '${context.loc('found_buckets', [buckets.length.toString()])}\n';
        for (final bucket in buckets) {
          _testResults +=
              '  - ${bucket.name} (Created: ${bucket.creationDate})\n';
        }
      } catch (e) {
        _testResults +=
            '${context.loc('list_buckets_failed', [e.toString()])}\n';
        _testResults += '${context.loc('r2_list_buckets_note')}\n\n';

        // Test 4: Try to list objects in the specified bucket
        _testResults += '${context.loc('test_list_objects')}\n';
        try {
          final stream = minioClient.listObjects(widget.serverConfig.bucket);
          final results = await stream.toList();
          _testResults += '${context.loc('list_objects_success')}\n';
          _testResults +=
              '${context.loc('found_objects', [results.length.toString()])}\n';

          int objectCount = 0;
          int prefixCount = 0;
          for (final result in results) {
            objectCount += result.objects.length;
            prefixCount += result.prefixes.length;
          }
          _testResults +=
              '${context.loc('objects_prefixes_count', [objectCount.toString(), prefixCount.toString()])}\n';
        } catch (e) {
          _testResults +=
              '${context.loc('list_objects_failed', [e.toString()])}\n';

          // Check for specific R2 errors
          if (e.toString().contains('Connection failed')) {
            _testResults += '\n${context.loc('possible_issues')}\n';
            _testResults += '${context.loc('issue_check_url')}\n';
            _testResults += '${context.loc('issue_check_creds')}\n';
            _testResults += '${context.loc('issue_check_bucket')}\n';
            _testResults += '${context.loc('issue_check_network')}\n';
          }
        }
      }

      _testResults += '\n${context.loc('test_complete')}\n';
    } catch (e) {
      _testResults += '\n${context.loc('unexpected_error', [e.toString()])}\n';
      _testResults +=
          '${context.loc('error_type', [e.runtimeType.toString()])}\n';
    }

    setState(() {
      _isTesting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc('r2_test_title')),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _isTesting ? null : _testConnection,
              child: Text(
                _isTesting
                    ? context.loc('testing_connection')
                    : context.loc('test_connection_btn'),
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _testResults,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: AppFontSizes.sm,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
