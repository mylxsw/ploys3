import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:ploys3/core/design_system.dart';
import 'package:ploys3/core/localization.dart';
import 'package:ploys3/core/upload_manager.dart';
import 'package:ploys3/models/upload_history_record.dart';

class UploadQueueUI extends StatefulWidget {
  final UploadManager uploadManager;

  const UploadQueueUI({super.key, required this.uploadManager});

  @override
  State<UploadQueueUI> createState() => _UploadQueueUIState();
}

class _UploadQueueUIState extends State<UploadQueueUI> {
  bool _isExpanded = false;

  bool _isImageFile(String fileName) {
    final extension = fileName.contains('.')
        ? fileName.substring(fileName.lastIndexOf('.') + 1)
        : fileName;
    return UploadHistoryRecord.detectFileType(extension) == 'image';
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showCopyOptionsDialog(UploadItem item) {
    final url = item.resultUrl;
    if (url == null || url.isEmpty) return;

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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                title: Text(
                  context.loc('copy_url'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                onTap: () {
                  _copyToClipboard(url, context.loc('url_copied'));
                  Navigator.pop(dialogContext);
                },
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: Icon(
                  Icons.image,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                title: Text(
                  context.loc('copy_markdown'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                onTap: () {
                  final nameWithoutExt = item.fileName.contains('.')
                      ? item.fileName.substring(0, item.fileName.lastIndexOf('.'))
                      : item.fileName;
                  final markdown = '![$nameWithoutExt]($url)';
                  _copyToClipboard(markdown, context.loc('markdown_copied'));
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

  void _handleCopy(UploadItem item) {
    final url = item.resultUrl;
    if (url == null || url.isEmpty) return;

    if (_isImageFile(item.fileName)) {
      _showCopyOptionsDialog(item);
      return;
    }

    _copyToClipboard(url, context.loc('url_copied'));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.uploadManager,
      builder: (context, child) {
        final queue = widget.uploadManager.queue;
        if (queue.isEmpty) return const SizedBox.shrink();
        final mediaQuery = MediaQuery.of(context);
        final isMobilePlatform =
            const [TargetPlatform.iOS, TargetPlatform.android].contains(defaultTargetPlatform);
        final horizontalMargin = isMobilePlatform ? 12.0 : 20.0;
        final bottomMargin = isMobilePlatform ? 12.0 : 20.0;
        final collapsedHeight = isMobilePlatform ? 56.0 : 60.0;
        final expandedHeight =
            isMobilePlatform ? mediaQuery.size.height * 0.6 : 500.0;

        final activeCount = queue
            .where(
              (item) =>
                  item.status == UploadStatus.uploading ||
                  item.status == UploadStatus.pending,
            )
            .length;

        // Auto-collapse if everything is done? Maybe not, user might want to see results.
        // But if empty, we hide it.

        return Positioned(
          left: isMobilePlatform ? horizontalMargin : null,
          right: horizontalMargin,
          bottom: bottomMargin + mediaQuery.padding.bottom,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: isMobilePlatform ? double.infinity : (_isExpanded ? 400 : 200),
            height: _isExpanded ? expandedHeight : collapsedHeight,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: _isExpanded
                  ? _buildExpandedView(queue)
                  : _buildCollapsedView(activeCount),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCollapsedView(int activeCount) {
    return InkWell(
      onTap: () => setState(() => _isExpanded = true),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (activeCount > 0)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).primaryColor,
                ),
              )
            else
              Icon(Icons.check_circle, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                activeCount > 0
                    ? context.loc('uploading_count', [activeCount.toString()])
                    : context.loc('upload_complete'),
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_up,
              color: Theme.of(context).disabledColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedView(List<UploadItem> queue) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  context.loc('upload_queue'),
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (queue.every(
                    (i) =>
                        i.status == UploadStatus.success ||
                        i.status == UploadStatus.failed,
                  ))
                    IconButton(
                      icon: const Icon(Icons.clear_all),
                      tooltip: context.loc('clear_completed'),
                      onPressed: () => widget.uploadManager.clearAll(),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: () => setState(() => _isExpanded = false),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(0),
            itemCount: queue.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = queue[index];
              return ListTile(
                title: Text(
                  item.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: AppFontSizes.md),
                ),
                subtitle: item.status == UploadStatus.failed
                    ? Text(
                        item.errorMessage ?? context.loc('error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: AppFontSizes.sm,
                        ),
                      )
                    : item.status == UploadStatus.uploading
                    ? LinearProgressIndicator(minHeight: 2)
                    : null,
                trailing: _buildItemAction(item),
                dense: true,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildItemAction(UploadItem item) {
    switch (item.status) {
      case UploadStatus.pending:
        return Icon(
          Icons.hourglass_empty,
          size: 16,
          color: Theme.of(context).disabledColor,
        );
      case UploadStatus.uploading:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case UploadStatus.success:
        return IconButton(
          icon: const Icon(Icons.link),
          tooltip: context.loc('copy_link'),
          onPressed: () => _handleCopy(item),
        );
      case UploadStatus.failed:
        return IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: context.loc('retry'),
          onPressed: () => widget.uploadManager.retry(item),
        );
    }
  }
}
