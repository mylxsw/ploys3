import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:ploys3/core/mcp/mcp_types.dart';
import 'package:ploys3/core/storage/s3_storage_service.dart';
import 'package:ploys3/models/s3_server_config.dart';

class McpService {
  static const String _serverConfigsKey = 'server_configs';

  List<McpToolDefinition> getToolDefinitions() {
    return const [
      McpToolDefinition(
        name: 'list_servers',
        description: 'List configured S3 servers.',
        inputSchema: {'type': 'object', 'properties': {}},
      ),
      McpToolDefinition(
        name: 'list_objects',
        description: 'List objects in a bucket or prefix.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'serverId': {'type': 'string', 'description': 'Configured server id.'},
            'prefix': {'type': 'string', 'description': 'Optional prefix to list.'},
          },
          'required': ['serverId'],
        },
      ),
      McpToolDefinition(
        name: 'create_folder',
        description: 'Create a folder in the configured bucket.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'serverId': {'type': 'string', 'description': 'Configured server id.'},
            'folderPath': {'type': 'string', 'description': 'Folder path, ending with / is optional.'},
          },
          'required': ['serverId', 'folderPath'],
        },
      ),
      McpToolDefinition(
        name: 'delete_object',
        description: 'Delete an object from the bucket.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'serverId': {'type': 'string', 'description': 'Configured server id.'},
            'key': {'type': 'string', 'description': 'Object key to delete.'},
          },
          'required': ['serverId', 'key'],
        },
      ),
      McpToolDefinition(
        name: 'delete_folder',
        description: 'Delete a folder and its contents.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'serverId': {'type': 'string', 'description': 'Configured server id.'},
            'folderPath': {'type': 'string', 'description': 'Folder prefix to delete.'},
          },
          'required': ['serverId', 'folderPath'],
        },
      ),
      McpToolDefinition(
        name: 'rename_object',
        description: 'Rename or move an object.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'serverId': {'type': 'string', 'description': 'Configured server id.'},
            'oldKey': {'type': 'string', 'description': 'Existing object key.'},
            'newKey': {'type': 'string', 'description': 'New object key.'},
          },
          'required': ['serverId', 'oldKey', 'newKey'],
        },
      ),
      McpToolDefinition(
        name: 'get_file_url',
        description: 'Get a public URL for an object.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'serverId': {'type': 'string', 'description': 'Configured server id.'},
            'key': {'type': 'string', 'description': 'Object key.'},
          },
          'required': ['serverId', 'key'],
        },
      ),
      McpToolDefinition(
        name: 'test_connection',
        description: 'Test connectivity to the configured server.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'serverId': {'type': 'string', 'description': 'Configured server id.'},
          },
          'required': ['serverId'],
        },
      ),
    ];
  }

  Future<McpToolResult> callTool(String name, Map<String, dynamic> arguments) async {
    try {
      switch (name) {
        case 'list_servers':
          return _listServers();
        case 'list_objects':
          return _listObjects(arguments);
        case 'create_folder':
          return _createFolder(arguments);
        case 'delete_object':
          return _deleteObject(arguments);
        case 'delete_folder':
          return _deleteFolder(arguments);
        case 'rename_object':
          return _renameObject(arguments);
        case 'get_file_url':
          return _getFileUrl(arguments);
        case 'test_connection':
          return _testConnection(arguments);
        default:
          return _error('Unknown tool: $name');
      }
    } catch (error) {
      return _error('Tool error: $error');
    }
  }

  Future<McpToolResult> _listServers() async {
    final configs = await _loadConfigs();
    final servers = configs
        .map(
          (config) => {
            'id': config.id,
            'name': config.name,
            'address': config.address,
            'bucket': config.bucket,
            'region': config.region,
            'cdnUrl': config.cdnUrl,
          },
        )
        .toList();
    return _success(servers);
  }

  Future<McpToolResult> _listObjects(Map<String, dynamic> arguments) async {
    final config = await _getConfig(arguments);
    final prefix = arguments['prefix'] as String?;
    final service = S3StorageService(config);
    final objects = await service.listObjects(prefix: prefix);
    final results = objects
        .map(
          (item) => {
            'key': item.key,
            'isDirectory': item.isDirectory,
            'size': item.size,
            'lastModified': item.lastModified?.toIso8601String(),
            'eTag': item.eTag,
          },
        )
        .toList();
    return _success(results);
  }

  Future<McpToolResult> _createFolder(Map<String, dynamic> arguments) async {
    final config = await _getConfig(arguments);
    final folderPath = arguments['folderPath'] as String?;
    if (folderPath == null || folderPath.isEmpty) {
      return _error('folderPath is required.');
    }
    final service = S3StorageService(config);
    await service.createFolder(folderPath);
    return _success({'status': 'ok', 'folderPath': folderPath});
  }

  Future<McpToolResult> _deleteObject(Map<String, dynamic> arguments) async {
    final config = await _getConfig(arguments);
    final key = arguments['key'] as String?;
    if (key == null || key.isEmpty) {
      return _error('key is required.');
    }
    final service = S3StorageService(config);
    await service.deleteObject(key);
    return _success({'status': 'ok', 'key': key});
  }

  Future<McpToolResult> _deleteFolder(Map<String, dynamic> arguments) async {
    final config = await _getConfig(arguments);
    final folderPath = arguments['folderPath'] as String?;
    if (folderPath == null || folderPath.isEmpty) {
      return _error('folderPath is required.');
    }
    final service = S3StorageService(config);
    await service.deleteFolder(folderPath);
    return _success({'status': 'ok', 'folderPath': folderPath});
  }

  Future<McpToolResult> _renameObject(Map<String, dynamic> arguments) async {
    final config = await _getConfig(arguments);
    final oldKey = arguments['oldKey'] as String?;
    final newKey = arguments['newKey'] as String?;
    if (oldKey == null || oldKey.isEmpty || newKey == null || newKey.isEmpty) {
      return _error('oldKey and newKey are required.');
    }
    final service = S3StorageService(config);
    await service.renameObject(oldKey, newKey);
    return _success({'status': 'ok', 'oldKey': oldKey, 'newKey': newKey});
  }

  Future<McpToolResult> _getFileUrl(Map<String, dynamic> arguments) async {
    final config = await _getConfig(arguments);
    final key = arguments['key'] as String?;
    if (key == null || key.isEmpty) {
      return _error('key is required.');
    }
    final service = S3StorageService(config);
    final url = service.getFileUrl(key);
    return _success({'url': url});
  }

  Future<McpToolResult> _testConnection(Map<String, dynamic> arguments) async {
    final config = await _getConfig(arguments);
    final service = S3StorageService(config);
    await service.testConnection();
    return _success({'status': 'ok'});
  }

  Future<List<S3ServerConfig>> _loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final configs = prefs.getStringList(_serverConfigsKey) ?? [];
    return configs.map((config) => S3ServerConfig.fromJson(json.decode(config))).toList();
  }

  Future<S3ServerConfig> _getConfig(Map<String, dynamic> arguments) async {
    final serverId = arguments['serverId'] as String?;
    if (serverId == null || serverId.isEmpty) {
      throw StateError('serverId is required.');
    }
    final configs = await _loadConfigs();
    final config = configs.where((config) => config.id == serverId).toList();
    if (config.isEmpty) {
      throw StateError('Server not found for id: $serverId');
    }
    return config.first;
  }

  McpToolResult _success(dynamic data) {
    return McpToolResult(
      isError: false,
      content: [
        {'type': 'json', 'value': data},
      ],
    );
  }

  McpToolResult _error(String message) {
    return McpToolResult(
      isError: true,
      content: [
        {'type': 'text', 'text': message},
      ],
    );
  }
}
