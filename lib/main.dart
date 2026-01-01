import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:s3_ui/models/s3_server_config.dart';
import 'package:s3_ui/s3_config_page.dart';
import 'package:s3_ui/s3_browser_page.dart';
import 'package:s3_ui/settings_page.dart';
import 'package:s3_ui/core/design_system.dart';
import 'package:s3_ui/core/theme_manager.dart';
import 'package:s3_ui/core/language_manager.dart';
import 'package:s3_ui/core/localization.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 设置系统UI样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const App());
}

/// 主应用
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, child) {
        return MaterialApp(
          title: 'S3 Manager',
          theme: ThemeManager.instance.currentTheme,
          debugShowCheckedModeBanner: false,
          home: const LanguageProvider(
            child: ThemeProvider(
              child: AppShell(),
            ),
          ),
        );
      },
    );
  }
}

/// 应用外壳
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 左侧导航栏
          NavigationRail(
            extended: true,
            minExtendedWidth: 280,
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 2,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  // Logo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.secondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.cloud_outlined,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'S3',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            'MANAGER',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              letterSpacing: 2,
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // 添加服务器按钮
                  SizedBox(
                    width: 200,
                    child: AppComponents.primaryButton(
                      text: context.loc('add_new_server'),
                      icon: Icons.add,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => S3ConfigPage(onSave: _loadConfigs),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            destinations: [
              // 服务器列表
              ..._serverConfigs.map((server) {
                final isSelected = _selectedServerConfig?.id == server.id;
                return NavigationRailDestination(
                  icon: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: null, // Handled by NavigationRail
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.cloud_outlined,
                          size: 24,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                  selectedIcon: Material(
                    color: Colors.transparent,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.cloud_done,
                        size: 24,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  label: Text(
                    server.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                );
              }),
            ],
            trailing: Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 设置按钮
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsPage(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.settings_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                context.loc('settings'),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            onDestinationSelected: (index) {
              setState(() {
                _selectedServerConfig = _serverConfigs[index];
              });
            },
            selectedIndex: _selectedServerConfig != null && _serverConfigs.isNotEmpty
                ? _serverConfigs.indexWhere((s) => s.id == _selectedServerConfig!.id)
                : null,
          ),

          // 右侧内容区域
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: _selectedServerConfig != null
                  ? S3BrowserPage(serverConfig: _selectedServerConfig!)
                  : AppComponents.emptyState(
                      icon: Icons.cloud_off_outlined,
                      title: context.loc('no_server_selected'),
                      subtitle: context.loc('select_server_to_start'),
                      onAction: _serverConfigs.isEmpty
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => S3ConfigPage(onSave: _loadConfigs),
                                ),
                              );
                            }
                          : null,
                      actionText: _serverConfigs.isEmpty ? context.loc('add_new_server') : null,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}