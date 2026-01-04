class McpServer {
  McpServer(Object _);

  bool get isRunning => false;

  Future<void> start({required String host, required int port}) async {}

  Future<void> stop() async {}
}
