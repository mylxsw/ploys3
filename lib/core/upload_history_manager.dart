import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ploys3/models/upload_history_record.dart';

class UploadHistoryManager extends ChangeNotifier {
  static UploadHistoryManager? _instance;
  static UploadHistoryManager get instance =>
      _instance ??= UploadHistoryManager._internal();

  UploadHistoryManager._internal();

  static const String _storageKey = 'upload_history';

  List<UploadHistoryRecord> _records = [];
  bool _loaded = false;

  List<UploadHistoryRecord> get records => List.unmodifiable(_records);

  Future<void> loadHistory() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final List<String> jsonList = prefs.getStringList(_storageKey) ?? [];
    _records = jsonList
        .map((jsonStr) {
          try {
            return UploadHistoryRecord.fromJson(json.decode(jsonStr));
          } catch (_) {
            return null;
          }
        })
        .whereType<UploadHistoryRecord>()
        .toList();
    // Sort newest first
    _records.sort((a, b) => b.uploadTime.compareTo(a.uploadTime));
    _loaded = true;
    notifyListeners();
  }

  Future<void> addRecord(UploadHistoryRecord record) async {
    await loadHistory();
    _records.insert(0, record);
    await _persist();
    notifyListeners();
  }

  Future<void> deleteRecord(String id) async {
    _records.removeWhere((r) => r.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _records.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _records.map((r) => json.encode(r.toJson())).toList();
    await prefs.setStringList(_storageKey, jsonList);
  }
}
