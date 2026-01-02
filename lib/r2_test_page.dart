import 'package:flutter/material.dart';
import 'package:s3_ui/models/s3_server_config.dart';
import 'package:s3_ui/r2_connection_helper.dart';
import 'package:s3_ui/core/design_system.dart';

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
      _testResults = 'Testing connection...\n\n';
    });

    try {
      // First validate the configuration
      final validationIssues = R2ConnectionHelper.validateR2Config(
        widget.serverConfig,
      );
      if (validationIssues.isNotEmpty) {
        _testResults += '=== Configuration Issues ===\n';
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
      _testResults += '=== Connection Info ===\n';
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
        _testResults += '=== R2 Endpoint Formats ===\n';
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
      _testResults += '=== Initializing MinIO Client ===\n';
      final minioClient = R2ConnectionHelper.createR2Client(
        widget.serverConfig,
      );
      _testResults += '✓ MinIO client initialized successfully\n\n';

      // Test 3: Try to list buckets (R2 might not support this)
      _testResults += '=== Testing List Buckets ===\n';
      try {
        final buckets = await minioClient.listBuckets();
        _testResults += '✓ List buckets succeeded\n';
        _testResults += 'Found ${buckets.length} bucket(s)\n';
        for (final bucket in buckets) {
          _testResults +=
              '  - ${bucket.name} (Created: ${bucket.creationDate})\n';
        }
      } catch (e) {
        _testResults += '✗ List buckets failed: $e\n';
        _testResults +=
            '  This is normal for R2 - it doesn\'t support list_buckets operation\n\n';

        // Test 4: Try to list objects in the specified bucket
        _testResults += '=== Testing List Objects ===\n';
        try {
          final stream = minioClient.listObjects(widget.serverConfig.bucket);
          final results = await stream.toList();
          _testResults += '✓ List objects succeeded\n';
          _testResults += 'Found ${results.length} result(s)\n';

          int objectCount = 0;
          int prefixCount = 0;
          for (final result in results) {
            objectCount += result.objects.length;
            prefixCount += result.prefixes.length;
          }
          _testResults += 'Objects: $objectCount, Prefixes: $prefixCount\n';
        } catch (e) {
          _testResults += '✗ List objects failed: $e\n';

          // Check for specific R2 errors
          if (e.toString().contains('Connection failed')) {
            _testResults += '\nPossible issues:\n';
            _testResults += '1. Check if the R2 endpoint URL is correct\n';
            _testResults += '2. Verify your access credentials\n';
            _testResults += '3. Ensure the bucket exists\n';
            _testResults += '4. Check your network connection\n';
          }
        }
      }

      _testResults += '\n=== Test Complete ===\n';
    } catch (e) {
      _testResults += '\n✗ Unexpected error: $e\n';
      _testResults += 'Error Type: ${e.runtimeType}\n';
    }

    setState(() {
      _isTesting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('R2 Connection Test'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _isTesting ? null : _testConnection,
              child: Text(_isTesting ? 'Testing...' : 'Test Connection'),
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
