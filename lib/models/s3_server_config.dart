import 'package:json_annotation/json_annotation.dart';

part 's3_server_config.g.dart';

enum ServerType { s3, local, ssh, ftp }

extension ServerTypeX on ServerType {
  String get value => switch (this) {
    ServerType.s3 => 's3',
    ServerType.local => 'local',
    ServerType.ssh => 'ssh',
    ServerType.ftp => 'ftp',
  };

  static ServerType fromValue(String? value) {
    return switch (value) {
      'local' => ServerType.local,
      'ssh' => ServerType.ssh,
      'ftp' => ServerType.ftp,
      _ => ServerType.s3,
    };
  }
}

@JsonSerializable()
class S3ServerConfig {
  final String id;
  final String name;
  final String serverType;
  final String address;
  final String bucket;
  final String accessKeyId;
  final String secretAccessKey;
  final String? region;
  final String? cdnUrl;
  final String localPath;
  final String host;
  final int port;
  final String username;
  final String password;
  final String privateKey;
  final String remotePath;

  S3ServerConfig({
    required this.id,
    required this.name,
    this.serverType = 's3',
    required this.address,
    required this.bucket,
    required this.accessKeyId,
    required this.secretAccessKey,
    this.region,
    this.cdnUrl,
    this.localPath = '',
    this.host = '',
    this.port = 0,
    this.username = '',
    this.password = '',
    this.privateKey = '',
    this.remotePath = '',
  });

  factory S3ServerConfig.fromJson(Map<String, dynamic> json) =>
      _$S3ServerConfigFromJson(json);

  Map<String, dynamic> toJson() => _$S3ServerConfigToJson(this);

  ServerType get type => ServerTypeX.fromValue(serverType);
}
