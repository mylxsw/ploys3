import 'package:path/path.dart' as p;

const Map<String, String> _contentTypesByExtension = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'bmp': 'image/bmp',
  'webp': 'image/webp',
  'svg': 'image/svg+xml',
  'tif': 'image/tiff',
  'tiff': 'image/tiff',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'ico': 'image/x-icon',
};

String? contentTypeForFileName(String fileName) {
  final extension = p.extension(fileName).toLowerCase().replaceFirst('.', '');
  if (extension.isEmpty) return null;
  return _contentTypesByExtension[extension];
}
