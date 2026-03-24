import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ploys3/core/upload_history_store.dart';
import 'package:ploys3/models/upload_history_record.dart';

class UploadHistoryManager extends ChangeNotifier {
  static UploadHistoryManager? _instance;
  static UploadHistoryManager get instance =>
      _instance ??= UploadHistoryManager._internal();

  UploadHistoryManager._internal();

  static const String _storageKey = 'upload_history';

  List<UploadHistoryRecord> _records = [];
  bool _loaded = false;
  StreamSubscription<FileSystemEvent>? _watchSubscription;

  List<UploadHistoryRecord> get records => List.unmodifiable(_records);

  Future<void> loadHistory({bool forceRefresh = false}) async {
    if (_loaded && !forceRefresh) return;

    await _migrateLegacyPreferencesIfNeeded();
    _records = await UploadHistoryStore.readRecords();
    _records.sort((a, b) => b.uploadTime.compareTo(a.uploadTime));
    _loaded = true;
    _startWatchingSharedHistoryFile();
    notifyListeners();
  }

  Future<void> addRecord(UploadHistoryRecord record) async {
    await loadHistory();
    await UploadHistoryStore.appendRecord(record);
    await loadHistory(forceRefresh: true);
  }

  Future<void> deleteRecord(String id) async {
    _records.removeWhere((r) => r.id == id);
    await _persist();
    await loadHistory(forceRefresh: true);
  }

  Future<void> clearAll() async {
    _records.clear();
    await _persist();
    await loadHistory(forceRefresh: true);
  }

  Future<void> _persist() async {
    await UploadHistoryStore.writeRecords(_records);
  }

  Future<void> _migrateLegacyPreferencesIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final historyPath = UploadHistoryStore.historyFilePath;
    if (historyPath == null) return;

    final historyFile = File(historyPath);
    final hasSharedFile =
        historyFile.existsSync() &&
        historyFile.readAsStringSync().trim().isNotEmpty;
    if (hasSharedFile) {
      return;
    }

    final List<String> jsonList = prefs.getStringList(_storageKey) ?? [];
    if (jsonList.isEmpty) {
      return;
    }

    final records = jsonList
        .map((jsonStr) {
          try {
            return UploadHistoryRecord.fromJson(json.decode(jsonStr));
          } catch (_) {
            return null;
          }
        })
        .whereType<UploadHistoryRecord>()
        .toList();

    if (records.isEmpty) {
      return;
    }

    records.sort((a, b) => b.uploadTime.compareTo(a.uploadTime));
    await UploadHistoryStore.writeRecords(records);
  }

  void _startWatchingSharedHistoryFile() {
    if (_watchSubscription != null) return;

    final directoryPath = UploadHistoryStore.historyDirectoryPath;
    if (directoryPath == null) return;

    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    _watchSubscription = directory.watch().listen((event) {
      if (p.basename(event.path) != 'upload_history.json') {
        return;
      }
      unawaited(loadHistory(forceRefresh: true));
    });
  }
}
