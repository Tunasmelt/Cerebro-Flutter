// Unit test for the client-side responsibility that actually exists
// here: correctly parsing the server's real (flat, ordered) list
// response and passing every field through unchanged. There is no
// cursor to test — see CHANGELOG's Phase 2 entry: the real backend's
// `GET /documents` isn't paginated, contradicting this milestone's
// original exit-criteria wording, confirmed from the deployed
// backend's own source rather than its (empty) OpenAPI schema.
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocumentSummary.fromJson', () {
    test('parses every field the real list endpoint returns', () {
      final summary = DocumentSummary.fromJson({
        'id': 'doc-1',
        'title': 'notes.txt',
        'mime': 'text/plain',
        'size_bytes': 42,
        'original_size_bytes': 50,
        'status': 'ready',
        'created_at': '2026-01-01T00:00:00Z',
      });

      expect(summary.id, 'doc-1');
      expect(summary.title, 'notes.txt');
      expect(summary.mime, 'text/plain');
      expect(summary.sizeBytes, 42);
      expect(summary.originalSizeBytes, 50);
      expect(summary.status, DocumentStatus.ready);
      expect(summary.createdAt, DateTime.parse('2026-01-01T00:00:00Z'));
    });

    test('a null original_size_bytes parses to null, not a crash', () {
      final summary = DocumentSummary.fromJson({
        'id': 'doc-2',
        'title': 'paper.pdf',
        'mime': 'application/pdf',
        'size_bytes': 900,
        'original_size_bytes': null,
        'status': 'processing',
        'created_at': '2026-01-02T00:00:00Z',
      });

      expect(summary.originalSizeBytes, isNull);
      expect(summary.status, DocumentStatus.processing);
    });

    test(
      'an unrecognized status maps to unknown rather than throwing — a '
      'safety net for a value the server adds later',
      () {
        final summary = DocumentSummary.fromJson({
          'id': 'doc-3',
          'title': 'x',
          'mime': 'text/plain',
          'size_bytes': 1,
          'original_size_bytes': 1,
          'status': 'some_future_status',
          'created_at': '2026-01-01T00:00:00Z',
        });

        expect(summary.status, DocumentStatus.unknown);
      },
    );

    test(
      'parsing preserves list order — the client never re-sorts a '
      'response the server already ordered (created_at desc)',
      () {
        final json = [
          {
            'id': 'newest',
            'title': 'a',
            'mime': 'text/plain',
            'size_bytes': 1,
            'original_size_bytes': 1,
            'status': 'ready',
            'created_at': '2026-01-02T00:00:00Z',
          },
          {
            'id': 'oldest',
            'title': 'b',
            'mime': 'text/plain',
            'size_bytes': 1,
            'original_size_bytes': 1,
            'status': 'ready',
            'created_at': '2026-01-01T00:00:00Z',
          },
        ];

        final parsed = json
            .map((row) => DocumentSummary.fromJson(row).id)
            .toList();

        expect(parsed, ['newest', 'oldest']);
      },
    );
  });

  group('DocumentDetail.fromJson', () {
    test('parses the detail shape, including the folded-in ingest fields', () {
      final detail = DocumentDetail.fromJson({
        'id': 'doc-1',
        'title': 'notes.txt',
        'mime': 'text/plain',
        'size_bytes': 42,
        'status': 'failed',
        'created_at': '2026-01-01T00:00:00Z',
        'ingest_state': 'embedding',
        'last_error': 'embedding_failed',
      });

      expect(detail.status, DocumentStatus.failed);
      expect(detail.ingestState, 'embedding');
      expect(detail.lastError, 'embedding_failed');
    });

    test('a ready document with no ingest job has null ingest fields', () {
      final detail = DocumentDetail.fromJson({
        'id': 'doc-1',
        'title': 'notes.txt',
        'mime': 'text/plain',
        'size_bytes': 42,
        'status': 'ready',
        'created_at': '2026-01-01T00:00:00Z',
        'ingest_state': null,
        'last_error': null,
      });

      expect(detail.ingestState, isNull);
      expect(detail.lastError, isNull);
    });
  });
}
