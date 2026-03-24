import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

const String _configDir = '.config/ploys3';
const String _historyFileName = 'upload_history.json';
const String _lockFileName = 'upload_history.lock';

Future<void> addUploadHistoryRecord({
  required String filePath,
  required String downloadUrl,
  required String serverName,
}) async {
  final historyFile = await _ensureHistoryFile();
  await _withLock(historyFile, () async {
    final existing = await _readHistoryUnlocked(historyFile);
    final fileName = p.basename(filePath);
    final extension = p.extension(filePath);
    final now = DateTime.now().toIso8601String();
    existing.insert(0, {
      'id': '${DateTime.now().millisecondsSinceEpoch}_$fileName',
      'fileName': fileName,
      'fileExtension': extension,
      'fileType': _detectFileType(extension),
      'downloadUrl': downloadUrl,
      'serverName': serverName,
      'uploadTime': now,
    });

    existing.sort((a, b) {
      final left = a['uploadTime'] as String? ?? '';
      final right = b['uploadTime'] as String? ?? '';
      return right.compareTo(left);
    });

    final encoded = const JsonEncoder.withIndent('  ').convert(existing);
    await historyFile.writeAsString(encoded);
  });
}

Future<List<Map<String, dynamic>>> _readHistoryUnlocked(
  File historyFile,
) async {
  final raw = await historyFile.readAsString();
  if (raw.trim().isEmpty) {
    return <Map<String, dynamic>>[];
  }

  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    return <Map<String, dynamic>>[];
  }

  return decoded
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String _detectFileType(String extension) {
  final ext = extension.toLowerCase().replaceAll('.', '');
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
    'avif',
  };
  const videoExts = {'mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv', 'webm', 'm4v'};
  const audioExts = {'mp3', 'wav', 'flac', 'aac', 'ogg', 'wma', 'm4a'};
  const docExts = {
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'csv',
    'md',
    'rtf',
  };
  const archiveExts = {'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz'};

  if (imageExts.contains(ext)) return 'image';
  if (videoExts.contains(ext)) return 'video';
  if (audioExts.contains(ext)) return 'audio';
  if (docExts.contains(ext)) return 'document';
  if (archiveExts.contains(ext)) return 'archive';
  return 'other';
}

Future<File> _ensureHistoryFile() async {
  final home = Platform.environment['HOME'] ?? '';
  if (home.isEmpty) {
    throw FileSystemException(
      'Unable to resolve upload history path because HOME is unset.',
    );
  }

  final dir = Directory(p.join(home, _configDir));
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  final file = File(p.join(dir.path, _historyFileName));
  if (!file.existsSync()) {
    file.writeAsStringSync('[]');
  }
  return file;
}

Future<T> _withLock<T>(File historyFile, Future<T> Function() action) async {
  final lockFile = File(p.join(historyFile.parent.path, _lockFileName));
  if (!lockFile.existsSync()) {
    lockFile.createSync(recursive: true);
  }

  final handle = await lockFile.open(mode: FileMode.writeOnlyAppend);
  await handle.lock(FileLock.exclusive);
  try {
    return await action();
  } finally {
    await handle.unlock();
    await handle.close();
  }
}
