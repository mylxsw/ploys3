import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'package:ploys3_cli/config.dart';
import 'package:ploys3_cli/uploader.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
    ..addFlag('version', negatable: false, help: 'Show version');

  parser.addCommand('upload', ArgParser()
    ..addOption('server', abbr: 's', help: 'Server name or ID (default: image bed server)')
    ..addOption('prefix', abbr: 'p', help: 'Upload directory/prefix (default: from image bed config)')
    ..addOption('naming', abbr: 'n', help: 'Naming rule: original|random (default: from config)',
        allowed: ['original', 'random'])
    ..addFlag('markdown', abbr: 'm', negatable: false, help: 'Output as Markdown image links')
    ..addFlag('verbose', abbr: 'v', negatable: false, help: 'Verbose output')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
    ..addOption('config', abbr: 'c', help: 'Config file path'));

  parser.addCommand('servers', ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
    ..addOption('config', abbr: 'c', help: 'Config file path'));

  parser.addCommand('config', ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help'));

  ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    _printUsage(parser);
    exit(1);
  }

  if (results['help'] as bool) {
    _printUsage(parser);
    return;
  }

  if (results['version'] as bool) {
    print('ploys3 1.0.0');
    return;
  }

  if (results.command == null) {
    _printUsage(parser);
    exit(1);
  }

  switch (results.command!.name) {
    case 'upload':
      await _handleUpload(results.command!);
    case 'servers':
      _handleServers(results.command!);
    case 'config':
      _handleConfig(results.command!);
    default:
      _printUsage(parser);
      exit(1);
  }
}

void _printUsage(ArgParser parser) {
  stderr.writeln('PloyS3 CLI - Upload files to S3-compatible storage');
  stderr.writeln('');
  stderr.writeln('Usage: ploys3 <command> [options] [files...]');
  stderr.writeln('');
  stderr.writeln('Commands:');
  stderr.writeln('  upload    Upload files to storage');
  stderr.writeln('  servers   List configured servers');
  stderr.writeln('  config    Show current configuration');
  stderr.writeln('');
  stderr.writeln('Options:');
  stderr.writeln(parser.usage);
  stderr.writeln('');
  stderr.writeln('Examples:');
  stderr.writeln('  ploys3 upload screenshot.png           Upload to image bed');
  stderr.writeln('  ploys3 upload -m *.png                 Upload and output Markdown');
  stderr.writeln('  ploys3 upload -s myserver file.zip     Upload to specific server');
  stderr.writeln('  ploys3 upload -p blog/img/ photo.jpg   Upload to specific directory');
}

Future<void> _handleUpload(ArgResults args) async {
  if (args['help'] as bool) {
    stderr.writeln('Usage: ploys3 upload [options] <files...>');
    stderr.writeln('');
    stderr.writeln('Options:');
    stderr.writeln('  -s, --server    Server name or ID');
    stderr.writeln('  -p, --prefix    Upload directory/prefix');
    stderr.writeln('  -n, --naming    Naming rule: original|random');
    stderr.writeln('  -m, --markdown  Output as Markdown image links');
    stderr.writeln('  -v, --verbose   Verbose output');
    return;
  }

  final filePaths = args.rest;
  if (filePaths.isEmpty) {
    // Check if stdin has data (piped input)
    stderr.writeln('Error: No files specified.');
    stderr.writeln('Usage: ploys3 upload [options] <files...>');
    exit(1);
  }

  // Resolve glob-expanded paths and validate
  final resolvedPaths = <String>[];
  for (final fp in filePaths) {
    final resolved = p.isAbsolute(fp) ? fp : p.join(Directory.current.path, fp);
    if (!File(resolved).existsSync()) {
      stderr.writeln('Warning: File not found: $fp');
      continue;
    }
    resolvedPaths.add(resolved);
  }

  if (resolvedPaths.isEmpty) {
    stderr.writeln('Error: No valid files found.');
    exit(1);
  }

  // Load config
  CliConfig config;
  try {
    config = loadConfig(args['config'] as String?);
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }

  // Determine server
  ServerConfig? server;
  final serverQuery = args['server'] as String?;

  if (serverQuery != null) {
    server = config.findServer(serverQuery);
    if (server == null) {
      stderr.writeln('Error: Server "$serverQuery" not found.');
      stderr.writeln('Available servers:');
      for (final s in config.servers) {
        stderr.writeln('  ${s.name} (${s.id})');
      }
      exit(1);
    }
  } else {
    server = config.imageBedServer;
    if (server == null) {
      stderr.writeln('Error: No image bed server configured.');
      stderr.writeln('Please configure image bed in the PloyS3 app, or use -s to specify a server.');
      exit(1);
    }
  }

  if (server.serverType != 's3') {
    stderr.writeln('Error: CLI upload currently supports S3-compatible servers only.');
    stderr.writeln('Server "${server.name}" is of type "${server.serverType}".');
    exit(1);
  }

  // Determine prefix and naming rule
  final prefix = args['prefix'] as String? ??
      (serverQuery == null ? (config.imageBed?.uploadDir ?? '') : '');
  final namingRule = args['naming'] as String? ??
      (serverQuery == null ? (config.imageBed?.namingRule ?? 'original') : 'original');
  final markdown = args['markdown'] as bool;
  final verbose = args['verbose'] as bool;

  if (verbose) {
    stderr.writeln('Server: ${server.name}');
    stderr.writeln('Bucket: ${server.bucket}');
    stderr.writeln('Prefix: ${prefix.isEmpty ? '(root)' : prefix}');
    stderr.writeln('Naming: $namingRule');
    stderr.writeln('Files:  ${resolvedPaths.length}');
    stderr.writeln('');
  }

  // Upload
  final results = await uploadFiles(
    server: server,
    filePaths: resolvedPaths,
    prefix: prefix,
    namingRule: namingRule,
    verbose: verbose,
  );

  // Output results
  var hasError = false;
  for (final result in results) {
    if (result.success) {
      if (markdown && isImageFile(result.filePath)) {
        final alt = p.basenameWithoutExtension(result.filePath);
        print('![$alt](${result.url})');
      } else {
        print(result.url);
      }
    } else {
      stderr.writeln('Failed: ${p.basename(result.filePath)} - ${result.error}');
      hasError = true;
    }
  }

  if (hasError) exit(1);
}

void _handleServers(ArgResults args) {
  if (args['help'] as bool) {
    stderr.writeln('Usage: ploys3 servers');
    stderr.writeln('List all configured servers.');
    return;
  }

  CliConfig config;
  try {
    config = loadConfig(args['config'] as String?);
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }

  if (config.servers.isEmpty) {
    stderr.writeln('No servers configured.');
    return;
  }

  final imageBedId = config.imageBed?.serverId;

  for (final server in config.servers) {
    final isImageBed = server.id == imageBedId;
    final marker = isImageBed ? ' [image bed]' : '';
    final type = server.serverType.toUpperCase();
    print('${server.name} ($type)$marker');
    if (server.serverType == 's3') {
      print('  Endpoint: ${server.address}');
      print('  Bucket:   ${server.bucket}');
      if (server.cdnUrl != null && server.cdnUrl!.isNotEmpty) {
        print('  CDN:      ${server.cdnUrl}');
      }
    } else if (server.serverType == 'ssh') {
      print('  Host: ${server.host}:${server.port}');
      print('  Path: ${server.remotePath}');
    } else if (server.serverType == 'ftp') {
      print('  Host: ${server.host}:${server.port}');
      print('  Path: ${server.remotePath}');
    } else if (server.serverType == 'local') {
      print('  Path: ${server.localPath}');
    }
    print('');
  }
}

void _handleConfig(ArgResults args) {
  if (args['help'] as bool) {
    stderr.writeln('Usage: ploys3 config');
    stderr.writeln('Show current CLI configuration.');
    return;
  }

  final path = configFilePath;

  if (path == null) {
    print('Config file: not found');
    print('');
    print('Searched:');
    for (final p in configSearchPaths) {
      print('  - $p');
    }
    print('');
    print('Please open the PloyS3 app to generate the config file.');
    return;
  }

  print('Config file: $path');

  try {
    final config = loadConfig();
    print('Servers: ${config.servers.length}');

    if (config.imageBed != null) {
      print('');
      print('Image Bed:');
      final server = config.imageBedServer;
      print('  Server:  ${server?.name ?? 'Not found (${config.imageBed!.serverId})'}');
      print('  Dir:     ${config.imageBed!.uploadDir.isEmpty ? '(root)' : config.imageBed!.uploadDir}');
      print('  Naming:  ${config.imageBed!.namingRule}');
    }
  } catch (e) {
    stderr.writeln('Error reading config: $e');
  }
}
