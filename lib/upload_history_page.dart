import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ploys3/core/design_system.dart';
import 'package:ploys3/core/localization.dart';
import 'package:ploys3/core/upload_history_manager.dart';
import 'package:ploys3/models/upload_history_record.dart';
import 'package:ploys3/widgets/window_title_bar.dart';
import 'package:intl/intl.dart';

class UploadHistoryPage extends StatefulWidget {
  const UploadHistoryPage({super.key});

  @override
  State<UploadHistoryPage> createState() => _UploadHistoryPageState();
}

class _UploadHistoryPageState extends State<UploadHistoryPage> {
  final UploadHistoryManager _manager = UploadHistoryManager.instance;

  @override
  void initState() {
    super.initState();
    _manager.loadHistory(forceRefresh: true);
    _manager.addListener(_onChanged);
  }

  @override
  void dispose() {
    _manager.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _showClearAllDialog() {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.loc('clear_history_title')),
        content: Text(context.loc('clear_history_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.loc('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.loc('clear_all')),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        _manager.clearAll();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.loc('history_cleared'))),
          );
        }
      }
    });
  }

  void _deleteRecord(UploadHistoryRecord record) {
    _manager.deleteRecord(record.id);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.loc('record_deleted'))));
  }

  void _handleCopy(UploadHistoryRecord record) {
    if (record.fileType == 'image') {
      _showCopyOptionsDialog(record);
    } else {
      Clipboard.setData(ClipboardData(text: record.downloadUrl));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.loc('url_copied'))));
    }
  }

  void _showCopyOptionsDialog(UploadHistoryRecord record) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            context.loc('copy_options'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.link,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                title: Text(
                  context.loc('copy_url'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: record.downloadUrl));
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(context.loc('url_copied'))),
                  );
                  Navigator.pop(dialogContext);
                },
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: Icon(
                  Icons.image,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                title: Text(
                  context.loc('copy_markdown'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                onTap: () {
                  final nameWithoutExt = record.fileName.contains('.')
                      ? record.fileName.substring(
                          0,
                          record.fileName.lastIndexOf('.'),
                        )
                      : record.fileName;
                  final markdown = '![$nameWithoutExt](${record.downloadUrl})';
                  Clipboard.setData(ClipboardData(text: markdown));
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(context.loc('markdown_copied'))),
                  );
                  Navigator.pop(dialogContext);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.loc('cancel')),
            ),
          ],
        );
      },
    );
  }

  IconData _fileTypeIcon(String fileType) {
    return switch (fileType) {
      'image' => Icons.image_outlined,
      'video' => Icons.videocam_outlined,
      'audio' => Icons.audiotrack_outlined,
      'document' => Icons.description_outlined,
      'archive' => Icons.archive_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
    } catch (_) {
      return isoTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = _manager.records;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      body: WindowBorder(
        color: Colors.transparent,
        width: 0,
        child: Column(
          children: [
            const WindowTitleBar(),
            Expanded(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  title: Text(context.loc('upload_history')),
                  centerTitle: true,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  actions: [
                    if (records.isNotEmpty)
                      IconButton(
                        onPressed: _showClearAllDialog,
                        icon: const Icon(Icons.delete_sweep_outlined),
                        tooltip: context.loc('clear_all'),
                      ),
                  ],
                ),
                body: records.isEmpty
                    ? AppComponents.emptyState(
                        icon: Icons.history,
                        title: context.loc('no_upload_history'),
                        subtitle: context.loc('no_upload_history_hint'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: records.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final record = records[index];
                          return _buildRecordItem(context, record);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordItem(BuildContext context, UploadHistoryRecord record) {
    final theme = Theme.of(context);
    return Dismissible(
      key: Key(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async => true,
      onDismissed: (_) => _deleteRecord(record),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _handleCopy(record),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // File type icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _fileTypeIcon(record.fileType),
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // File info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.fileName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          record.downloadUrl,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontSize: AppFontSizes.xs,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.cloud_outlined,
                              size: 12,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                record.serverName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                  fontSize: AppFontSizes.xs,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(record.uploadTime),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                                fontSize: AppFontSizes.xs,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.copy,
                          size: 18,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        onPressed: () => _handleCopy(record),
                        tooltip: context.loc('copy_link'),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        onPressed: () => _deleteRecord(record),
                        tooltip: context.loc('delete'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
