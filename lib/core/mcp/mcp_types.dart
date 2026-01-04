class McpToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  const McpToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'inputSchema': inputSchema,
    };
  }
}

class McpToolResult {
  final bool isError;
  final List<Map<String, dynamic>> content;

  const McpToolResult({required this.isError, required this.content});

  Map<String, dynamic> toJson() {
    return {
      'isError': isError,
      'content': content,
    };
  }
}
