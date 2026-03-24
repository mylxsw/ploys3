import 'dart:convert';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:ploys3/core/design_system.dart';
import 'package:ploys3/core/theme_manager.dart';
import 'package:ploys3/core/language_manager.dart';
import 'package:ploys3/core/localization.dart';
import 'package:ploys3/core/mcp/mcp_settings_manager.dart';
import 'package:ploys3/core/menubar_settings_manager.dart';
import 'package:ploys3/models/s3_server_config.dart';
import 'package:ploys3/core/cli_helper.dart';
import 'package:ploys3/core/platform.dart';
import 'package:ploys3/image_bed_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ploys3/widgets/window_title_bar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.onServerConfigsChanged});

  final VoidCallback? onServerConfigsChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppThemeMode _themeMode = AppThemeMode.system;
  AppLanguage _selectedLanguage = AppLanguage.chinese;
  bool _mcpEnabled = false;
  bool _menuBarEnabled = true;
  bool _quickUploadEnabled = true;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  final TextEditingController _mcpHostController = TextEditingController();
  final TextEditingController _mcpPortController = TextEditingController();

  @override
  void initState() {
    super.initState();
    McpSettingsManager.instance.initialize();
    MenuBarSettingsManager.instance.initialize();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _themeMode = ThemeManager.instance.themeMode;
      _selectedLanguage = LanguageManager.instance.currentLanguage;
      _mcpEnabled = McpSettingsManager.instance.enabled;
      _menuBarEnabled = MenuBarSettingsManager.instance.menuBarEnabled;
      _quickUploadEnabled = MenuBarSettingsManager.instance.quickUploadEnabled;
      _mcpHostController.text = McpSettingsManager.instance.host;
      _mcpPortController.text = McpSettingsManager.instance.port.toString();
    });
  }

  Future<void> _setMenuBarEnabled(bool enabled) async {
    await MenuBarSettingsManager.instance.setMenuBarEnabled(enabled);
    setState(() {
      _menuBarEnabled = enabled;
    });
  }

  Future<void> _setQuickUploadEnabled(bool enabled) async {
    await MenuBarSettingsManager.instance.setQuickUploadEnabled(enabled);
    setState(() {
      _quickUploadEnabled = enabled;
    });
  }

  Future<void> _setThemeMode(AppThemeMode mode) async {
    await ThemeManager.instance.setThemeMode(mode);
    setState(() {
      _themeMode = mode;
    });
  }

  Future<void> _setLanguage(AppLanguage language) async {
    await LanguageManager.instance.setLanguage(language);
    setState(() {
      _selectedLanguage = language;
    });
  }

  Future<void> _setMcpEnabled(bool enabled) async {
    await McpSettingsManager.instance.setEnabled(enabled);
    setState(() {
      _mcpEnabled = enabled;
    });
  }

  Future<void> _updateMcpHost(String value) async {
    await McpSettingsManager.instance.setHost(value);
  }

  Future<void> _updateMcpPort(String value) async {
    final port = int.tryParse(value);
    if (port != null) {
      await McpSettingsManager.instance.setPort(port);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _backupServerConfigs() async {
    if (_isBackingUp) return;
    final backupSuccessMessage = context.loc('backup_success');
    final backupFailedMessage = context.loc('backup_failed');

    setState(() {
      _isBackingUp = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final serverConfigStrings = prefs.getStringList('server_configs') ?? [];
      final serverConfigs = serverConfigStrings
          .map((item) => S3ServerConfig.fromJson(json.decode(item)))
          .map((config) => config.toJson())
          .toList();
      final backupPayload = <String, dynamic>{
        'format': 'ploys3-server-config-backup',
        'version': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'serverConfigs': serverConfigs,
      };
      final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(backupPayload)),
      );
      final now = DateTime.now();
      final fileName =
          'ploys3-backup-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

      await FileSaver.instance.saveAs(
        name: fileName,
        bytes: bytes,
        ext: 'ploys3',
        mimeType: MimeType.json,
      );

      _showMessage(backupSuccessMessage);
    } catch (_) {
      _showMessage(backupFailedMessage, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }

  Future<void> _restoreServerConfigs() async {
    if (_isRestoring) return;
    final restoreSuccessMessage = context.loc('restore_success');
    final restoreFailedMessage = context.loc('restore_failed');
    final restoreInvalidExtensionMessage = context.loc(
      'restore_invalid_extension',
    );
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.any,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final pickedFile = result.files.single;
    final fileName = pickedFile.name.toLowerCase();
    if (!fileName.endsWith('.ploys3')) {
      _showMessage(restoreInvalidExtensionMessage, isError: true);
      return;
    }

    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.loc('restore_confirm_title')),
        content: Text(context.loc('restore_confirm_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.loc('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.loc('restore_confirm_btn')),
          ),
        ],
      ),
    );
    if (shouldContinue != true) return;

    setState(() {
      _isRestoring = true;
    });

    try {
      final bytes = pickedFile.bytes;
      if (bytes == null || bytes.isEmpty) {
        _showMessage(restoreFailedMessage, isError: true);
        return;
      }

      final content = utf8.decode(bytes);
      final dynamic decoded = json.decode(content);

      final List<dynamic> rawConfigs;
      if (decoded is Map<String, dynamic> && decoded['serverConfigs'] is List) {
        rawConfigs = decoded['serverConfigs'] as List<dynamic>;
      } else if (decoded is List) {
        rawConfigs = decoded;
      } else {
        throw const FormatException('Invalid backup format');
      }

      final normalizedConfigs = rawConfigs.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid server config');
        }
        final config = S3ServerConfig.fromJson(item);
        return json.encode(config.toJson());
      }).toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('server_configs', normalizedConfigs);
      widget.onServerConfigsChanged?.call();
      _showMessage(restoreSuccessMessage);
    } catch (_) {
      _showMessage(restoreFailedMessage, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _mcpHostController.dispose();
    _mcpPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobilePlatform = const [
      TargetPlatform.iOS,
      TargetPlatform.android,
    ].contains(defaultTargetPlatform);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      body: WindowBorder(
        color: Colors.transparent,
        width: 0,
        child: Column(
          children: [
            const WindowTitleBar(),
            Expanded(
              child: Scaffold(
                appBar: AppBar(
                  title: Text(context.loc('settings')),
                  centerTitle: true,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                ),
                backgroundColor: Colors.transparent,
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: _buildSettingsContent(
                        context,
                        isMobile: isMobilePlatform,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsContent(BuildContext context, {required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 外观设置
        Text(
          context.loc('appearance_settings'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),

        // 主题模式选择
        _buildSettingCard(
          icon: Icons.dark_mode_outlined,
          title: context.loc('dark_mode'),
          subtitle: _getThemeModeDescription(),
          trailing: isMobile
              ? _buildThemeDropdown(context)
              : _buildThemeSegmentedButton(),
          isMobile: isMobile,
        ),

        const SizedBox(height: 24),

        // 语言设置
        Text(
          context.loc('language_settings'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),

        // 语言选择
        AppComponents.card(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(context.loc('language')),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioGroup<AppLanguage>(
                      groupValue: _selectedLanguage,
                      onChanged: (value) {
                        if (value == null) return;
                        _setLanguage(value);
                        Navigator.pop(context);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final language in AppLanguage.values)
                            RadioListTile<AppLanguage>(
                              title: Text(language.displayName),
                              value: language,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.loc('cancel_btn')),
                  ),
                ],
              ),
            );
          },
          child: Row(
            children: [
              Icon(
                Icons.language,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.loc('language'),
                      style: const TextStyle(
                        fontSize: AppFontSizes.lg,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedLanguage.displayName,
                      style: TextStyle(
                        fontSize: AppFontSizes.md,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 菜单栏设置（仅 macOS）
        if (Platform.isMacOS) ...[
          Text(
            context.loc('menubar_settings'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),

          _buildSettingCard(
            icon: Icons.menu,
            title: context.loc('menubar_enable'),
            subtitle: context.loc('menubar_enable_desc'),
            trailing: Switch.adaptive(
              value: _menuBarEnabled,
              onChanged: _setMenuBarEnabled,
            ),
            isMobile: isMobile,
          ),

          const SizedBox(height: 12),

          Opacity(
            opacity: _menuBarEnabled ? 1.0 : 0.5,
            child: _buildSettingCard(
              icon: Icons.upload_outlined,
              title: context.loc('quick_upload_enable'),
              subtitle: context.loc('quick_upload_enable_desc'),
              trailing: Switch.adaptive(
                value: _quickUploadEnabled,
                onChanged: _menuBarEnabled ? _setQuickUploadEnabled : null,
              ),
              isMobile: isMobile,
            ),
          ),

          const SizedBox(height: 24),
        ],

        // MCP 设置
        Text(
          context.loc('mcp_settings'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),

        _buildSettingCard(
          icon: Icons.hub_outlined,
          title: context.loc('mcp_enable'),
          subtitle: context.loc('mcp_enable_desc'),
          trailing: Switch.adaptive(
            value: _mcpEnabled,
            onChanged: _setMcpEnabled,
          ),
          isMobile: isMobile,
        ),

        const SizedBox(height: 12),

        _buildTextSettingCard(
          icon: Icons.lan_outlined,
          title: context.loc('mcp_host'),
          subtitle: context.loc('mcp_host_desc'),
          controller: _mcpHostController,
          isMobile: isMobile,
          onChanged: _updateMcpHost,
        ),

        const SizedBox(height: 12),

        _buildTextSettingCard(
          icon: Icons.swap_vert_circle_outlined,
          title: context.loc('mcp_port'),
          subtitle: context.loc('mcp_port_desc'),
          controller: _mcpPortController,
          isMobile: isMobile,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: _updateMcpPort,
        ),

        const SizedBox(height: 24),

        // 图床设置
        Text(
          context.loc('image_bed_settings'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),

        AppComponents.card(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const ImageBedSettingsPage(),
              ),
            );
          },
          child: Row(
            children: [
              Icon(
                Icons.image_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.loc('image_bed'),
                      style: const TextStyle(
                        fontSize: AppFontSizes.lg,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.loc('image_bed_settings_desc'),
                      style: TextStyle(
                        fontSize: AppFontSizes.md,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 命令行工具（仅桌面平台）
        if (Platform.isDesktop) ...[
          Text(
            context.loc('cli_settings'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),

          _buildSettingCard(
            icon: Icons.terminal,
            title: context.loc('cli_install'),
            subtitle: context.loc('cli_install_desc'),
            trailing: _buildCliInstallButton(context),
            isMobile: isMobile,
          ),

          const SizedBox(height: 12),

          _buildSettingCard(
            icon: Icons.folder_open,
            title: context.loc('cli_path'),
            subtitle: CliHelper.effectiveCliPath,
            trailing: IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: 'Copy',
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: CliHelper.effectiveCliPath),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            isMobile: isMobile,
          ),

          const SizedBox(height: 24),
        ],

        Text(
          context.loc('backup_restore_settings'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),

        _buildSettingCard(
          icon: Icons.backup_outlined,
          title: context.loc('backup_config'),
          subtitle: context.loc('backup_config_desc'),
          trailing: FilledButton(
            onPressed: _isBackingUp ? null : _backupServerConfigs,
            child: Text(context.loc('backup_btn')),
          ),
          isMobile: isMobile,
        ),

        const SizedBox(height: 12),

        _buildSettingCard(
          icon: Icons.restore_page_outlined,
          title: context.loc('restore_config'),
          subtitle: context.loc('restore_config_desc'),
          trailing: FilledButton(
            onPressed: _isRestoring ? null : _restoreServerConfigs,
            child: Text(context.loc('restore_btn')),
          ),
          isMobile: isMobile,
        ),

        const SizedBox(height: 24),

        // 关于
        Text(
          context.loc('about'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),

        AppComponents.card(
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'S3 Manager',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2026 S3 Manager by mylxsw',
            );
          },
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.loc('version'),
                      style: const TextStyle(
                        fontSize: AppFontSizes.lg,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '1.0.0',
                      style: TextStyle(
                        fontSize: AppFontSizes.md,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCliInstallButton(BuildContext context) {
    final isInstalled = CliHelper.isCliInstalled;
    if (isInstalled) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Text(
            context.loc('cli_installed'),
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final installFailedTemplate = context.loc('cli_install_failed');
              final uninstallSuccess = context.loc('cli_uninstall_success');

              final error = await CliHelper.uninstallCli();
              if (!mounted) return;
              if (error != null) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      installFailedTemplate.replaceFirst('%s', error),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(uninstallSuccess),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                setState(() {});
              }
            },
            child: Text(context.loc('cli_uninstall_btn')),
          ),
        ],
      );
    }
    return FilledButton(
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final installFailedTemplate = context.loc('cli_install_failed');
        final installSuccess = context.loc('cli_install_success');

        final error = await CliHelper.installCli();
        if (!mounted) return;
        if (error != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(installFailedTemplate.replaceFirst('%s', error)),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text(installSuccess),
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() {});
        }
      },
      child: Text(context.loc('cli_install_btn')),
    );
  }

  Widget _buildThemeDropdown(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<AppThemeMode>(
        value: _themeMode,
        isDense: true,
        onChanged: (value) {
          if (value != null) {
            _setThemeMode(value);
          }
        },
        items: [
          DropdownMenuItem(
            value: AppThemeMode.light,
            child: Text(context.loc('theme_light')),
          ),
          DropdownMenuItem(
            value: AppThemeMode.system,
            child: Text(context.loc('theme_system')),
          ),
          DropdownMenuItem(
            value: AppThemeMode.dark,
            child: Text(context.loc('theme_dark')),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSegmentedButton() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<AppThemeMode>(
          segments: [
            ButtonSegment(
              value: AppThemeMode.light,
              label: Text(context.loc('theme_light')),
              icon: Icon(Icons.light_mode),
            ),
            ButtonSegment(
              value: AppThemeMode.system,
              label: Text(context.loc('theme_system')),
              icon: Icon(Icons.auto_mode),
            ),
            ButtonSegment(
              value: AppThemeMode.dark,
              label: Text(context.loc('theme_dark')),
              icon: Icon(Icons.dark_mode),
            ),
          ],
          selected: {_themeMode},
          onSelectionChanged: (Set<AppThemeMode> newSelection) {
            if (newSelection.isNotEmpty) {
              _setThemeMode(newSelection.first);
            }
          },
        ),
      ],
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required bool isMobile,
  }) {
    return AppComponents.card(
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: AppFontSizes.lg,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: AppFontSizes.md,
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: trailing),
              ],
            )
          : Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: AppFontSizes.lg,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: AppFontSizes.md,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing,
              ],
            ),
    );
  }

  Widget _buildTextSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required bool isMobile,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final input = TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: subtitle,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      onChanged: onChanged,
    );

    return AppComponents.card(
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: AppFontSizes.lg,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: AppFontSizes.md,
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                input,
              ],
            )
          : Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: AppFontSizes.lg,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: AppFontSizes.md,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(width: 200, child: input),
              ],
            ),
    );
  }

  String _getThemeModeDescription() {
    switch (_themeMode) {
      case AppThemeMode.light:
        return 'Light theme always';
      case AppThemeMode.dark:
        return 'Dark theme always';
      case AppThemeMode.system:
        return 'Follow system setting';
    }
  }
}
