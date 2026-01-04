import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ploys3/core/mcp/mcp_server.dart';
import 'package:ploys3/core/mcp/mcp_service.dart';

class McpSettingsManager extends ChangeNotifier {
  static McpSettingsManager? _instance;
  static McpSettingsManager get instance => _instance ??= McpSettingsManager._internal();

  McpSettingsManager._internal();

  static const String _enabledKey = 'mcp_enabled';
  static const String _hostKey = 'mcp_host';
  static const String _portKey = 'mcp_port';

  final McpServer _server = McpServer(McpService());

  bool _initialized = false;
  bool _enabled = false;
  String _host = '127.0.0.1';
  int _port = 8040;

  bool get enabled => _enabled;
  String get host => _host;
  int get port => _port;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await _loadSettings();
    await _applyServerState();
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    await _saveSetting(_enabledKey, enabled);
    await _applyServerState();
    notifyListeners();
  }

  Future<void> setHost(String host) async {
    final trimmed = host.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _host = trimmed;
    await _saveSetting(_hostKey, trimmed);
    await _restartIfRunning();
    notifyListeners();
  }

  Future<void> setPort(int port) async {
    if (port < 1 || port > 65535) {
      return;
    }
    _port = port;
    await _saveSetting(_portKey, port);
    await _restartIfRunning();
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    _host = prefs.getString(_hostKey) ?? _host;
    _port = prefs.getInt(_portKey) ?? _port;
    notifyListeners();
  }

  Future<void> _saveSetting(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _applyServerState() async {
    if (!_enabled) {
      await _server.stop();
      return;
    }
    try {
      await _server.start(host: _host, port: _port);
    } catch (error) {
      debugPrint('Failed to start MCP server: $error');
    }
  }

  Future<void> _restartIfRunning() async {
    if (_enabled) {
      await _applyServerState();
    }
  }
}
