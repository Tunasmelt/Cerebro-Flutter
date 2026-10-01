// Milestone 2.2 unit test: the upload flow's local state machine —
// `selecting → uploading → confirming → done`, `→ failed` from any
// non-terminal stage, and NO illegal transition possible (above all:
// `done` is unreachable without `confirming` having succeeded).
import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/documents/data/upload/upload_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const failure = NetworkUnreachableException();

  test('the happy path walks selecting → uploading → confirming → done', () {
    var state = const UploadFlowState.selecting();
    expect(state.stage, UploadStage.selecting);

    state = state.startUpload();
    expect(state.stage, UploadStage.uploading);

    state = state.uploaded('doc-1');
    expect(state.stage, UploadStage.confirming);
    expect(state.documentId, 'doc-1');

    state = state.confirmed();
    expect(state.stage, UploadStage.done);
    expect(state.documentId, 'doc-1');
    expect(state.isTerminal, isTrue);
  });

  group('done is unreachable without confirming having succeeded', () {
    test('selecting cannot jump to done', () {
      expect(
        () => const UploadFlowState.selecting().confirmed(),
        throwsA(isA<IllegalUploadTransition>()),
      );
    });

    test('uploading cannot jump to done, skipping confirm', () {
      final uploading = const UploadFlowState.selecting().startUpload();
      expect(uploading.confirmed, throwsA(isA<IllegalUploadTransition>()));
    });

    test('a failed flow cannot be marked confirmed', () {
      final failed = const UploadFlowState.selecting().startUpload().fail(
        failure,
      );
      expect(failed.confirmed, throwsA(isA<IllegalUploadTransition>()));
    });
  });

  group('other illegal transitions', () {
    test('cannot reach confirming straight from selecting', () {
      expect(
        () => const UploadFlowState.selecting().uploaded('doc-1'),
        throwsA(isA<IllegalUploadTransition>()),
      );
    });

    test('cannot start an upload twice', () {
      final uploading = const UploadFlowState.selecting().startUpload();
      expect(uploading.startUpload, throwsA(isA<IllegalUploadTransition>()));
    });

    test('cannot report "uploaded" from confirming', () {
      final confirming = const UploadFlowState.selecting()
          .startUpload()
          .uploaded('doc-1');
      expect(
        () => confirming.uploaded('doc-2'),
        throwsA(isA<IllegalUploadTransition>()),
      );
    });

    test('done and failed are terminal: nothing moves them', () {
      final done = const UploadFlowState.selecting()
          .startUpload()
          .uploaded('doc-1')
          .confirmed();
      final failed = const UploadFlowState.selecting().fail(failure);

      expect(() => done.fail(failure), throwsA(isA<IllegalUploadTransition>()));
      expect(
        () => failed.fail(failure),
        throwsA(isA<IllegalUploadTransition>()),
      );
      expect(failed.startUpload, throwsA(isA<IllegalUploadTransition>()));
    });
  });

  group('→ failed on each stage, remembering where it failed', () {
    test('failing while selecting (e.g. validation)', () {
      final failed = const UploadFlowState.selecting().fail(failure);
      expect(failed.stage, UploadStage.failed);
      expect(failed.failedAt, UploadStage.selecting);
      expect(failed.error, same(failure));
      expect(failed.isTerminal, isTrue);
    });

    test('failing while uploading (init or the PUT)', () {
      final failed = const UploadFlowState.selecting().startUpload().fail(
        failure,
      );
      expect(failed.failedAt, UploadStage.uploading);
      expect(failed.documentId, isNull);
    });

    test('failing while confirming keeps the document id', () {
      final failed = const UploadFlowState.selecting()
          .startUpload()
          .uploaded('doc-1')
          .fail(failure);
      expect(failed.failedAt, UploadStage.confirming);
      expect(failed.documentId, 'doc-1');
    });
  });
}
