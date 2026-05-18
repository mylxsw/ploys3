import 'package:flutter_test/flutter_test.dart';
import 'package:ploys3/core/content_type.dart';

void main() {
  group('contentTypeForFileName', () {
    test('uses image/svg+xml for SVG files', () {
      expect(contentTypeForFileName('diagram.svg'), 'image/svg+xml');
      expect(contentTypeForFileName('DIAGRAM.SVG'), 'image/svg+xml');
    });

    test('returns null for unknown extensions', () {
      expect(contentTypeForFileName('archive.unknown'), isNull);
      expect(contentTypeForFileName('README'), isNull);
    });
  });
}
