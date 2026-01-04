import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ploys3/core/design_system.dart';
import 'package:ploys3/core/theme_manager.dart';
import 'package:ploys3/core/language_manager.dart';
import 'package:ploys3/core/localization.dart';
import 'package:ploys3/core/mcp/mcp_settings_manager.dart';

import 'package:ploys3/widgets/window_title_bar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppThemeMode _themeMode = AppThemeMode.system;
  AppLanguage _selectedLanguage = AppLanguage.chinese;
  bool _mcpEnabled = false;
  final TextEditingController _mcpHostController = TextEditingController();
  final TextEditingController _mcpPortController = TextEditingController();

  @override
  void initState() {
    super.initState();
    McpSettingsManager.instance.initialize();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _themeMode = ThemeManager.instance.themeMode;
      _selectedLanguage = LanguageManager.instance.currentLanguage;
      _mcpEnabled = McpSettingsManager.instance.enabled;
      _mcpHostController.text = McpSettingsManager.instance.host;
      _mcpPortController.text = McpSettingsManager.instance.port.toString();
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

  @override
  void dispose() {
    _mcpHostController.dispose();
    _mcpPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobilePlatform = const [TargetPlatform.iOS, TargetPlatform.android].contains(defaultTargetPlatform);

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
                      child: _buildSettingsContent(context, isMobile: isMobilePlatform),
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 8),

        // 主题模式选择
        _buildSettingCard(
          icon: Icons.dark_mode_outlined,
          title: context.loc('dark_mode'),
          subtitle: _getThemeModeDescription(),
          trailing: isMobile ? _buildThemeDropdown(context) : _buildThemeSegmentedButton(),
          isMobile: isMobile,
        ),

        const SizedBox(height: 24),

        // 语言设置
        Text(
          context.loc('language_settings'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
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
                    for (final language in AppLanguage.values)
                      RadioListTile<AppLanguage>(
                        title: Text(language.displayName),
                        value: language,
                        groupValue: _selectedLanguage,
                        onChanged: (value) {
                          if (value != null) {
                            _setLanguage(value);
                            Navigator.pop(context);
                          }
                        },
                      ),
                  ],
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(context.loc('cancel_btn')))],
              ),
            );
          },
          child: Row(
            children: [
              Icon(Icons.language, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.loc('language'),
                      style: const TextStyle(fontSize: AppFontSizes.lg, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedLanguage.displayName,
                      style: TextStyle(fontSize: AppFontSizes.md, color: Theme.of(context).textTheme.bodySmall?.color),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // MCP 设置
        Text(
          context.loc('mcp_settings'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
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

        // 关于
        Text(
          context.loc('about'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
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
              Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.loc('version'),
                      style: const TextStyle(fontSize: AppFontSizes.lg, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '1.0.0',
                      style: TextStyle(fontSize: AppFontSizes.md, color: Theme.of(context).textTheme.bodySmall?.color),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ],
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
          DropdownMenuItem(value: AppThemeMode.light, child: Text(context.loc('theme_light'))),
          DropdownMenuItem(value: AppThemeMode.system, child: Text(context.loc('theme_system'))),
          DropdownMenuItem(value: AppThemeMode.dark, child: Text(context.loc('theme_dark'))),
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
            ButtonSegment(value: AppThemeMode.light, label: Text(context.loc('theme_light')), icon: Icon(Icons.light_mode)),
            ButtonSegment(value: AppThemeMode.system, label: Text(context.loc('theme_system')), icon: Icon(Icons.auto_mode)),
            ButtonSegment(value: AppThemeMode.dark, label: Text(context.loc('theme_dark')), icon: Icon(Icons.dark_mode)),
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
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontSize: AppFontSizes.lg, fontWeight: FontWeight.w500),
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
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: AppFontSizes.lg, fontWeight: FontWeight.w500),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontSize: AppFontSizes.lg, fontWeight: FontWeight.w500),
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
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: AppFontSizes.lg, fontWeight: FontWeight.w500),
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
