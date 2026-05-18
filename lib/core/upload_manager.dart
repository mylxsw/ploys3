import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as path;
import 'package:ploys3/core/content_type.dart';
import 'package:ploys3/core/image_bed_path_template.dart';
import 'package:ploys3/core/language_manager.dart';
import 'package:ploys3/core/menubar_controller.dart';
import 'package:ploys3/core/platform.dart';
import 'package:ploys3/core/storage/storage_service.dart';
import 'package:ploys3/core/upload_history_manager.dart';
import 'package:ploys3/models/upload_history_record.dart';

const MethodChannel _macFileAccessChannel = MethodChannel('com.ploys3/menubar');

enum UploadStatus { pending, uploading, success, failed }

class UploadItem {
  final String id;
  final String filePath;
  final String fileName;
  final String originalFileName;
  final String targetBucket;
  final String targetKey;
  final String? cdnUrl; // For localized "Check" or "Copy Link"

  UploadStatus status;
  double progress;
  String? errorMessage;
  String? resultUrl;

  UploadItem({
    required this.filePath,
    required this.fileName,
    required this.originalFileName,
    required this.targetBucket,
    required this.targetKey,
    this.cdnUrl,
    this.status = UploadStatus.pending,
    this.progress = 0.0,
  }) : id = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
}

class UploadManager extends ChangeNotifier {
  static FlutterLocalNotificationsPlugin? _notifications;
  static const int _notificationId = 2001;
  static const String copyMarkdownActionId = 'copy_markdown';
  static const String copyMarkdownCategoryId = 'upload_complete_markdown';
  static final Set<UploadManager> _activeManagers = {};
  static bool get hasAnyActiveUploads => _activeManagers.isNotEmpty;

  static void initializeNotifications(FlutterLocalNotificationsPlugin plugin) {
    _notifications = plugin;
  }

  final List<UploadItem> _queue = [];
  final StorageService _service;
  final String? _cdnUrl;
  final String serverName;
  final VoidCallback? onUploadComplete;

  bool _isProcessing = false;
  final Set<String> _notifiedItemIds = {};

  UploadManager({
    required StorageService service,
    String? cdnUrl,
    this.serverName = '',
    this.onUploadComplete,
  }) : _service = service,
       _cdnUrl = cdnUrl;

  List<UploadItem> get queue => List.unmodifiable(_queue);

  bool get hasActiveUploads => _queue.any(
    (item) =>
        item.status == UploadStatus.uploading ||
        item.status == UploadStatus.pending,
  );

  void addToQueue(List<String> filePaths, String targetPrefix) {
    addToQueueWithNameResolver(
      filePaths,
      targetPrefix,
      (filePath) => path.basename(filePath),
    );
  }

  List<UploadItem> addToQueueWithNameResolver(
    List<String> filePaths,
    String targetPrefix,
    String Function(String path) nameResolver,
  ) {
    final addedItems = <UploadItem>[];
    for (final filePath in filePaths) {
      final originalName = path.basename(filePath);
      final fileName = nameResolver(filePath);
      if (fileName.isEmpty) continue;
      final key = targetPrefix.isEmpty ? fileName : '$targetPrefix$fileName';

      final item = UploadItem(
        filePath: filePath,
        fileName: fileName,
        originalFileName: originalName,
        targetBucket: _service.bucketName,
        targetKey: key,
        cdnUrl: _cdnUrl,
      );
      _queue.add(item);
      addedItems.add(item);
    }
    notifyListeners();
    if (addedItems.isNotEmpty) {
      _markActive();
    }
    _processQueue();
    return addedItems;
  }

  List<UploadItem> addToQueueWithTargetResolver(
    List<String> filePaths,
    ImageBedResolvedTarget Function(String path) targetResolver,
  ) {
    final addedItems = <UploadItem>[];
    for (final filePath in filePaths) {
      final originalName = path.basename(filePath);
      final target = targetResolver(filePath);
      if (target.key.isEmpty || target.fileName.isEmpty) continue;

      final item = UploadItem(
        filePath: filePath,
        fileName: target.fileName,
        originalFileName: originalName,
        targetBucket: _service.bucketName,
        targetKey: target.key,
        cdnUrl: _cdnUrl,
      );
      _queue.add(item);
      addedItems.add(item);
    }
    notifyListeners();
    if (addedItems.isNotEmpty) {
      _markActive();
    }
    _processQueue();
    return addedItems;
  }

  void retry(UploadItem item) {
    if (item.status == UploadStatus.failed) {
      item.status = UploadStatus.pending;
      item.errorMessage = null;
      item.progress = 0.0;
      notifyListeners();
      _processQueue();
    }
  }

  void remove(UploadItem item) {
    _queue.remove(item);
    notifyListeners();
  }

  void clearCompleted() {
    _queue.removeWhere((item) => item.status == UploadStatus.success);
    notifyListeners();
  }

  void clearAll() {
    if (!hasActiveUploads) {
      _queue.clear();
      notifyListeners();
      _markInactive();
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;

    _isProcessing = true;

    try {
      while (true) {
        // Find next pending item
        final pendingItems = _queue
            .where((item) => item.status == UploadStatus.pending)
            .toList();
        if (pendingItems.isEmpty) break;

        final item = pendingItems.first;

        // Update status to uploading
        item.status = UploadStatus.uploading;
        notifyListeners();

        try {
          await _ensureFileReadable(item.filePath);
          final file = File(item.filePath);
          final stream = file.openRead().cast<Uint8List>();
          final size = await file.length();

          // We'll wrap the stream to track progress if Minio client allows,
          // otherwise we might just update to 100% on completion.
          // Minio's putObject doesn't easily expose stream progress callback in all versions,
          // but we can try to estimate or just wait.
          // For now, let's assume atomic upload for simplicity or mock progress.
          // If we want real progress, we need to wrap the stream.

          await _service.uploadStream(
            item.targetKey,
            stream,
            size: size,
            contentType:
                contentTypeForFileName(item.targetKey) ??
                contentTypeForFileName(item.originalFileName),
          );

          item.status = UploadStatus.success;
          item.progress = 1.0;
          item.resultUrl = _buildFileUrl(item.targetKey);
          // Save upload history
          _saveUploadHistory(item);
          // Trigger callback to refresh file list
          onUploadComplete?.call();
        } catch (e) {
          item.status = UploadStatus.failed;
          item.errorMessage = e.toString();
        }

        notifyListeners();
      }
      _notifyIfBatchCompleted();
    } finally {
      _isProcessing = false;
      if (!hasActiveUploads) {
        _markInactive();
      }
    }
  }

  void _saveUploadHistory(UploadItem item) {
    final dotIndex = item.originalFileName.lastIndexOf('.');
    final extension = dotIndex > 0
        ? item.originalFileName.substring(dotIndex)
        : '';
    final record = UploadHistoryRecord(
      id: '${DateTime.now().millisecondsSinceEpoch}_${item.fileName}',
      fileName: item.originalFileName,
      fileExtension: extension,
      fileType: UploadHistoryRecord.detectFileType(extension),
      downloadUrl: item.resultUrl ?? _buildFileUrl(item.targetKey),
      serverName: serverName,
      uploadTime: DateTime.now().toIso8601String(),
    );
    UploadHistoryManager.instance.addRecord(record);
  }

  String _buildFileUrl(String key) {
    if (_cdnUrl != null && _cdnUrl.isNotEmpty) {
      String url = _cdnUrl;
      if (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }
      return '$url/$key';
    }
    // Fallback if no CDN, maybe simple key or presigned?
    // Usually standard S3 URL structure or just key.
    return key;
  }

  void _notifyIfBatchCompleted() {
    if (_notifications == null) return;
    final hasActive = _queue.any(
      (item) =>
          item.status == UploadStatus.pending ||
          item.status == UploadStatus.uploading,
    );
    if (hasActive) return;
    _markInactive();

    final completedItems = _queue
        .where((item) => item.status == UploadStatus.success)
        .where((item) => !_notifiedItemIds.contains(item.id))
        .toList();
    if (completedItems.isEmpty) return;

    for (final item in completedItems) {
      _notifiedItemIds.add(item.id);
    }

    final urls = completedItems
        .map((item) => item.resultUrl ?? _buildFileUrl(item.targetKey))
        .toList();
    Clipboard.setData(ClipboardData(text: urls.join('\n')));

    final count = completedItems.length;
    final body = count <= 1
        ? LanguageManager.instance.getLocalized('upload_complete_body_single')
        : LanguageManager.instance
              .getLocalized('upload_complete_body_multi')
              .replaceFirst('%s', '$count');
    final markdownLines = completedItems
        .where((item) => _isImageFile(item.originalFileName))
        .map((item) {
          final url = item.resultUrl ?? _buildFileUrl(item.targetKey);
          final altText = path.basenameWithoutExtension(item.originalFileName);
          return '![$altText]($url)';
        })
        .toList();
    final markdown = markdownLines.join('\n\n');
    final hasMarkdown = markdown.isNotEmpty;
    final payload = json.encode({
      'markdown': markdown,
      'hasMarkdown': hasMarkdown,
    });
    final details = _buildNotificationDetails(
      includeMarkdownAction: hasMarkdown && Platform.isDesktop,
    );
    _notifications!.show(
      id: _notificationId,
      title: LanguageManager.instance.getLocalized('upload_complete'),
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  void _markActive() {
    if (!_activeManagers.contains(this)) {
      _activeManagers.add(this);
      _updateMenuBarUploadingState();
    }
  }

  void _markInactive() {
    if (_activeManagers.remove(this)) {
      _updateMenuBarUploadingState();
    }
  }

  static void _updateMenuBarUploadingState() {
    if (!Platform.isMacOS) return;
    if (_activeManagers.isNotEmpty) {
      MenuBarIconController.setUploading();
    } else {
      MenuBarIconController.resetToNormal();
    }
  }

  bool _isImageFile(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    const imageExts = {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'webp',
      'svg',
      'tif',
      'tiff',
      'heic',
      'heif',
      'ico',
    };
    return imageExts.contains(ext);
  }

  NotificationDetails _buildNotificationDetails({
    required bool includeMarkdownAction,
  }) {
    if (Platform.isMacOS) {
      final darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        categoryIdentifier: includeMarkdownAction
            ? copyMarkdownCategoryId
            : null,
      );
      return NotificationDetails(macOS: darwinDetails);
    }

    if (defaultTargetPlatform == TargetPlatform.windows) {
      final actions = includeMarkdownAction
          ? [
              WindowsAction(
                content: LanguageManager.instance.getLocalized('copy_markdown'),
                arguments: copyMarkdownActionId,
              ),
            ]
          : <WindowsAction>[];
      final windowsDetails = WindowsNotificationDetails(actions: actions);
      return NotificationDetails(windows: windowsDetails);
    }

    if (defaultTargetPlatform == TargetPlatform.linux) {
      final actions = includeMarkdownAction
          ? [
              LinuxNotificationAction(
                key: copyMarkdownActionId,
                label: LanguageManager.instance.getLocalized('copy_markdown'),
              ),
            ]
          : <LinuxNotificationAction>[];
      final linuxDetails = LinuxNotificationDetails(actions: actions);
      return NotificationDetails(linux: linuxDetails);
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      );
      return const NotificationDetails(iOS: darwinDetails);
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidDetails = AndroidNotificationDetails(
        'upload_complete',
        LanguageManager.instance.getLocalized('upload_complete_channel'),
        channelDescription: LanguageManager.instance.getLocalized(
          'upload_complete_channel_desc',
        ),
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
      return NotificationDetails(android: androidDetails);
    }

    return const NotificationDetails();
  }

  Future<void> _ensureFileReadable(String filePath) async {
    if (!Platform.isMacOS) return;
    try {
      // Best-effort: try to acquire security-scoped access.
      // If it fails, we still attempt the upload — the file may be
      // readable without a bookmark (e.g. when passed by the CLI tool
      // or located in an already-accessible directory).
      await _macFileAccessChannel.invokeMethod<dynamic>(
        'ensureFileAccess',
        filePath,
      );
    } catch (_) {
      // Ignore all errors — the actual file read in uploadStream
      // will produce a clear error if the file is truly inaccessible.
    }
  }
}
