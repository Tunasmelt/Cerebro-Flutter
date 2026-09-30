import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/presentation/document_presentation.dart';
import 'package:cerebro_mobile/shared/tokens/app_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('documentTypeColor / documentStatusColor', () {
    test(
      'never uses amber for a Markdown file or a processing status — '
      'amber is reserved exclusively for sealed/locked UI project-wide',
      () {
        expect(documentTypeColor('text/markdown'), isNot(AppColors.accentLocked));
        expect(
          documentStatusColor(DocumentStatus.processing),
          isNot(AppColors.accentLocked),
        );
      },
    );

    test('sealed is the one status that legitimately uses amber', () {
      expect(documentStatusColor(DocumentStatus.sealed), AppColors.accentLocked);
    });

    test('every status maps to a distinct color', () {
      final colors = DocumentStatus.values.map(documentStatusColor).toSet();
      expect(colors.length, DocumentStatus.values.length);
    });
  });

  group('documentTypeLabel', () {
    test('maps known mime types to short labels', () {
      expect(documentTypeLabel('application/pdf'), 'PDF');
      expect(documentTypeLabel('image/jpeg'), 'JPG');
      expect(documentTypeLabel('image/png'), 'PNG');
      expect(documentTypeLabel('text/markdown'), 'MD');
      expect(documentTypeLabel('text/plain'), 'TXT');
    });

    test('falls back to the subtype, uppercased, for an unknown mime', () {
      expect(documentTypeLabel('application/zip'), 'ZIP');
    });
  });

  group('formatDocumentSize', () {
    test('formats bytes, kb, and mb the same way the web reference does', () {
      expect(formatDocumentSize(42), '42b');
      expect(formatDocumentSize(2048), '2.0kb');
      expect(formatDocumentSize(5 * 1024 * 1024), '5.0mb');
    });
  });
}
