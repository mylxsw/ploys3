import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ploys3/core/mcp/mcp_service.dart';

class McpServer {
  final McpService _service;
  HttpServer? _server;

  McpServer(this._service);

  bool get isRunning => _server != null;

  Future<void> start({required String host, required int port}) async {
    if (_server != null) {
      await stop();
    }
    _server = await HttpServer.bind(host, port);
    _server!.listen(_handleRequest, onError: (Object error, StackTrace stack) {
      debugPrint('MCP server error: $error');
    });
    debugPrint('MCP server listening on http://$host:$port');
  }

  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    request.response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
      ..set('Access-Control-Allow-Headers', 'Content-Type');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    if (request.method == 'POST' && path == '/mcp') {
      await _handleJsonRpc(request);
      return;
    }

    if (request.method == 'GET' && path == '/mcp/health') {
      await _writeJson(request.response, {'status': 'ok'});
      return;
    }

    if (request.method == 'GET' && path == '/mcp/tools') {
      final tools = _service.getToolDefinitions().map((tool) => tool.toJson()).toList();
      await _writeJson(request.response, {'tools': tools});
      return;
    }

    if (request.method == 'POST' && path == '/mcp/tools/call') {
      final body = await utf8.decoder.bind(request).join();
      final payload = body.isEmpty ? <String, dynamic>{} : json.decode(body) as Map<String, dynamic>;
      final name = payload['name'] as String?;
      final arguments = payload['arguments'] as Map<String, dynamic>? ?? <String, dynamic>{};

      if (name == null || name.isEmpty) {
        request.response.statusCode = HttpStatus.badRequest;
        await _writeJson(request.response, {'error': 'Tool name is required.'});
        return;
      }

      final result = await _service.callTool(name, arguments);
      await _writeJson(request.response, {'result': result.toJson()});
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    await _writeJson(request.response, {'error': 'Not found'});
  }

  Future<void> _handleJsonRpc(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    if (body.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      await _writeJson(request.response, {'error': 'Empty request body.'});
      return;
    }

    final payload = json.decode(body);
    if (payload is List) {
      final responses = <Map<String, dynamic>>[];
      for (final item in payload) {
        if (item is Map<String, dynamic>) {
          final response = await _handleJsonRpcMessage(item);
          if (response != null) {
            responses.add(response);
          }
        }
      }
      if (responses.isEmpty) {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }
      await _writeJson(request.response, responses);
      return;
    }

    if (payload is Map<String, dynamic>) {
      final response = await _handleJsonRpcMessage(payload);
      if (response == null) {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }
      await _writeJson(request.response, response);
      return;
    }

    request.response.statusCode = HttpStatus.badRequest;
    await _writeJson(request.response, {'error': 'Invalid JSON-RPC payload.'});
  }

  Future<Map<String, dynamic>?> _handleJsonRpcMessage(Map<String, dynamic> message) async {
    final id = message['id'];
    final jsonrpc = message['jsonrpc'];
    final method = message['method'] as String?;
    final params = message['params'] as Map<String, dynamic>? ?? <String, dynamic>{};

    if (jsonrpc != '2.0' || method == null || method.isEmpty) {
      return _jsonRpcError(id, -32600, 'Invalid Request');
    }

    switch (method) {
      case 'initialize':
        return _jsonRpcResult(id, {
          'protocolVersion': '2024-11-05',
          'capabilities': {
            'tools': {},
          },
          'serverInfo': {
            'name': 'S3 Manager MCP',
            'version': '1.0.0',
          },
        });
      case 'notifications/initialized':
        return null;
      case 'tools/list':
        final tools = _service.getToolDefinitions().map((tool) => tool.toJson()).toList();
        return _jsonRpcResult(id, {'tools': tools});
      case 'tools/call':
        final name = params['name'] as String?;
        final arguments = params['arguments'] as Map<String, dynamic>? ?? <String, dynamic>{};
        if (name == null || name.isEmpty) {
          return _jsonRpcError(id, -32602, 'Tool name is required.');
        }
        final result = await _service.callTool(name, arguments);
        return _jsonRpcResult(id, result.toJson());
      default:
        return _jsonRpcError(id, -32601, 'Method not found: $method');
    }
  }

  Map<String, dynamic> _jsonRpcResult(Object? id, Map<String, dynamic> result) {
    return {
      'jsonrpc': '2.0',
      'id': id,
      'result': result,
    };
  }

  Map<String, dynamic> _jsonRpcError(Object? id, int code, String message) {
    return {
      'jsonrpc': '2.0',
      'id': id,
      'error': {
        'code': code,
        'message': message,
      },
    };
  }

  Future<void> _writeJson(HttpResponse response, Object data) async {
    response.headers.contentType = ContentType.json;
    response.write(json.encode(data));
    await response.close();
  }
}
