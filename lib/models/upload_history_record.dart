import 'package:json_annotation/json_annotation.dart';

part 'upload_history_record.g.dart';

@JsonSerializable()
class UploadHistoryRecord {
  final String id;
  final String fileName;
  final String fileExtension;
  final String fileType;
  final String downloadUrl;
  final String serverName;
  final String uploadTime;

  UploadHistoryRecord({
    required this.id,
    required this.fileName,
    required this.fileExtension,
    required this.fileType,
    required this.downloadUrl,
    required this.serverName,
    required this.uploadTime,
  });

  factory UploadHistoryRecord.fromJson(Map<String, dynamic> json) =>
      _$UploadHistoryRecordFromJson(json);

  Map<String, dynamic> toJson() => _$UploadHistoryRecordToJson(this);

  static String detectFileType(String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    const imageExts = {
      'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'tif', 'tiff',
      'heic', 'heif', 'ico', 'avif',
    };
    const videoExts = {
      'mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv', 'webm', 'm4v',
    };
    const audioExts = {
      'mp3', 'wav', 'flac', 'aac', 'ogg', 'wma', 'm4a',
    };
    const docExts = {
      'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv',
      'md', 'rtf',
    };
    const archiveExts = {
      'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz',
    };

    if (imageExts.contains(ext)) return 'image';
    if (videoExts.contains(ext)) return 'video';
    if (audioExts.contains(ext)) return 'audio';
    if (docExts.contains(ext)) return 'document';
    if (archiveExts.contains(ext)) return 'archive';
    return 'other';
  }
}
