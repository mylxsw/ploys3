import 'package:flutter_test/flutter_test.dart';
import 'package:ploys3/core/image_bed_path_template.dart';
import 'package:ploys3/image_bed_settings_page.dart';

void main() {
  group('ImageBedPathTemplate', () {
    final now = DateTime(2026, 3, 25, 8, 9, 10);

    test('treats plain template as prefix and appends original filename', () {
      final resolved = ImageBedPathTemplate.resolve(
        '/tmp/My Screenshot.png',
        pathTemplate: 'images/{year}/{month}/',
        namingRule: ImageBedNamingRule.original,
        now: now,
        timestampMs: 1710504000000,
      );

      expect(resolved.key, 'images/2026/03/My Screenshot.png');
      expect(resolved.fileName, 'My Screenshot.png');
    });

    test('uses full path when template includes filename placeholders', () {
      final resolved = ImageBedPathTemplate.resolve(
        '/tmp/My Screenshot.png',
        pathTemplate: 'images/{year}/{fileName}.{ext}',
        namingRule: ImageBedNamingRule.random,
        now: now,
        timestampMs: 1710504000000,
      );

      expect(resolved.key, 'images/2026/My-Screenshot.png');
      expect(resolved.fileName, 'My-Screenshot.png');
    });
  });
}
