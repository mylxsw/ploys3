import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:ploys3/core/storage/storage_service.dart';
import 'package:ploys3/models/s3_server_config.dart';

class LocalFileStorageService implements StorageService {
  LocalFileStorageService(this._config);

  final S3ServerConfig _config;

  String get _rootPath {
    final path = _config.localPath.trim().isNotEmpty
        ? _config.localPath.trim()
        : _config.address.trim();
    if (path.isEmpty) {
      throw StateError('Local path is required.');
    }
    return p.normalize(path);
  }

  String _normalizeKey(String key) {
    var value = key.trim().replaceAll('\\', '/');
    value = value.replaceAll(RegExp(r'^/+'), '');
    return value;
  }

  String _joinRoot(String key) {
    final normalizedKey = _normalizeKey(key);
    if (normalizedKey.isEmpty) return _rootPath;
    return p.normalize(p.join(_rootPath, normalizedKey));
  }

  @override
  String get id => _config.id;

  @override
  String get bucketName => p.basename(_rootPath);

  @override
  Future<List<StorageItem>> listObjects({String? prefix}) async {
    final normalizedPrefix = _normalizeKey(prefix ?? '');
    final targetDir = Directory(_joinRoot(normalizedPrefix));
    if (!await targetDir.exists()) {
      return [];
    }

    final entities = await targetDir.list(followLinks: false).toList();
    final items = <StorageItem>[];
    for (final entity in entities) {
      final name = p.basename(entity.path);
      if (name == '.' || name == '..') continue;

      final key = normalizedPrefix.isEmpty ? name : '$normalizedPrefix/$name';
      if (entity is Directory) {
        items.add(StorageItem(key: '$key/', isDirectory: true));
      } else if (entity is File) {
        final stat = await entity.stat();
        items.add(
          StorageItem(
            key: key,
            isDirectory: false,
            size: stat.size,
            lastModified: stat.modified,
          ),
        );
      }
    }

    return items;
  }

  @override
  Future<void> createFolder(String folderPath) async {
    final dir = Directory(_joinRoot(folderPath));
    await dir.create(recursive: true);
  }

  @override
  Future<void> deleteObject(String key) async {
    final file = File(_joinRoot(key));
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> deleteFolder(String folderPath) async {
    final dir = Directory(_joinRoot(folderPath));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  @override
  Future<void> renameObject(String oldKey, String newKey) async {
    final oldPath = _joinRoot(oldKey);
    final newPath = _joinRoot(newKey);
    await Directory(p.dirname(newPath)).create(recursive: true);

    final oldFile = File(oldPath);
    if (await oldFile.exists()) {
      await oldFile.rename(newPath);
      return;
    }

    final oldDir = Directory(oldPath);
    if (await oldDir.exists()) {
      await oldDir.rename(newPath);
      return;
    }

    throw StateError('Path not found: $oldKey');
  }

  @override
  Future<Stream<Uint8List>> downloadStream(String key) async {
    final file = File(_joinRoot(key));
    if (!await file.exists()) {
      throw StateError('File not found: $key');
    }
    return file.openRead().cast<Uint8List>();
  }

  @override
  Future<void> uploadStream(
    String key,
    Stream<Uint8List> stream, {
    int? size,
    String? contentType,
  }) async {
    final file = File(_joinRoot(key));
    await Directory(p.dirname(file.path)).create(recursive: true);
    final sink = file.openWrite();
    await sink.addStream(stream);
    await sink.flush();
    await sink.close();
  }

  @override
  String getFileUrl(String key) {
    final fullPath = _joinRoot(key);
    return Uri.file(fullPath).toString();
  }

  @override
  Future<void> testConnection() async {
    final root = Directory(_rootPath);
    if (!await root.exists()) {
      throw StateError('Local path does not exist: $_rootPath');
    }
    await root.list(followLinks: false).take(1).toList();
  }
}
