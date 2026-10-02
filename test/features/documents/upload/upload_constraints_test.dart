import 'package:cerebro_mobile/features/documents/data/upload/upload_constraints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  unsupportedTypeMessageTests();
  group('the 50MB ceiling is exactly 50 MiB, to the byte', () {
    test('kMaxUploadBytes is 52,428,800', () {
      expect(kMaxUploadBytes, 52428800);
      expect(kMaxUploadBytes, 50 * 1024 * 1024);
    });

    test('a file exactly at the limit is allowed', () {
      expect(validateUpload(mime: 'application/pdf', sizeBytes: 52428800), isNull);
    });

    test('one byte over the limit is rejected with the server\'s wording', () {
      expect(
        validateUpload(mime: 'application/pdf', sizeBytes: 52428801),
        'File exceeds the 50MB upload limit',
      );
    });

    test('an empty file is not rejected client-side (web parity)', () {
      expect(validateUpload(mime: 'text/plain', sizeBytes: 0), isNull);
    });
  });

  group('mime allow-list mirrors the backend exactly', () {
    test('all six backend types are allowed', () {
      for (final mime in [
        'text/plain',
        'text/markdown',
        'application/pdf',
        'image/jpeg',
        'image/png',
        'image/webp',
      ]) {
        expect(validateUpload(mime: mime, sizeBytes: 1), isNull, reason: mime);
      }
      expect(kAllowedUploadMimeTypes, hasLength(6));
    });

    test('an unsupported type is rejected and named', () {
      expect(
        validateUpload(mime: 'application/zip', sizeBytes: 1),
        'Unsupported file type: application/zip',
      );
    });

    test('an unknown type (null mime) is rejected', () {
      expect(
        validateUpload(mime: null, sizeBytes: 1),
        'Unsupported file type: unknown',
      );
    });
  });

  group('uploadMimeForFileName', () {
    test('maps extensions, case-insensitively', () {
      expect(uploadMimeForFileName('report.PDF'), 'application/pdf');
      expect(uploadMimeForFileName('a.b.c.jpeg'), 'image/jpeg');
      expect(uploadMimeForFileName('notes.md'), 'text/markdown');
      expect(uploadMimeForFileName('photo.webp'), 'image/webp');
    });

    test('returns null for unsupported or missing extensions', () {
      expect(uploadMimeForFileName('archive.zip'), isNull);
      expect(uploadMimeForFileName('README'), isNull);
      expect(uploadMimeForFileName('trailing.'), isNull);
    });
  });
}

void unsupportedTypeMessageTests() {
  group('unsupported type names the extension, not "unknown"', () {
    test('a .gif', () {
      expect(
        validateUpload(
          mime: uploadMimeForFileName('party.GIF'),
          sizeBytes: 1,
          fileName: 'party.GIF',
        ),
        'Unsupported file type: .gif',
      );
    });
    test('no extension at all still says unknown', () {
      expect(
        validateUpload(mime: null, sizeBytes: 1, fileName: 'README'),
        'Unsupported file type: unknown',
      );
    });
  });
}
