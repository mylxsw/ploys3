// GENERATED CODE - DO NOT MODIFY BY HAND

part of 's3_server_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

S3ServerConfig _$S3ServerConfigFromJson(Map<String, dynamic> json) =>
    S3ServerConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      serverType: json['serverType'] as String? ?? 's3',
      address: json['address'] as String? ?? '',
      bucket: json['bucket'] as String? ?? '',
      accessKeyId: json['accessKeyId'] as String? ?? '',
      secretAccessKey: json['secretAccessKey'] as String? ?? '',
      region: json['region'] as String?,
      cdnUrl: json['cdnUrl'] as String?,
      localPath: json['localPath'] as String? ?? '',
      host: json['host'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 0,
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      privateKey: json['privateKey'] as String? ?? '',
      remotePath: json['remotePath'] as String? ?? '',
    );

Map<String, dynamic> _$S3ServerConfigToJson(S3ServerConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'serverType': instance.serverType,
      'address': instance.address,
      'bucket': instance.bucket,
      'accessKeyId': instance.accessKeyId,
      'secretAccessKey': instance.secretAccessKey,
      'region': instance.region,
      'cdnUrl': instance.cdnUrl,
      'localPath': instance.localPath,
      'host': instance.host,
      'port': instance.port,
      'username': instance.username,
      'password': instance.password,
      'privateKey': instance.privateKey,
      'remotePath': instance.remotePath,
    };
