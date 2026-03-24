import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:ploys3/models/upload_history_record.dart';

class UploadHistoryStore {
  static const String _configDir = '.config/ploys3';
  static const String _historyFileName = 'upload_history.json';
  static const String _lockFileName = 'upload_history.lock';

  static String? get historyFilePath {
    final home = Platform.environment['HOME'] ?? '';
    if (home.isEmpty) return null;
    return p.join(home, _configDir, _historyFileName);
  }

  static String? get historyDirectoryPath {
    final filePath = historyFilePath;
    if (filePath == null) return null;
    return p.dirname(filePath);
  }

  static Future<List<UploadHistoryRecord>> readRecords() async {
    final file = await _ensureHistoryFile();
    return _withLock(file, () async {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return <UploadHistoryRecord>[];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <UploadHistoryRecord>[];
      }

      return decoded
          .whereType<Map>()
          .map(
            (json) =>
                UploadHistoryRecord.fromJson(Map<String, dynamic>.from(json)),
          )
          .toList();
    });
  }

  static Future<void> writeRecords(List<UploadHistoryRecord> records) async {
    final file = await _ensureHistoryFile();
    await _withLock(file, () async {
      final payload = records.map((record) => record.toJson()).toList();
      final encoded = const JsonEncoder.withIndent('  ').convert(payload);
      await file.writeAsString(encoded);
    });
  }

  static Future<void> appendRecord(UploadHistoryRecord record) async {
    final file = await _ensureHistoryFile();
    await _withLock(file, () async {
      final existing = await _readRecordsUnlocked(file);
      existing.insert(0, record);
      existing.sort((a, b) => b.uploadTime.compareTo(a.uploadTime));

      final payload = existing.map((item) => item.toJson()).toList();
      final encoded = const JsonEncoder.withIndent('  ').convert(payload);
      await file.writeAsString(encoded);
    });
  }

  static Future<List<UploadHistoryRecord>> _readRecordsUnlocked(
    File file,
  ) async {
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return <UploadHistoryRecord>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <UploadHistoryRecord>[];
    }

    return decoded
        .whereType<Map>()
        .map(
          (json) =>
              UploadHistoryRecord.fromJson(Map<String, dynamic>.from(json)),
        )
        .toList();
  }

  static Future<File> _ensureHistoryFile() async {
    final filePath = historyFilePath;
    if (filePath == null) {
      throw FileSystemException(
        'Unable to resolve upload history path because HOME is unset.',
      );
    }

    final directory = Directory(p.dirname(filePath));
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      file.writeAsStringSync('[]');
    }
    return file;
  }

  static Future<T> _withLock<T>(File file, Future<T> Function() action) async {
    final lockFile = File(p.join(file.parent.path, _lockFileName));
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
}
