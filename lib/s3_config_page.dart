import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:ploys3/models/s3_server_config.dart';
import 'package:ploys3/core/localization.dart';
import 'package:ploys3/core/design_system.dart';

import 'package:ploys3/widgets/window_title_bar.dart';

class S3ConfigPage extends StatefulWidget {
  final VoidCallback onSave;
  final S3ServerConfig? existingConfig;

  const S3ConfigPage({super.key, required this.onSave, this.existingConfig});

  @override
  State<S3ConfigPage> createState() => _S3ConfigPageState();
}

class _S3ConfigPageState extends State<S3ConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  ServerType _selectedServerType = ServerType.s3;

  // S3
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _bucketController = TextEditingController();
  final TextEditingController _accessKeyIdController = TextEditingController();
  final TextEditingController _cdnUrlController = TextEditingController();
  final TextEditingController _secretAccessKeyController =
      TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  // Local
  final TextEditingController _localPathController = TextEditingController();
  // SSH/FTP
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _privateKeyController = TextEditingController();
  final TextEditingController _remotePathController = TextEditingController();
  bool _useKeyAuth = false;

  int _defaultPortForType(ServerType type) {
    return switch (type) {
      ServerType.ssh => 22,
      ServerType.ftp => 21,
      _ => 0,
    };
  }

  void _onServerTypeChanged(ServerType value) {
    final previousType = _selectedServerType;
    final previousDefaultPort = _defaultPortForType(previousType);
    final newDefaultPort = _defaultPortForType(value);
    final parsedCurrentPort = int.tryParse(_portController.text.trim()) ?? 0;

    setState(() {
      _selectedServerType = value;
      if ((parsedCurrentPort == 0 ||
              parsedCurrentPort == previousDefaultPort) &&
          (value == ServerType.ssh || value == ServerType.ftp)) {
        _portController.text = '$newDefaultPort';
      }
    });
  }

  Future<void> _pickLocalDirectory() async {
    final selected = await FilePicker.platform.getDirectoryPath();
    if (!mounted || selected == null || selected.isEmpty) {
      return;
    }
    setState(() {
      _localPathController.text = selected;
    });
  }

  Future<void> _pickPrivateKeyFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (!mounted || result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    try {
      final content = await File(filePath).readAsString();
      // Validate the key by attempting to parse it
      SSHKeyPair.fromPem(content);
      setState(() {
        _privateKeyController.text = content;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.loc('ssh_invalid_key_file')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _saveConfig() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      final List<String> serverConfigs =
          prefs.getStringList('server_configs') ?? [];

      if (widget.existingConfig != null) {
        // Editing existing config - preserve the ID
        final updatedConfig = S3ServerConfig(
          id: widget.existingConfig!.id,
          name: _nameController.text,
          serverType: _selectedServerType.value,
          address: _selectedServerType == ServerType.s3
              ? _addressController.text.trim()
              : '',
          bucket: _selectedServerType == ServerType.s3
              ? _bucketController.text.trim()
              : '',
          accessKeyId: _selectedServerType == ServerType.s3
              ? _accessKeyIdController.text.trim()
              : '',
          secretAccessKey: _selectedServerType == ServerType.s3
              ? _secretAccessKeyController.text.trim()
              : '',
          region:
              _selectedServerType == ServerType.s3 &&
                  _regionController.text.isNotEmpty
              ? _regionController.text.trim()
              : null,
          cdnUrl:
              _selectedServerType == ServerType.s3 &&
                  _cdnUrlController.text.isNotEmpty
              ? _cdnUrlController.text.trim()
              : null,
          localPath: _selectedServerType == ServerType.local
              ? _localPathController.text.trim()
              : '',
          host:
              _selectedServerType == ServerType.ssh ||
                  _selectedServerType == ServerType.ftp
              ? _hostController.text.trim()
              : '',
          port:
              _selectedServerType == ServerType.ssh ||
                  _selectedServerType == ServerType.ftp
              ? int.tryParse(_portController.text.trim()) ?? 0
              : 0,
          username:
              _selectedServerType == ServerType.ssh ||
                  _selectedServerType == ServerType.ftp
              ? _usernameController.text.trim()
              : '',
          password:
              (_selectedServerType == ServerType.ssh ||
                      _selectedServerType == ServerType.ftp) &&
                  !_useKeyAuth
              ? _passwordController.text
              : '',
          privateKey:
              _selectedServerType == ServerType.ssh && _useKeyAuth
              ? _privateKeyController.text
              : '',
          remotePath:
              _selectedServerType == ServerType.ssh ||
                  _selectedServerType == ServerType.ftp
              ? _remotePathController.text.trim()
              : '',
        );

        // Find and replace the existing config
        final index = serverConfigs.indexWhere((configString) {
          final config = S3ServerConfig.fromJson(json.decode(configString));
          return config.id == widget.existingConfig!.id;
        });

        if (index != -1) {
          serverConfigs[index] = json.encode(updatedConfig.toJson());
        }
      } else {
        // Creating new config
        final newConfig = S3ServerConfig(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text,
          serverType: _selectedServerType.value,
          address: _selectedServerType == ServerType.s3
              ? _addressController.text.trim()
              : '',
          bucket: _selectedServerType == ServerType.s3
              ? _bucketController.text.trim()
              : '',
          accessKeyId: _selectedServerType == ServerType.s3
              ? _accessKeyIdController.text.trim()
              : '',
          secretAccessKey: _selectedServerType == ServerType.s3
              ? _secretAccessKeyController.text.trim()
              : '',
          region:
              _selectedServerType == ServerType.s3 &&
                  _regionController.text.isNotEmpty
              ? _regionController.text.trim()
              : null,
          cdnUrl:
              _selectedServerType == ServerType.s3 &&
                  _cdnUrlController.text.isNotEmpty
              ? _cdnUrlController.text.trim()
              : null,
          localPath: _selectedServerType == ServerType.local
              ? _localPathController.text.trim()
              : '',
          host:
              _selectedServerType == ServerType.ssh ||
                  _selectedServerType == ServerType.ftp
              ? _hostController.text.trim()
              : '',
          port:
              _selectedServerType == ServerType.ssh ||
                  _selectedServerType == ServerType.ftp
              ? int.tryParse(_portController.text.trim()) ?? 0
              : 0,
          username:
              _selectedServerType == ServerType.ssh ||
                  _selectedServerType == ServerType.ftp
              ? _usernameController.text.trim()
              : '',
          password:
              (_selectedServerType == ServerType.ssh ||
                      _selectedServerType == ServerType.ftp) &&
                  !_useKeyAuth
              ? _passwordController.text
              : '',
          privateKey:
              _selectedServerType == ServerType.ssh && _useKeyAuth
              ? _privateKeyController.text
              : '',
          remotePath:
              _selectedServerType == ServerType.ssh ||
                  _selectedServerType == ServerType.ftp
              ? _remotePathController.text.trim()
              : '',
        );

        serverConfigs.add(json.encode(newConfig.toJson()));
      }

      await prefs.setStringList('server_configs', serverConfigs);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.loc('server_saved')),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onSave();
        Navigator.pop(context);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // If editing existing config, populate the fields
    if (widget.existingConfig != null) {
      _nameController.text = widget.existingConfig!.name;
      _selectedServerType = widget.existingConfig!.type;
      _addressController.text = widget.existingConfig!.address;
      _bucketController.text = widget.existingConfig!.bucket;
      _accessKeyIdController.text = widget.existingConfig!.accessKeyId;
      _secretAccessKeyController.text = widget.existingConfig!.secretAccessKey;
      _localPathController.text = widget.existingConfig!.localPath;
      _hostController.text = widget.existingConfig!.host;
      _portController.text = widget.existingConfig!.port > 0
          ? '${widget.existingConfig!.port}'
          : '';
      _usernameController.text = widget.existingConfig!.username;
      _passwordController.text = widget.existingConfig!.password;
      _privateKeyController.text = widget.existingConfig!.privateKey;
      _useKeyAuth = widget.existingConfig!.privateKey.isNotEmpty;
      _remotePathController.text = widget.existingConfig!.remotePath;
      if (widget.existingConfig!.region != null) {
        _regionController.text = widget.existingConfig!.region!;
      }
      if (widget.existingConfig!.cdnUrl != null) {
        _cdnUrlController.text = widget.existingConfig!.cdnUrl!;
      }
    } else {
      if (_selectedServerType == ServerType.ssh) {
        _portController.text = '22';
      } else if (_selectedServerType == ServerType.ftp) {
        _portController.text = '21';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _bucketController.dispose();
    _accessKeyIdController.dispose();
    _secretAccessKeyController.dispose();
    _regionController.dispose();
    _cdnUrlController.dispose();
    _localPathController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    _remotePathController.dispose();
    super.dispose();
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
                  title: Text(
                    widget.existingConfig != null
                        ? context.loc('title_edit_server')
                        : context.loc('title_add_server'),
                  ),
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  centerTitle: true,
                  actions: [
                    TextButton.icon(
                      onPressed: _saveConfig,
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
                body: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12.0,
                              ),
                              child: DropdownButtonFormField<ServerType>(
                                initialValue: _selectedServerType,
                                decoration: InputDecoration(
                                  labelText: context.loc('server_type'),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: ServerType.s3,
                                    child: Text(context.loc('server_type_s3')),
                                  ),
                                  if (Platform.isMacOS || Platform.isLinux || Platform.isWindows)
                                    DropdownMenuItem(
                                      value: ServerType.local,
                                      child: Text(
                                        context.loc('server_type_local'),
                                      ),
                                    ),
                                  DropdownMenuItem(
                                    value: ServerType.ssh,
                                    child: Text(context.loc('server_type_ssh')),
                                  ),
                                  DropdownMenuItem(
                                    value: ServerType.ftp,
                                    child: Text(context.loc('server_type_ftp')),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  _onServerTypeChanged(value);
                                },
                              ),
                            ),
                            _buildTextFormField(
                              context.loc('name'),
                              _nameController,
                              context.loc('name_hint'),
                            ),
                            ..._buildTypeFields(),
                          ],
                        ),
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

  List<Widget> _buildTypeFields() {
    switch (_selectedServerType) {
      case ServerType.s3:
        return [
          _buildTextFormField(
            context.loc('address'),
            _addressController,
            context.loc('address_hint'),
          ),
          _buildTextFormField(
            context.loc('bucket'),
            _bucketController,
            context.loc('bucket_hint'),
          ),
          _buildTextFormField(
            context.loc('access_key_id'),
            _accessKeyIdController,
            context.loc('access_key_hint'),
          ),
          _buildTextFormField(
            context.loc('secret_access_key'),
            _secretAccessKeyController,
            context.loc('secret_key_hint'),
            obscureText: true,
          ),
          _buildTextFormField(
            context.loc('region'),
            _regionController,
            context.loc('region_hint'),
            isOptional: true,
          ),
          _buildTextFormField(
            context.loc('cdn_url'),
            _cdnUrlController,
            context.loc('cdn_hint'),
            isOptional: true,
          ),
        ];
      case ServerType.local:
        return [
          _buildTextFormField(
            context.loc('local_path'),
            _localPathController,
            context.loc('local_path_hint'),
            suffixIcon: IconButton(
              onPressed: _pickLocalDirectory,
              tooltip: context.loc('pick_directory'),
              icon: const Icon(Icons.folder_open),
            ),
          ),
        ];
      case ServerType.ssh:
      case ServerType.ftp:
        return [
          _buildTextFormField(
            context.loc('server_host'),
            _hostController,
            context.loc('server_host_hint'),
          ),
          _buildTextFormField(
            context.loc('server_port'),
            _portController,
            _selectedServerType == ServerType.ssh ? '22' : '21',
            keyboardType: TextInputType.number,
          ),
          _buildTextFormField(
            context.loc('server_username'),
            _usernameController,
            context.loc('server_username_hint'),
          ),
          if (_selectedServerType == ServerType.ssh)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Row(
                children: [
                  Text(
                    context.loc('ssh_auth_type'),
                    style: const TextStyle(fontSize: AppFontSizes.md),
                  ),
                  const SizedBox(width: 16),
                  ChoiceChip(
                    label: Text(context.loc('ssh_auth_password')),
                    selected: !_useKeyAuth,
                    onSelected: (_) => setState(() => _useKeyAuth = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(context.loc('ssh_auth_key')),
                    selected: _useKeyAuth,
                    onSelected: (_) => setState(() => _useKeyAuth = true),
                  ),
                ],
              ),
            ),
          if (_selectedServerType == ServerType.ssh && _useKeyAuth)
            _buildTextFormField(
              context.loc('ssh_private_key'),
              _privateKeyController,
              context.loc('ssh_private_key_hint'),
              maxLines: 2,
              suffixIcon: IconButton(
                onPressed: _pickPrivateKeyFile,
                tooltip: context.loc('ssh_pick_key_file'),
                icon: const Icon(Icons.file_open),
              ),
            )
          else
            _buildTextFormField(
              context.loc('server_password'),
              _passwordController,
              context.loc('server_password_hint'),
              obscureText: true,
            ),
          _buildTextFormField(
            context.loc('remote_path'),
            _remotePathController,
            context.loc('remote_path_hint'),
            isOptional: true,
          ),
        ];
    }
  }

  Widget _buildTextFormField(
    String label,
    TextEditingController controller,
    String hintText, {
    bool obscureText = false,
    bool isOptional = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    int? maxLines,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLines: maxLines ?? 1,
        minLines: maxLines ?? 1,
        style: const TextStyle(fontSize: AppFontSizes.md),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          labelStyle: const TextStyle(fontSize: AppFontSizes.md),
          hintStyle: const TextStyle(fontSize: AppFontSizes.md),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          alignLabelWithHint: (maxLines ?? 1) > 1,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          suffixIcon: suffixIcon,
        ),
        validator: (value) {
          // Skip validation for optional fields
          if (isOptional) {
            return null;
          }
          if (value == null || value.isEmpty) {
            return context.loc('validation_required', [label]);
          }
          if (keyboardType == TextInputType.number &&
              int.tryParse(value) == null) {
            return context.loc('validation_invalid_number');
          }
          return null;
        },
      ),
    );
  }
}
