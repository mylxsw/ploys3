import 'package:ploys3/core/storage/ftp_storage_service.dart';
import 'package:ploys3/core/storage/local_file_storage_service.dart';
import 'package:ploys3/core/storage/s3_storage_service.dart';
import 'package:ploys3/core/storage/sftp_storage_service.dart';
import 'package:ploys3/core/storage/storage_service.dart';
import 'package:ploys3/models/s3_server_config.dart';

class StorageServiceFactory {
  static StorageService create(S3ServerConfig config) {
    return switch (config.type) {
      ServerType.s3 => S3StorageService(config),
      ServerType.local => LocalFileStorageService(config),
      ServerType.ssh => SftpStorageService(config),
      ServerType.ftp => FtpStorageService(config),
    };
  }
}
