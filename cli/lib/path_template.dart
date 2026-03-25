import 'dart:math' as math;

import 'package:path/path.dart' as p;

class ResolvedUploadTarget {
  const ResolvedUploadTarget({required this.key, required this.fileName});

  final String key;
  final String fileName;
}

ResolvedUploadTarget resolveUploadTarget({
  required String filePath,
  required String pathTemplate,
  required String namingRule,
  DateTime? now,
  int? timestampMs,
}) {
  final resolvedName = resolveFileName(
    filePath,
    namingRule,
    now: now,
    timestampMs: timestampMs,
  );
  final normalizedTemplate = _normalizeTemplate(pathTemplate);

  if (normalizedTemplate.isEmpty) {
    return ResolvedUploadTarget(key: resolvedName, fileName: resolvedName);
  }

  final resolvedTemplate = _applyTemplate(
    normalizedTemplate,
    p.basename(filePath),
    now: now,
    timestampMs: timestampMs,
  );

  if (_templateSpecifiesFileName(normalizedTemplate)) {
    final normalizedKey = _normalizeResolvedKey(resolvedTemplate);
    return ResolvedUploadTarget(
      key: normalizedKey,
      fileName: p.basename(normalizedKey),
    );
  }

  final prefix = normalizePrefix(resolvedTemplate);
  final key = prefix.isEmpty ? resolvedName : '$prefix$resolvedName';
  return ResolvedUploadTarget(key: key, fileName: resolvedName);
}

String resolveFileName(
  String filePath,
  String namingRule, {
  DateTime? now,
  int? timestampMs,
}) {
  final originalName = p.basename(filePath);
  if (namingRule == 'original') return originalName;

  final dotIndex = originalName.lastIndexOf('.');
  final extension = dotIndex > 0 ? originalName.substring(dotIndex) : '';
  final currentTime = now ?? DateTime.now();
  final timestamp =
      '${currentTime.year}'
      '${currentTime.month.toString().padLeft(2, '0')}'
      '${currentTime.day.toString().padLeft(2, '0')}-'
      '${currentTime.hour.toString().padLeft(2, '0')}'
      '${currentTime.minute.toString().padLeft(2, '0')}'
      '${currentTime.second.toString().padLeft(2, '0')}';
  final rand = math.Random();
  final uuid =
      '${rand.nextInt(0x7FFFFFFF).toRadixString(36)}-'
      '${rand.nextInt(0x7FFFFFFF).toRadixString(36)}';
  return '$timestamp-$uuid$extension';
}

String normalizePrefix(String prefix) {
  final normalized = _normalizeResolvedKey(prefix);
  if (normalized.isEmpty) return '';
  return normalized.endsWith('/') ? normalized : '$normalized/';
}

String _applyTemplate(
  String template,
  String originalName, {
  DateTime? now,
  int? timestampMs,
}) {
  final currentTime = now ?? DateTime.now();
  final effectiveTimestamp = timestampMs ?? currentTime.millisecondsSinceEpoch;
  final basename = p.basenameWithoutExtension(originalName);
  final extension = p.extension(originalName).replaceFirst('.', '');
  final sanitizedBasename = _sanitizeFileNamePart(basename);

  return template
      .replaceAll('{year}', currentTime.year.toString().padLeft(4, '0'))
      .replaceAll('{month}', currentTime.month.toString().padLeft(2, '0'))
      .replaceAll('{day}', currentTime.day.toString().padLeft(2, '0'))
      .replaceAll('{timestamp}', effectiveTimestamp.toString())
      .replaceAll('{fileName}', sanitizedBasename)
      .replaceAll('{ext}', extension);
}

String _normalizeTemplate(String input) {
  var value = input.trim();
  if (value.isEmpty) return '';
  value = value.replaceAll('\\', '/');
  value = value.replaceAll(RegExp(r'^/+'), '');
  return value;
}

String _normalizeResolvedKey(String input) {
  var value = input.trim();
  if (value.isEmpty) return '';
  value = value.replaceAll('\\', '/');
  value = value.replaceAll(RegExp(r'^/+'), '');
  value = value.replaceAll(RegExp(r'/+'), '/');
  value = value.replaceAll(RegExp(r'/+$'), '');
  return value;
}

bool _templateSpecifiesFileName(String template) {
  return template.contains('{fileName}') || template.contains('{ext}');
}

String _sanitizeFileNamePart(String input) {
  final sanitized = input
      .trim()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^[.-]+|[.-]+$'), '');
  return sanitized.isEmpty ? 'file' : sanitized;
}
