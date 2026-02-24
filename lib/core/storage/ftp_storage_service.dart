import 'dart:io';
import 'dart:typed_data';

import 'package:ftpconnect/ftpconnect.dart';
import 'package:path/path.dart' as p;
import 'package:ploys3/core/storage/storage_service.dart';
import 'package:ploys3/models/s3_server_config.dart';

class FtpStorageService implements StorageService {
  FtpStorageService(this._config);

  final S3ServerConfig _config;

  String get _host => _config.host.trim().isNotEmpty
      ? _config.host.trim()
      : _config.address.trim();
  int get _port => _config.port > 0 ? _config.port : 21;
  String get _username => _config.username.trim().isNotEmpty
      ? _config.username.trim()
      : 'anonymous';
  String get _password => _config.password;
  String get _rootPath => _normalizePath(_config.remotePath);

  String _normalizePath(String input) {
    var value = input.trim().replaceAll('\\', '/');
    if (value.isEmpty) return '/';
    if (!value.startsWith('/')) value = '/$value';
    return p.posix.normalize(value);
  }

  String _normalizeKey(String key) {
    var value = key.trim().replaceAll('\\', '/');
    value = value.replaceAll(RegExp(r'^/+'), '');
    return p.posix.normalize(value);
  }

  String _toAbsolute(String key) {
    final normalizedKey = _normalizeKey(key);
    if (normalizedKey.isEmpty || normalizedKey == '.') return _rootPath;
    if (_rootPath == '/') return '/$normalizedKey';
    return p.posix.join(_rootPath, normalizedKey);
  }

  Future<T> _withClient<T>(Future<T> Function(FTPConnect client) action) async {
    if (_host.isEmpty) {
      throw StateError('FTP host is required.');
    }

    final client = FTPConnect(
      _host,
      port: _port,
      user: _username,
      pass: _password,
      securityType: SecurityType.ftp,
      timeout: 20,
    );
    client.transferMode = TransferMode.passive;
    client.listCommand = ListCommand.mlsd;

    final ok = await client.connect();
    if (!ok) {
      throw StateError('Failed to connect FTP server.');
    }

    try {
      return await action(client);
    } finally {
      await client.disconnect();
    }
  }

  Future<void> _ensureDirectory(FTPConnect client, String absolutePath) async {
    final segments = absolutePath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    var current = '/';
    for (final segment in segments) {
      current = p.posix.join(current, segment);
      final changed = await client.changeDirectory(current);
      if (!changed) {
        await client.makeDirectory(current);
      }
    }
    await client.changeDirectory(_rootPath);
  }

  Future<Uint8List> _readAll(Stream<Uint8List> stream) async {
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      buffer.add(chunk);
    }
    return buffer.takeBytes();
  }

  @override
  String get id => _config.id;

  @override
  String get bucketName => _rootPath;

  @override
  Future<List<StorageItem>> listObjects({String? prefix}) async {
    return _withClient((client) async {
      final normalizedPrefix = _normalizeKey(prefix ?? '');
      final dirPath = _toAbsolute(normalizedPrefix);
      final changed = await client.changeDirectory(dirPath);
      if (!changed) return <StorageItem>[];

      final entries = await client.listDirectoryContent();
      await client.changeDirectory(_rootPath);

      return entries
          .where((entry) => entry.name != '.' && entry.name != '..')
          .map((entry) {
            final key = normalizedPrefix.isEmpty
                ? entry.name
                : '$normalizedPrefix/${entry.name}';
            if (entry.type == FTPEntryType.dir) {
              return StorageItem(
                key: '$key/',
                isDirectory: true,
                lastModified: entry.modifyTime,
              );
            }
            return StorageItem(
              key: key,
              isDirectory: false,
              size: entry.size,
              lastModified: entry.modifyTime,
            );
          })
          .toList();
    });
  }

  @override
  Future<void> createFolder(String folderPath) async {
    await _withClient((client) async {
      await _ensureDirectory(client, _toAbsolute(folderPath));
    });
  }

  @override
  Future<void> deleteObject(String key) async {
    await _withClient((client) async {
      await client.deleteFile(_toAbsolute(key));
    });
  }

  @override
  Future<void> deleteFolder(String folderPath) async {
    await _withClient((client) async {
      await client.deleteDirectory(_toAbsolute(folderPath));
    });
  }

  @override
  Future<void> renameObject(String oldKey, String newKey) async {
    await _withClient((client) async {
      final newPath = _toAbsolute(newKey);
      await _ensureDirectory(client, p.posix.dirname(newPath));
      await client.rename(_toAbsolute(oldKey), newPath);
    });
  }

  @override
  Future<Stream<Uint8List>> downloadStream(String key) async {
    return _withClient((client) async {
      final tmpDir = await Directory.systemTemp.createTemp(
        'ploys3-ftp-download-',
      );
      final file = File(p.join(tmpDir.path, p.basename(_normalizeKey(key))));
      final ok = await client.downloadFile(_toAbsolute(key), file);
      if (!ok) {
        throw StateError('FTP download failed: $key');
      }
      final bytes = await file.readAsBytes();
      await tmpDir.delete(recursive: true);
      return Stream<Uint8List>.value(bytes);
    });
  }

  @override
  Future<void> uploadStream(
    String key,
    Stream<Uint8List> stream, {
    int? size,
    String? contentType,
  }) async {
    await _withClient((client) async {
      final bytes = await _readAll(stream);
      final tmpDir = await Directory.systemTemp.createTemp(
        'ploys3-ftp-upload-',
      );
      final file = File(p.join(tmpDir.path, p.basename(_normalizeKey(key))));
      await file.writeAsBytes(bytes, flush: true);
      final target = _toAbsolute(key);
      await _ensureDirectory(client, p.posix.dirname(target));
      final ok = await client.uploadFile(file, sRemoteName: target);
      await tmpDir.delete(recursive: true);
      if (!ok) {
        throw StateError('FTP upload failed: $key');
      }
    });
  }

  @override
  String getFileUrl(String key) {
    final target = _toAbsolute(key);
    return 'ftp://$_host:$_port$target';
  }

  @override
  Future<void> testConnection() async {
    await _withClient((client) async {
      final changed = await client.changeDirectory(_rootPath);
      if (!changed) {
        throw StateError('FTP remote path not accessible: $_rootPath');
      }
      await client.listDirectoryContentOnlyNames();
    });
  }
}
