// GENERATED CODE - DO NOT MODIFY BY HAND

part of 's3_server_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

S3ServerConfig _$S3ServerConfigFromJson(Map<String, dynamic> json) =>
    S3ServerConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      bucket: json['bucket'] as String,
      accessKeyId: json['accessKeyId'] as String,
      secretAccessKey: json['secretAccessKey'] as String,
      region: json['region'] as String?,
    );

Map<String, dynamic> _$S3ServerConfigToJson(S3ServerConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'address': instance.address,
      'bucket': instance.bucket,
      'accessKeyId': instance.accessKeyId,
      'secretAccessKey': instance.secretAccessKey,
      'region': instance.region,
    };
