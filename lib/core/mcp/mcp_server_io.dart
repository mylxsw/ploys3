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

  Future<void> _writeJson(HttpResponse response, Map<String, dynamic> data) async {
    response.headers.contentType = ContentType.json;
    response.write(json.encode(data));
    await response.close();
  }
}
