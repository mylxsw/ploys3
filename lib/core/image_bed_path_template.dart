import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:ploys3/image_bed_settings_page.dart';

class ImageBedResolvedTarget {
  const ImageBedResolvedTarget({required this.key, required this.fileName});

  final String key;
  final String fileName;
}

class ImageBedPathTemplate {
  static const String yearVar = '{year}';
  static const String monthVar = '{month}';
  static const String dayVar = '{day}';
  static const String timestampVar = '{timestamp}';
  static const String fileNameVar = '{fileName}';
  static const String extVar = '{ext}';

  static const List<String> supportedVariables = <String>[
    yearVar,
    monthVar,
    dayVar,
    timestampVar,
    fileNameVar,
    extVar,
  ];

  static ImageBedResolvedTarget resolve(
    String filePath, {
    required String pathTemplate,
    required ImageBedNamingRule namingRule,
    DateTime? now,
    int? timestampMs,
  }) {
    final originalName = p.basename(filePath);
    final resolvedName = _resolveFileName(
      filePath,
      namingRule,
      now: now,
      timestampMs: timestampMs,
    );
    final normalizedTemplate = _normalizeTemplate(pathTemplate);

    if (normalizedTemplate.isEmpty) {
      return ImageBedResolvedTarget(key: resolvedName, fileName: resolvedName);
    }

    final resolvedTemplate = _applyTemplate(
      normalizedTemplate,
      originalName,
      now: now,
      timestampMs: timestampMs,
    );

    if (_templateSpecifiesFileName(normalizedTemplate)) {
      final normalizedKey = _normalizeResolvedKey(resolvedTemplate);
      return ImageBedResolvedTarget(
        key: normalizedKey,
        fileName: p.basename(normalizedKey),
      );
    }

    final prefix = _normalizePrefix(resolvedTemplate);
    final key = prefix.isEmpty ? resolvedName : '$prefix$resolvedName';
    return ImageBedResolvedTarget(key: key, fileName: resolvedName);
  }

  static String resolveFileName(
    String filePath,
    ImageBedNamingRule namingRule, {
    DateTime? now,
    int? timestampMs,
  }) {
    return _resolveFileName(
      filePath,
      namingRule,
      now: now,
      timestampMs: timestampMs,
    );
  }

  static String _resolveFileName(
    String filePath,
    ImageBedNamingRule namingRule, {
    DateTime? now,
    int? timestampMs,
  }) {
    final originalName = p.basename(filePath);
    if (namingRule == ImageBedNamingRule.original) {
      return originalName;
    }

    final dotIndex = originalName.lastIndexOf('.');
    final extension = dotIndex > 0 ? originalName.substring(dotIndex) : '';
    final currentTime = now ?? DateTime.now();
    final timestamp =
        '${currentTime.year}${currentTime.month.toString().padLeft(2, '0')}${currentTime.day.toString().padLeft(2, '0')}-${currentTime.hour.toString().padLeft(2, '0')}${currentTime.minute.toString().padLeft(2, '0')}${currentTime.second.toString().padLeft(2, '0')}';
    final rand = math.Random();
    final uuid =
        '${rand.nextInt(0x7FFFFFFF).toRadixString(36)}-${rand.nextInt(0x7FFFFFFF).toRadixString(36)}';
    return '$timestamp-$uuid$extension';
  }

  static String _applyTemplate(
    String template,
    String originalName, {
    DateTime? now,
    int? timestampMs,
  }) {
    final currentTime = now ?? DateTime.now();
    final effectiveTimestamp =
        timestampMs ?? currentTime.millisecondsSinceEpoch;
    final basename = p.basenameWithoutExtension(originalName);
    final extension = p.extension(originalName).replaceFirst('.', '');
    final sanitizedBasename = _sanitizeFileNamePart(basename);

    return template
        .replaceAll(yearVar, currentTime.year.toString().padLeft(4, '0'))
        .replaceAll(monthVar, currentTime.month.toString().padLeft(2, '0'))
        .replaceAll(dayVar, currentTime.day.toString().padLeft(2, '0'))
        .replaceAll(timestampVar, effectiveTimestamp.toString())
        .replaceAll(fileNameVar, sanitizedBasename)
        .replaceAll(extVar, extension);
  }

  static String _normalizeTemplate(String input) {
    var value = input.trim();
    if (value.isEmpty) return '';
    value = value.replaceAll('\\', '/');
    value = value.replaceAll(RegExp(r'^/+'), '');
    return value;
  }

  static String _normalizePrefix(String input) {
    final normalized = _normalizeResolvedKey(input);
    if (normalized.isEmpty) return '';
    return normalized.endsWith('/') ? normalized : '$normalized/';
  }

  static String _normalizeResolvedKey(String input) {
    var value = input.trim();
    if (value.isEmpty) return '';
    value = value.replaceAll('\\', '/');
    value = value.replaceAll(RegExp(r'^/+'), '');
    value = value.replaceAll(RegExp(r'/+'), '/');
    value = value.replaceAll(RegExp(r'/+$'), '');
    return value;
  }

  static bool _templateSpecifiesFileName(String template) {
    return template.contains(fileNameVar) || template.contains(extVar);
  }

  static String _sanitizeFileNamePart(String input) {
    final sanitized = input
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^[.-]+|[.-]+$'), '');
    return sanitized.isEmpty ? 'file' : sanitized;
  }
}
