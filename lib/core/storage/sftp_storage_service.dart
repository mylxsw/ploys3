import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;
import 'package:ploys3/core/storage/storage_service.dart';
import 'package:ploys3/models/s3_server_config.dart';

class SftpStorageService implements StorageService {
  SftpStorageService(this._config);

  final S3ServerConfig _config;

  String get _host => _config.host.trim().isNotEmpty
      ? _config.host.trim()
      : _config.address.trim();
  int get _port => _config.port > 0 ? _config.port : 22;
  String get _username => _config.username.trim();
  String get _password => _config.password;
  String get _privateKey => _config.privateKey;
  String get _rootPath => _normalizeRemotePath(_config.remotePath);

  String _normalizeRemotePath(String input) {
    var value = input.trim().replaceAll('\\', '/');
    if (value.isEmpty) return '.';
    if (!value.startsWith('/')) {
      value = '/$value';
    }
    value = p.posix.normalize(value);
    return value;
  }

  String _normalizeKey(String key) {
    var value = key.trim().replaceAll('\\', '/');
    value = value.replaceAll(RegExp(r'^/+'), '');
    if (value.isEmpty || value == '.') return '';
    return p.posix.normalize(value);
  }

  String _toRemotePath(String key) {
    final normalizedKey = _normalizeKey(key);
    if (normalizedKey.isEmpty || normalizedKey == '.') {
      return _rootPath;
    }
    if (_rootPath == '.') {
      return normalizedKey;
    }
    if (_rootPath == '/') {
      return p.posix.join('/', normalizedKey);
    }
    return p.posix.join(_rootPath, normalizedKey);
  }

  DateTime? _mtimeToDateTime(int? seconds) {
    if (seconds == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  Future<T> _withSftp<T>(Future<T> Function(SftpClient sftp) action) async {
    if (_host.isEmpty || _username.isEmpty) {
      throw StateError('SSH host and username are required.');
    }

    final socket = await SSHSocket.connect(_host, _port);

    final useKeyAuth = _privateKey.trim().isNotEmpty;
    final client = SSHClient(
      socket,
      username: _username,
      onPasswordRequest: useKeyAuth ? null : () => _password,
      identities: useKeyAuth
          ? SSHKeyPair.fromPem(_privateKey)
          : null,
      disableHostkeyVerification: true,
    );

    try {
      await client.authenticated;
      final sftp = await client.sftp();
      return await action(sftp);
    } finally {
      client.close();
    }
  }

  Future<void> _mkdirRecursive(SftpClient sftp, String remotePath) async {
    final normalized = p.posix.normalize(remotePath);
    if (normalized == '/' || normalized == '.') return;

    final segments = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    var current = normalized.startsWith('/') ? '/' : '.';
    for (final segment in segments) {
      current = current == '/' ? '/$segment' : p.posix.join(current, segment);
      try {
        await sftp.mkdir(current);
      } catch (_) {
        // ignore if already exists
      }
    }
  }

  Future<void> _deleteDirRecursive(SftpClient sftp, String remotePath) async {
    final children = await sftp.listdir(remotePath);
    for (final child in children) {
      final name = child.filename;
      if (name == '.' || name == '..') continue;
      final childPath = p.posix.join(remotePath, name);
      if (child.attr.isDirectory) {
        await _deleteDirRecursive(sftp, childPath);
        await sftp.rmdir(childPath);
      } else {
        await sftp.remove(childPath);
      }
    }
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
    return _withSftp((sftp) async {
      final normalizedPrefix = _normalizeKey(prefix ?? '');
      final target = _toRemotePath(normalizedPrefix);
      final names = await sftp.listdir(target);
      final items = <StorageItem>[];
      for (final item in names) {
        if (item.filename == '.' || item.filename == '..') continue;
        final key = normalizedPrefix.isEmpty
            ? item.filename
            : '$normalizedPrefix/${item.filename}';
        var isDirectory =
            item.attr.isDirectory || item.longname.startsWith('d');
        // For symlinks, stat the target to check if it's a directory
        if (!isDirectory && item.longname.startsWith('l')) {
          try {
            final childPath = target == '.'
                ? item.filename
                : p.posix.join(target, item.filename);
            final stat = await sftp.stat(childPath);
            isDirectory = stat.isDirectory;
          } catch (_) {
            // Broken symlink or permission error, treat as file
          }
        }
        if (isDirectory) {
          items.add(StorageItem(
            key: '$key/',
            isDirectory: true,
            lastModified: _mtimeToDateTime(item.attr.modifyTime),
          ));
        } else {
          items.add(StorageItem(
            key: key,
            isDirectory: false,
            size: item.attr.size,
            lastModified: _mtimeToDateTime(item.attr.modifyTime),
          ));
        }
      }
      return items;
    });
  }

  @override
  Future<void> createFolder(String folderPath) async {
    await _withSftp((sftp) async {
      await _mkdirRecursive(sftp, _toRemotePath(folderPath));
    });
  }

  @override
  Future<void> deleteObject(String key) async {
    await _withSftp((sftp) async {
      await sftp.remove(_toRemotePath(key));
    });
  }

  @override
  Future<void> deleteFolder(String folderPath) async {
    await _withSftp((sftp) async {
      final target = _toRemotePath(folderPath);
      await _deleteDirRecursive(sftp, target);
      await sftp.rmdir(target);
    });
  }

  @override
  Future<void> renameObject(String oldKey, String newKey) async {
    await _withSftp((sftp) async {
      final newPath = _toRemotePath(newKey);
      await _mkdirRecursive(sftp, p.posix.dirname(newPath));
      await sftp.rename(_toRemotePath(oldKey), newPath);
    });
  }

  @override
  Future<Stream<Uint8List>> downloadStream(String key) async {
    return _withSftp((sftp) async {
      final file = await sftp.open(
        _toRemotePath(key),
        mode: SftpFileOpenMode.read,
      );
      try {
        final bytes = await file.readBytes();
        return Stream<Uint8List>.value(bytes);
      } finally {
        await file.close();
      }
    });
  }

  @override
  Future<void> uploadStream(
    String key,
    Stream<Uint8List> stream, {
    int? size,
    String? contentType,
  }) async {
    await _withSftp((sftp) async {
      final bytes = await _readAll(stream);
      final remotePath = _toRemotePath(key);
      await _mkdirRecursive(sftp, p.posix.dirname(remotePath));
      final file = await sftp.open(
        remotePath,
        mode:
            SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.truncate,
      );
      try {
        await file.writeBytes(bytes);
      } finally {
        await file.close();
      }
    });
  }

  @override
  String getFileUrl(String key) {
    final path = _toRemotePath(key);
    return 'sftp://$_host:$_port$path';
  }

  @override
  Future<void> testConnection() async {
    await _withSftp((sftp) async {
      await sftp.listdir(_rootPath);
    });
  }
}
