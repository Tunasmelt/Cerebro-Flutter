import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/ingest_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../scripted_documents_repository.dart';

void main() {
  group('every documented ingest_jobs.state maps to a defined label', () {
    const expected = {
      'uploading': ('Uploading', IngestStage.uploading),
      'normalizing': ('Preparing file', IngestStage.normalizing),
      'extracting': ('Reading text', IngestStage.extracting),
      'embedding': ('Indexing', IngestStage.embedding),
      'ready': ('Ready', IngestStage.ready),
      'failed': ('Failed', IngestStage.failed),
    };
    for (final entry in expected.entries) {
      test(entry.key, () {
        final stage = IngestStage.fromApi(entry.key);
        expect(stage, entry.value.$2);
        expect(stage.label, entry.value.$1);
      });
    }
  });

  group('an undocumented or missing state is a safe fallback, not a crash', () {
    for (final value in [null, '', 'archiving', 'READY', 'Embedding ']) {
      test(value ?? 'null', () {
        final stage = IngestStage.fromApi(value);
        expect(stage, IngestStage.unknown);
        expect(stage.label, 'Processing');
        expect(stage.isTerminal, isFalse);
        expect(stage.progress, isNull);
      });
    }
  });

  test('only ready and failed are terminal', () {
    expect(
      [for (final s in IngestStage.values) if (s.isTerminal) s],
      [IngestStage.ready, IngestStage.failed],
    );
  });

  test('progress only moves forward through the pipeline', () {
    const order = [
      IngestStage.uploading,
      IngestStage.normalizing,
      IngestStage.extracting,
      IngestStage.embedding,
      IngestStage.ready,
    ];
    final values = [for (final s in order) s.progress!];
    expect(values, orderedEquals([...values]..sort()));
    expect(values.toSet(), hasLength(order.length));
  });

  group('last_error codes read as plain language', () {
    const codes = [
      'file_too_large',
      'upload_expired',
      'corrupt_pdf',
      'corrupt_image',
      'original_download_failed',
      'indexed_upload_failed',
      'document_not_found',
      'chunk_insert_failed',
      'chunk_update_failed',
      'embed_call_failed',
      'provider_not_configured',
    ];
    for (final code in codes) {
      test(code, () {
        final message = ingestErrorMessage(code);
        expect(message, isNot(contains('_')), reason: 'no raw code leaks');
        expect(message, isNot(contains('(')));
      });
    }

    test('an unfamiliar code is still shown, not hidden', () {
      expect(
        ingestErrorMessage('quota_exceeded'),
        "This document couldn't be processed (quota_exceeded).",
      );
    });

    test('no code at all still says it failed', () {
      expect(ingestErrorMessage(null), "This document couldn't be processed.");
    });
  });

  group('effectiveDocumentStatus — a retried document is not still "failed"', () {
    // The backend leaves documents.status = failed while a retry runs; only
    // the job's stage says what is really happening.
    const cases = [
      // (status, stage) -> effective
      (DocumentStatus.failed, 'normalizing', DocumentStatus.processing),
      (DocumentStatus.failed, 'extracting', DocumentStatus.processing),
      (DocumentStatus.failed, 'embedding', DocumentStatus.processing),
      (DocumentStatus.failed, 'ready', DocumentStatus.ready),
      (DocumentStatus.failed, 'failed', DocumentStatus.failed),
      (DocumentStatus.failed, null, DocumentStatus.failed),
      (DocumentStatus.failed, 'archiving', DocumentStatus.failed),
      (DocumentStatus.processing, 'embedding', DocumentStatus.processing),
      (DocumentStatus.processing, 'ready', DocumentStatus.processing),
      (DocumentStatus.ready, 'ready', DocumentStatus.ready),
      (DocumentStatus.sealed, null, DocumentStatus.sealed),
    ];
    for (final (status, stage, expected) in cases) {
      test('${status.name} + ${stage ?? 'no job'} -> ${expected.name}', () {
        expect(
          effectiveDocumentStatus(detailAt(stage, status: status)),
          expected,
        );
      });
    }
  });

  group('Retry is offered unless there is structurally nothing to resume', () {
    for (final code in ['upload_expired', 'file_too_large', 'document_not_found']) {
      test('not for $code', () => expect(ingestErrorRetryable(code), isFalse));
    }
    for (final code in [
      'embed_call_failed',
      'chunk_insert_failed',
      'chunk_update_failed',
      'original_download_failed',
      'indexed_upload_failed',
      'provider_not_configured',
      'corrupt_pdf', // a truncated download can look corrupt
      'corrupt_image',
      'a_code_added_next_month',
      null,
    ]) {
      test('for ${code ?? 'no code'}', () => expect(ingestErrorRetryable(code), isTrue));
    }
  });
}
