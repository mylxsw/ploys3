import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:ploys3/core/design_system.dart';
import 'package:ploys3/core/localization.dart';
import 'package:ploys3/models/s3_server_config.dart';
import 'package:ploys3/s3_config_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ploys3/widgets/window_title_bar.dart';

enum ImageBedNamingRule { original, random }

class ImageBedSettingsPage extends StatefulWidget {
  const ImageBedSettingsPage({super.key});

  @override
  State<ImageBedSettingsPage> createState() => _ImageBedSettingsPageState();
}

class _ImageBedSettingsPageState extends State<ImageBedSettingsPage> {
  static const String _serverIdKey = 'image_bed_server_id';
  static const String _uploadDirKey = 'image_bed_upload_dir';
  static const String _namingRuleKey = 'image_bed_naming_rule';

  final TextEditingController _uploadDirController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<S3ServerConfig> _servers = [];
  String? _selectedServerId;
  ImageBedNamingRule _namingRule = ImageBedNamingRule.original;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _uploadDirController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> serverConfigsStrings =
        prefs.getStringList('server_configs') ?? [];
    final servers = serverConfigsStrings
        .map((config) => S3ServerConfig.fromJson(json.decode(config)))
        .toList();
    final savedServerId = prefs.getString(_serverIdKey);
    final uploadDir = prefs.getString(_uploadDirKey) ?? '';
    final namingRule = prefs.getString(_namingRuleKey);
    final rule = namingRule == 'random'
        ? ImageBedNamingRule.random
        : ImageBedNamingRule.original;

    setState(() {
      _servers = servers;
      _selectedServerId = servers.any((s) => s.id == savedServerId)
          ? savedServerId
          : null;
      _uploadDirController.text = uploadDir;
      _namingRule = rule;
    });
  }

  Future<void> _saveSettings() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_selectedServerId == null || _selectedServerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.loc('image_bed_choose_server_required')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final normalizedDir = _normalizeUploadDir(_uploadDirController.text);
    _uploadDirController.text = normalizedDir;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverIdKey, _selectedServerId ?? '');
    await prefs.setString(_uploadDirKey, normalizedDir);
    await prefs.setString(
      _namingRuleKey,
      _namingRule == ImageBedNamingRule.random ? 'random' : 'original',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.loc('success')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _openAddServer() async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            S3ConfigPage(onSave: _loadSettings),
      ),
    );
    await _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
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
                  title: Text(context.loc('image_bed_settings')),
                  centerTitle: true,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  actions: _servers.isEmpty
                      ? null
                      : [
                          TextButton.icon(
                            onPressed: _saveSettings,
                            label: Text(context.loc('save')),
                            icon: Icon(
                              Icons.save,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                ),
                backgroundColor: Colors.transparent,
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: _servers.isEmpty
                          ? _buildEmptyState(context)
                          : Form(key: _formKey, child: _buildEditor(context)),
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              context.loc('image_bed_no_server_title'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.loc('image_bed_no_server_desc'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            AppComponents.primaryButton(
              text: context.loc('image_bed_add_server'),
              icon: Icons.add,
              onPressed: _openAddServer,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.loc('image_bed_choose_server'),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedServerId,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            hintText: context.loc('image_bed_choose_server_hint'),
          ),
          items: _servers
              .map(
                (server) => DropdownMenuItem<String>(
                  value: server.id,
                  child: Text('${server.name} (${_serverLabel(server)})'),
                ),
              )
              .toList(),
          onChanged: (value) async {
            setState(() {
              _selectedServerId = value;
            });
          },
        ),
        const SizedBox(height: 20),
        Text(
          context.loc('image_bed_upload_dir'),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _uploadDirController,
          decoration: InputDecoration(
            hintText: context.loc('image_bed_upload_dir_hint'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          validator: _validateUploadDir,
        ),
        const SizedBox(height: 20),
        Text(
          context.loc('image_bed_naming_rule'),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        RadioGroup<ImageBedNamingRule>(
          groupValue: _namingRule,
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _namingRule = value;
            });
          },
          child: Column(
            children: [
              RadioListTile<ImageBedNamingRule>(
                value: ImageBedNamingRule.original,
                title: Text(context.loc('image_bed_keep_original')),
              ),
              RadioListTile<ImageBedNamingRule>(
                value: ImageBedNamingRule.random,
                title: Text(context.loc('image_bed_random_name')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _normalizeUploadDir(String input) {
    var value = input.trim();
    if (value.isEmpty) return '';
    value = value.replaceAll('\\', '/');
    value = value.replaceAll(RegExp(r'^/+'), '');
    value = value.replaceAll(RegExp(r'/+$'), '');
    return value;
  }

  String _serverLabel(S3ServerConfig server) {
    switch (server.type) {
      case ServerType.s3:
        return server.bucket;
      case ServerType.local:
        return server.localPath;
      case ServerType.ssh:
      case ServerType.ftp:
        final host = server.host.isNotEmpty ? server.host : server.address;
        return '$host:${server.port > 0 ? server.port : ''}';
    }
  }

  String? _validateUploadDir(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    if (text.contains(' ')) {
      return context.loc('image_bed_upload_dir_no_space');
    }
    if (text.contains(RegExp(r'[\u0000-\u001F]'))) {
      return context.loc('image_bed_upload_dir_invalid');
    }
    return null;
  }
}
