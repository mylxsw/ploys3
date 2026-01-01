import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:minio/minio.dart' as minio;
import 'package:minio/io.dart';
import 'package:minio/models.dart';
import 'package:s3_ui/models/s3_server_config.dart';
import 'package:s3_ui/r2_connection_helper.dart';
import 'package:s3_ui/download_manager.dart';

/// Represents an S3 object or directory prefix
class S3Item {
  final String key;
  final int? size;
  final DateTime? lastModified;
  final bool isDirectory;
  final String? eTag;

  S3Item({required this.key, this.size, this.lastModified, required this.isDirectory, this.eTag});

  /// Create an S3Item from an Object (file)
  factory S3Item.fromObject(Object obj) {
    return S3Item(
      key: obj.key ?? '',
      size: obj.size,
      lastModified: obj.lastModified,
      isDirectory: false,
      eTag: obj.eTag,
    );
  }

  /// Create an S3Item from a prefix (directory)
  factory S3Item.fromPrefix(String prefix) {
    return S3Item(key: prefix, size: null, lastModified: null, isDirectory: true, eTag: null);
  }
}

class S3BrowserPage extends StatefulWidget {
  final S3ServerConfig serverConfig;

  const S3BrowserPage({super.key, required this.serverConfig});

  @override
  State<S3BrowserPage> createState() => _S3BrowserPageState();
}

class _S3BrowserPageState extends State<S3BrowserPage> {
  late minio.Minio _minio;
  List<S3Item> _objects = [];
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isGridView = false;
  String _currentPrefix = '';
  final List<String> _prefixHistory = [];
  bool _isDragging = false;

  // Cache storage for file listings
  final Map<String, List<S3Item>> _cache = {};
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _initializeMinio();
    _listObjects();
  }

  @override
  void didUpdateWidget(S3BrowserPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.serverConfig.id != oldWidget.serverConfig.id) {
      // Clear cache and reset state when switching servers
      _cache.clear();
      _currentPrefix = '';
      _prefixHistory.clear();
      _objects = [];
      _isLoading = true;
      _initializeMinio();
      _listObjects();
    }
  }

  void _initializeMinio() {
    try {
      // First check if this is R2 and validate
      final validationIssues = R2ConnectionHelper.validateR2Config(widget.serverConfig);
      if (validationIssues.isNotEmpty) {
        debugPrint('Configuration validation issues:');
        for (final issue in validationIssues) {
          debugPrint('  - $issue');
        }
      }

      // Use R2 helper for R2 endpoints
      final uri = Uri.parse(widget.serverConfig.address);
      final isR2 = uri.host.contains('r2.cloudflarestorage.com');

      if (isR2) {
        debugPrint('Using R2 connection helper');
        _minio = R2ConnectionHelper.createR2Client(widget.serverConfig);
      } else {
        // Standard S3 configuration
        final endPoint = uri.host;
        final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
        final useSSL = uri.scheme == 'https';
        final region = widget.serverConfig.region ?? 'us-east-1';

        debugPrint('Using standard S3 configuration');
        debugPrint('Endpoint: $endPoint');
        debugPrint('Port: $port');
        debugPrint('Use SSL: $useSSL');
        debugPrint('Region: $region');

        _minio = minio.Minio(
          endPoint: endPoint,
          port: port,
          accessKey: widget.serverConfig.accessKeyId,
          secretKey: widget.serverConfig.secretAccessKey,
          useSSL: useSSL,
          region: region,
        );
      }

      debugPrint('✓ MinIO client initialized successfully');
    } catch (e) {
      debugPrint('✗ Failed to initialize MinIO client: $e');
      // Re-throw to be handled by the caller
      rethrow;
    }
  }

  Future<void> _listObjects({String? prefix}) async {
    final effectivePrefix = prefix ?? _currentPrefix;
    final cacheKey = '${widget.serverConfig.id}:${widget.serverConfig.bucket}:$effectivePrefix';

    // Check if we have cached data and we're not already refreshing
    if (_cache.containsKey(cacheKey) && !_isRefreshing && _currentPrefix == effectivePrefix) {
      setState(() {
        _objects = _cache[cacheKey]!;
        _isLoading = false;
      });
      debugPrint('Loaded from cache for prefix: $effectivePrefix');
    } else if (!_isRefreshing) {
      // No cache or different prefix, show loading
      setState(() {
        _isLoading = true;
      });
    }

    // Always fetch fresh data in the background
    _isRefreshing = true;

    try {
      // Debug information
      debugPrint('Listing objects from bucket: ${widget.serverConfig.bucket}');
      debugPrint('Using endpoint: ${widget.serverConfig.address}');
      debugPrint('Using prefix: $effectivePrefix');

      final stream = _minio.listObjects(widget.serverConfig.bucket, prefix: effectivePrefix);
      final results = await stream.toList();

      // Convert ListObjectsResult to S3Item
      final items = <S3Item>[];
      final directories = <S3Item>[];
      final files = <S3Item>[];

      for (final result in results) {
        // Add directory prefixes first
        for (final prefix in result.prefixes) {
          directories.add(S3Item.fromPrefix(prefix));
        }
        // Add objects (files)
        for (final obj in result.objects) {
          files.add(S3Item.fromObject(obj));
        }
      }

      // Sort directories and files separately
      directories.sort((a, b) => a.key.compareTo(b.key));
      files.sort((a, b) => a.key.compareTo(b.key));

      // Combine: directories first, then files
      items.addAll(directories);
      items.addAll(files);

      // Update cache
      _cache[cacheKey] = List.from(items);

      // Update UI if we're still on the same page
      if (mounted) {
        setState(() {
          _objects = items;
          _isLoading = false;
          _isRefreshing = false;
        });
        debugPrint('Updated with fresh data for prefix: $effectivePrefix');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });

        // More detailed error message
        String errorMessage = 'Error listing objects: $e';
        String detailedError = e.toString();

        debugPrint('=== S3 List Error ===');
        debugPrint('Error Type: ${e.runtimeType}');
        debugPrint('Error Message: $e');
        debugPrint('Full Error: $detailedError');
        debugPrint('====================');

        if (detailedError.contains('Connection failed')) {
          errorMessage =
              'Connection failed. Please check:\n'
              '1. Your network connection\n'
              '2. The endpoint URL is correct\n'
              '3. Your access credentials are valid\n'
              '4. For R2: Ensure the bucket exists and is accessible\n\n'
              'Technical details: ${e.toString().substring(0, 100)}...';
        } else if (detailedError.contains('AccessDenied')) {
          errorMessage =
              'Access Denied. Please check:\n'
              '1. Your access key and secret are correct\n'
              '2. The bucket exists\n'
              '3. You have list permissions on the bucket';
        } else if (detailedError.contains('NoSuchBucket')) {
          errorMessage =
              'Bucket not found. Please check:\n'
              '1. The bucket name is spelled correctly\n'
              '2. The bucket exists in your account';
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage), duration: const Duration(seconds: 8)));
      }
    }
  }

  void _clearCache() {
    // Clear all cached data for this bucket
    final prefix = '${widget.serverConfig.id}:${widget.serverConfig.bucket}:';
    _cache.removeWhere((key, value) => key.startsWith(prefix));
    debugPrint('Cleared cache for bucket: ${widget.serverConfig.bucket}');
  }

  void _showUploadProgressDialog(String fileName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Uploading $fileName...',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text('Please wait', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteProgressDialog(String fileName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Deleting ${fileName.split('/').last}...',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text('Please wait', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadObject(String key, {bool showDialog = true}) async {
    try {
      final stream = await _minio.getObject(widget.serverConfig.bucket, key);
      final bytes = await stream.toList();
      final flatBytes = bytes.expand((x) => x).toList();

      // Use our download manager for better error handling
      final filePath = await DownloadManager.saveFile(fileName: key, bytes: Uint8List.fromList(flatBytes));

      if (showDialog) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded: ${filePath.split('/').last}'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () {
                // Could add functionality to open the file location
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (showDialog) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error downloading $key: $e'), backgroundColor: Colors.red));
      }
      rethrow;
    }
  }

  Future<void> _renameObject(String oldKey) async {
    final newKeyController = TextEditingController(text: oldKey);
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Object'),
        content: TextField(
          controller: newKeyController,
          decoration: const InputDecoration(labelText: 'New name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Rename')),
        ],
      ),
    );

    if (confirmed == true) {
      final newKey = newKeyController.text;
      if (newKey.isNotEmpty && newKey != oldKey) {
        try {
          await _minio.copyObject(widget.serverConfig.bucket, newKey, '/${widget.serverConfig.bucket}/$oldKey');
          await _minio.removeObject(widget.serverConfig.bucket, oldKey);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Renamed $oldKey to $newKey')));
          _listObjects();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error renaming $oldKey: $e')));
        }
      }
    }
  }

  Future<void> _deleteObject(String key) async {
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Object'),
        content: Text('Are you sure you want to delete "$key"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      // Show progress dialog
      _showDeleteProgressDialog(key);

      try {
        await _minio.removeObject(widget.serverConfig.bucket, key);

        // Close progress dialog
        if (mounted) {
          Navigator.pop(context); // Close progress dialog
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted $key')));
          // Clear cache and refresh
          _clearCache();
          _listObjects();
        }
      } catch (e) {
        // Close progress dialog if still open
        if (mounted) {
          try {
            Navigator.pop(context); // Close progress dialog
          } catch (_) {}

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting $key: $e')));
        }
      }
    }
  }

  Future<void> _deleteFolder(String folderKey) async {
    // Ensure folder key ends with '/'
    final normalizedFolderKey = folderKey.endsWith('/') ? folderKey : '$folderKey/';

    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete the folder "$folderKey"?'),
            const SizedBox(height: 8),
            const Text(
              'Warning: This will delete all files and subfolders inside!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show progress dialog
    _showDeleteProgressDialog(folderKey);

    try {
      // First, list all objects with the folder prefix
      final stream = _minio.listObjects(widget.serverConfig.bucket, prefix: normalizedFolderKey);
      final results = await stream.toList();

      int deletedCount = 0;

      // Delete all objects in the folder
      for (final result in results) {
        // Delete objects
        for (final obj in result.objects) {
          if (obj.key != null) {
            await _minio.removeObject(widget.serverConfig.bucket, obj.key!);
            deletedCount++;
          }
        }
      }

      // Close progress dialog
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deleted folder "$folderKey" and $deletedCount object(s)')));
        // Clear cache and refresh
        _clearCache();
        _listObjects();
      }
    } catch (e) {
      // Close progress dialog if still open
      if (mounted) {
        try {
          Navigator.pop(context); // Close progress dialog
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting folder $folderKey: $e')));
      }
    }
  }

  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];

    // Calculate which suffix to use
    var i = 0;
    var size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  // Navigation methods
  void _navigateToDirectory(String prefix) {
    setState(() {
      _prefixHistory.add(_currentPrefix);
      _currentPrefix = prefix;
      // Clear current objects to prevent showing stale data
      _objects = [];
      _isLoading = true;
    });
    _listObjects(prefix: prefix);
  }

  void _showFileListCopyMenu(String key, bool isImage) {
    // Create a custom dropdown button that will handle the positioning
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Copy Options', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.link, color: Colors.white70),
                title: const Text('Copy URL', style: TextStyle(color: Colors.white)),
                onTap: () {
                  final url = _buildFileUrl(key);
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(const SnackBar(content: Text('URL copied to clipboard')));
                  Navigator.pop(dialogContext);
                },
              ),
              if (isImage) ...[
                const Divider(color: Colors.white24),
                ListTile(
                  leading: const Icon(Icons.image, color: Colors.white70),
                  title: const Text('Copy Markdown', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    final url = _buildFileUrl(key);
                    final markdown = '![${key.split('/').last}]($url)';
                    Clipboard.setData(ClipboardData(text: markdown));
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(const SnackBar(content: Text('Markdown copied to clipboard')));
                    Navigator.pop(dialogContext);
                  },
                ),
              ],
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel'))],
        );
      },
    );
  }

  String _buildFileUrl(String key) {
    if (widget.serverConfig.cdnUrl != null && widget.serverConfig.cdnUrl!.isNotEmpty) {
      String cdnUrl = widget.serverConfig.cdnUrl!;
      if (cdnUrl.endsWith('/')) {
        cdnUrl = cdnUrl.substring(0, cdnUrl.length - 1);
      }
      return '$cdnUrl/$key';
    } else {
      String baseUrl = widget.serverConfig.address;
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }
      return '$baseUrl/$key';
    }
  }

  void _goBack() {
    if (_prefixHistory.isNotEmpty) {
      setState(() {
        _currentPrefix = _prefixHistory.removeLast();
        // Clear current objects to prevent showing stale data
        _objects = [];
        _isLoading = true;
      });
      _listObjects(prefix: _currentPrefix);
    }
  }

  // File preview method
  void _showFilePreview(S3Item object) async {
    if (object.isDirectory) {
      _navigateToDirectory(object.key);
      return;
    }

    // Check if it's an image
    final isImage = RegExp(r'\.(jpg|jpeg|png|gif|bmp|webp|svg)$', caseSensitive: false).hasMatch(object.key);

    // For files, show preview dialog
    showDialog(
      context: context,
      builder: (context) => _PreviewDialog(
        object: object,
        serverConfig: widget.serverConfig,
        minioClient: _minio,
        isImage: isImage,
        onDownload: _downloadObject,
      ),
    );
  }

  Future<void> _uploadFile() async {
    setState(() {
      _isUploading = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final filePath = file.path!;
        final fileName = file.name;

        await _uploadFileFromPath(filePath, fileName);
      } else {
        // User cancelled file picker
        setState(() {
          _isUploading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted && _isUploading) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _uploadFileFromPath(String filePath, String fileName) async {
    // Determine the key (path in bucket)
    final key = _currentPrefix.isEmpty ? fileName : '$_currentPrefix$fileName';

    debugPrint('Uploading $fileName to $key');

    // Show progress dialog
    _showUploadProgressDialog(fileName);

    try {
      await _minio.fPutObject(widget.serverConfig.bucket, key, filePath);

      // Close progress dialog
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Uploaded $fileName')));
        // Clear cache and refresh to show the new file
        _clearCache();
        _listObjects(prefix: _currentPrefix);
      }
    } catch (e) {
      // Close progress dialog if still open
      if (mounted) {
        try {
          Navigator.pop(context); // Close progress dialog
        } catch (_) {}

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red));
      }
      rethrow;
    }
  }

  void _handleDragDone(DropDoneDetails details) async {
    setState(() {
      _isDragging = false;
    });

    if (details.files.isEmpty) return;

    // Process each dropped file
    for (final file in details.files) {
      try {
        final fileName = file.name;
        final filePath = file.path;

        if (filePath.isNotEmpty) {
          setState(() {
            _isUploading = true;
          });

          await _uploadFileFromPath(filePath, fileName);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to upload ${file.name}: $e'), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      }
    }
  }

  Future<void> _createFolder() async {
    final folderNameController = TextEditingController();
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Folder'),
        content: TextField(
          controller: folderNameController,
          decoration: const InputDecoration(labelText: 'Folder name', hintText: 'Enter folder name (e.g., my-folder)'),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(context, true);
            }
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (folderNameController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirmed != true || folderNameController.text.trim().isEmpty) return;

    setState(() {
      _isUploading = true;
    });

    try {
      // Normalize folder name - ensure it ends with /
      String folderName = folderNameController.text.trim();
      if (!folderName.endsWith('/')) {
        folderName = '$folderName/';
      }

      // Build the full key with current prefix
      final key = _currentPrefix.isEmpty ? folderName : '$_currentPrefix$folderName';

      debugPrint('Creating folder: $key');

      // In S3, folders are created by uploading an empty object with the folder name ending with /
      await _minio.putObject(
        widget.serverConfig.bucket,
        key,
        Stream.fromIterable([Uint8List(0)]), // Empty content
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Created folder: ${folderName.replaceAll('/', '')}')));
        // Clear cache and refresh to show the new folder
        _clearCache();
        _listObjects();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create folder: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.serverConfig.name),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        actions: [
          // View toggle button
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
            tooltip: _isGridView ? 'List view' : 'Grid view',
          ),
          // Create folder button
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            onPressed: _isUploading ? null : _createFolder,
            tooltip: 'Create folder',
          ),
          // Upload button
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _isUploading ? null : _uploadFile,
            tooltip: 'Upload file',
          ),
          // Refresh button
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _isLoading || _isRefreshing
                ? null
                : () {
                    _clearCache();
                    _listObjects(prefix: _currentPrefix);
                  },
            tooltip: 'Refresh',
          ),
        ],
      ),
      backgroundColor: const Color(0xFF121212),
      body: DropTarget(
        onDragDone: _handleDragDone,
        onDragEntered: (details) {
          setState(() {
            _isDragging = true;
          });
        },
        onDragExited: (details) {
          setState(() {
            _isDragging = false;
          });
        },
        child: Stack(
          children: [
            Column(
              children: [
                // Breadcrumb navigation
                if (_currentPrefix.isNotEmpty || _prefixHistory.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Home button to return to root
                        if (_currentPrefix.isNotEmpty || _prefixHistory.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              // Clear prefix history and go to root
                              setState(() {
                                _prefixHistory.clear();
                                _currentPrefix = '';
                                _objects = [];
                                _isLoading = true;
                              });
                              _listObjects(prefix: '');
                            },
                            icon: const Icon(Icons.home, size: 16),
                            label: const Text('Home'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                        if ((_prefixHistory.isNotEmpty || _currentPrefix.isNotEmpty) && _currentPrefix.isNotEmpty) const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentPrefix.isEmpty ? 'Root' : _currentPrefix,
                            style: const TextStyle(color: Colors.white70),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Back button moved to the right
                        if (_prefixHistory.isNotEmpty)
                          TextButton.icon(
                            onPressed: _goBack,
                            icon: const Icon(Icons.arrow_back, size: 16),
                            label: const Text('Back'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                      ],
                    ),
                  ),

                // Objects list/grid
                Expanded(
                  child: _isLoading && !_isRefreshing
                      ? const Center(child: CircularProgressIndicator())
                      : _objects.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _currentPrefix.isEmpty ? Icons.cloud_off : Icons.folder_open,
                                size: 64,
                                color: Colors.white24,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _currentPrefix.isEmpty ? 'No objects in bucket' : 'No objects in this directory',
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        )
                      : _isGridView
                      ? _buildGridView()
                      : _buildListView(),
                ),
              ],
            ),
            // Drag overlay
            if (_isDragging)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber, width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_upload, size: 64, color: Colors.amber),
                        const SizedBox(height: 16),
                        Text(
                          'Drop files here to upload',
                          style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      itemCount: _objects.length,
      itemBuilder: (context, index) {
        final object = _objects[index];
        return ListTile(
          leading: Icon(
            object.isDirectory ? Icons.folder : Icons.insert_drive_file,
            color: object.isDirectory ? Colors.amber : Colors.white70,
          ),
          title: Text(
            object.key.startsWith(_currentPrefix) ? object.key.substring(_currentPrefix.length) : object.key,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: object.isDirectory
              ? null
              : Text(
                  '${_formatBytes(object.size ?? 0, 1)} • ${DateFormat('yyyy-MM-dd HH:mm').format(object.lastModified ?? DateTime.now())}',
                  style: const TextStyle(color: Colors.white70),
                ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'download') {
                _downloadObject(object.key);
              } else if (value == 'copy') {
                // Check if it's an image
                final isImage = RegExp(
                  r'\.(jpg|jpeg|png|gif|bmp|webp|svg)$',
                  caseSensitive: false,
                ).hasMatch(object.key);
                if (isImage) {
                  _showFileListCopyMenu(object.key, true);
                } else {
                  // For non-image files, copy URL directly
                  final url = _buildFileUrl(object.key);
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL copied to clipboard')));
                }
              } else if (value == 'rename') {
                _renameObject(object.key);
              } else if (value == 'delete') {
                if (object.isDirectory) {
                  _deleteFolder(object.key);
                } else {
                  _deleteObject(object.key);
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'download', child: Text('Download')),
              if (!object.isDirectory) ...[
                const PopupMenuItem(value: 'copy', child: Text('Copy URL')),
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
              ],
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          onTap: () {
            if (object.isDirectory) {
              _navigateToDirectory(object.key);
            } else {
              _showFilePreview(object);
            }
          },
        );
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _objects.length,
      itemBuilder: (context, index) {
        final object = _objects[index];
        return Card(
          color: const Color(0xFF1E1E1E),
          child: InkWell(
            onTap: () {
              if (object.isDirectory) {
                _navigateToDirectory(object.key);
              } else {
                _showFilePreview(object);
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  object.isDirectory ? Icons.folder : Icons.insert_drive_file,
                  size: 48,
                  color: object.isDirectory ? Colors.amber : Colors.white70,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    object.key.startsWith(_currentPrefix) ? object.key.substring(_currentPrefix.length) : object.key,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!object.isDirectory) ...[
                  const SizedBox(height: 4),
                  Text(_formatBytes(object.size ?? 0, 0), style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Custom preview dialog widget
class _PreviewDialog extends StatefulWidget {
  final S3Item object;
  final S3ServerConfig serverConfig;
  final minio.Minio minioClient;
  final bool isImage;
  final Function(String, {bool showDialog}) onDownload;

  const _PreviewDialog({
    required this.object,
    required this.serverConfig,
    required this.minioClient,
    required this.isImage,
    required this.onDownload,
  });

  @override
  State<_PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<_PreviewDialog> {
  Uint8List? _imageBytes;
  bool _isLoadingImage = false;
  bool _isDownloading = false;
  final GlobalKey _copyButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.isImage) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      _isLoadingImage = true;
    });

    try {
      final stream = await widget.minioClient.getObject(widget.serverConfig.bucket, widget.object.key);
      final bytes = await stream.toList();
      final flatBytes = bytes.expand((x) => x).toList();

      if (mounted) {
        setState(() {
          _imageBytes = Uint8List.fromList(flatBytes);
          _isLoadingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingImage = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load image: $e'), backgroundColor: Colors.red));
      }
    }
  }

  String _getFileUrl() {
    // If CDN URL is configured, use it
    if (widget.serverConfig.cdnUrl != null && widget.serverConfig.cdnUrl!.isNotEmpty) {
      // Remove trailing slash from CDN URL if present
      String cdnUrl = widget.serverConfig.cdnUrl!;
      if (cdnUrl.endsWith('/')) {
        cdnUrl = cdnUrl.substring(0, cdnUrl.length - 1);
      }
      // Build the full URL
      return '$cdnUrl/${widget.object.key}';
    } else {
      // Otherwise, use the S3 address to build the URL
      String baseUrl = widget.serverConfig.address;
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }
      return '$baseUrl/${widget.object.key}';
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showCopyMenu() {
    // Get the button's RenderBox using the GlobalKey
    final RenderObject? renderObject = _copyButtonKey.currentContext?.findRenderObject();
    if (renderObject == null || renderObject is! RenderBox) return;

    final button = renderObject;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

    // Calculate position relative to the overlay
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem<String>(
          value: 'url',
          child: ListTile(leading: Icon(Icons.link), title: Text('Copy URL'), dense: true),
        ),
        if (widget.isImage) ...[
          const PopupMenuItem<String>(
            value: 'markdown',
            child: ListTile(leading: Icon(Icons.image), title: Text('Copy Markdown'), dense: true),
          ),
        ],
      ],
    ).then((String? value) {
      if (value == null) return;

      final url = _getFileUrl();

      switch (value) {
        case 'url':
          _copyToClipboard(url, 'URL copied to clipboard');
          break;
        case 'markdown':
          final markdown = '![${widget.object.key.split('/').last}]($url)';
          _copyToClipboard(markdown, 'Markdown copied to clipboard');
          break;
      }
    });
  }

  Future<void> _handleDownload() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      // Download without showing dialog (since we're already in a dialog)
      await widget.onDownload(widget.object.key, showDialog: false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded: ${widget.object.key.split('/').last}'),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.object.key,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Preview area
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Preview/Image area
                  Expanded(flex: 2, child: _buildPreviewContent()),
                  const SizedBox(width: 16),
                  // File details
                  Expanded(flex: 1, child: _buildFileDetails(dateFormat)),
                ],
              ),
            ),

            // Action buttons
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  key: _copyButtonKey,
                  onPressed: _showCopyMenu,
                  icon: const Icon(Icons.content_copy),
                  label: const Text('Copy'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isDownloading ? null : _handleDownload,
                  icon: _isDownloading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download),
                  label: Text(_isDownloading ? 'Downloading...' : 'Download'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewContent() {
    if (!widget.isImage) {
      return Container(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.insert_drive_file, size: 64, color: Colors.white.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text('File Preview', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
              const SizedBox(height: 8),
              Text(
                'Preview not available for this file type',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoadingImage) {
      return Container(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_imageBytes != null) {
      return Container(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            _imageBytes!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 64, color: Colors.white.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text('Failed to load image', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, size: 64, color: Colors.white.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('Image Preview', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
            const SizedBox(height: 8),
            Text(
              'Failed to load image preview',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileDetails(DateFormat dateFormat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'File Information',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Name', widget.object.key),
          if (widget.object.size != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow('Size', _formatBytes(widget.object.size!, 2)),
          ],
          if (widget.object.lastModified != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow('Modified', dateFormat.format(widget.object.lastModified!)),
          ],
          if (widget.object.eTag != null) ...[const SizedBox(height: 8), _buildDetailRow('ETag', widget.object.eTag!)],
          const SizedBox(height: 8),
          _buildDetailRow('Type', widget.isImage ? 'Image' : 'File'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
      ],
    );
  }

  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];

    // Calculate which suffix to use
    var i = 0;
    var size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}
