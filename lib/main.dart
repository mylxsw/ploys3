import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:s3_ui/models/s3_server_config.dart';
import 'package:s3_ui/s3_config_page.dart';
import 'package:s3_ui/s3_browser_page.dart';
import 'package:s3_ui/r2_test_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'S3 UI',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF1F1F1F),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        dividerColor: Colors.grey[800],
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: Colors.white70),
        ),
      ),
      home: const MyHomePage(title: 'S3 UI'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<S3ServerConfig> _serverConfigs = [];
  S3ServerConfig? _selectedServerConfig;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> serverConfigsStrings = prefs.getStringList('server_configs') ?? [];
    setState(() {
      _serverConfigs = serverConfigsStrings
          .map((config) => S3ServerConfig.fromJson(json.decode(config)))
          .toList();
    });
  }

  Future<void> _editServer(S3ServerConfig server) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => S3ConfigPage(
          onSave: _loadConfigs,
          existingConfig: server,
        ),
      ),
    );
  }

  Future<void> _testConnection(S3ServerConfig server) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => R2TestPage(serverConfig: server),
      ),
    );
  }

  Future<void> _deleteServer(S3ServerConfig server) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Server'),
        content: Text('Are you sure you want to delete "${server.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      final List<String> serverConfigsStrings = prefs.getStringList('server_configs') ?? [];

      // Remove the server from the list
      serverConfigsStrings.removeWhere((configString) {
        final config = S3ServerConfig.fromJson(json.decode(configString));
        return config.id == server.id;
      });

      await prefs.setStringList('server_configs', serverConfigsStrings);

      // If the deleted server was selected, clear the selection
      if (_selectedServerConfig?.id == server.id) {
        setState(() {
          _selectedServerConfig = null;
        });
      }

      _loadConfigs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 250,
            color: const Color(0xFF1E1E1E),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
                  child: Text(
                    'S3 Servers',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.add, color: Colors.white70),
                  title: const Text('Add S3 Server'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => S3ConfigPage(onSave: _loadConfigs),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _serverConfigs.length,
                    itemBuilder: (context, index) {
                      final server = _serverConfigs[index];
                      return ListTile(
                        leading: const Icon(Icons.cloud_queue_outlined, color: Colors.white70),
                        title: Text(server.name),
                        selected: _selectedServerConfig?.id == server.id,
                        selectedTileColor: Colors.grey[800],
                        onTap: () {
                          setState(() {
                            _selectedServerConfig = server;
                          });
                        },
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editServer(server);
                            } else if (value == 'delete') {
                              _deleteServer(server);
                            } else if (value == 'test') {
                              _testConnection(server);
                            }
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'test',
                              child: Text('Test Connection'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: _selectedServerConfig != null
                ? S3BrowserPage(serverConfig: _selectedServerConfig!)
                : Container(
                    color: const Color(0xFF252526),
                    child: Center(
                      child: Text(
                        'Select a server to view its content',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
