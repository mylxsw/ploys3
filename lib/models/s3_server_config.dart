import 'package:json_annotation/json_annotation.dart';

part 's3_server_config.g.dart';

@JsonSerializable()
class S3ServerConfig {
  final String id;
  final String name;
  final String address;
  final String bucket;
  final String accessKeyId;
  final String secretAccessKey;
  final String? region;

  S3ServerConfig({
    required this.id,
    required this.name,
    required this.address,
    required this.bucket,
    required this.accessKeyId,
    required this.secretAccessKey,
    this.region,
  });

  factory S3ServerConfig.fromJson(Map<String, dynamic> json) => _$S3ServerConfigFromJson(json);

  Map<String, dynamic> toJson() => _$S3ServerConfigToJson(this);
}
