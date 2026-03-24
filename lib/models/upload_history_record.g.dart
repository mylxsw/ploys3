// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upload_history_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UploadHistoryRecord _$UploadHistoryRecordFromJson(Map<String, dynamic> json) =>
    UploadHistoryRecord(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      fileExtension: json['fileExtension'] as String,
      fileType: json['fileType'] as String,
      downloadUrl: json['downloadUrl'] as String,
      serverName: json['serverName'] as String,
      uploadTime: json['uploadTime'] as String,
    );

Map<String, dynamic> _$UploadHistoryRecordToJson(
  UploadHistoryRecord instance,
) => <String, dynamic>{
  'id': instance.id,
  'fileName': instance.fileName,
  'fileExtension': instance.fileExtension,
  'fileType': instance.fileType,
  'downloadUrl': instance.downloadUrl,
  'serverName': instance.serverName,
  'uploadTime': instance.uploadTime,
};
