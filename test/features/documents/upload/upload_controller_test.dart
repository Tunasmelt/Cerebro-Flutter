// Milestone 2.2 unit tests for the orchestrator: given mock failures at
// each call, the flow lands in `failed` at the right stage, and the
// invariant holds — `upload-confirm` is only ever called after the PUT
// succeeded, and `done` only after `upload-confirm` succeeded.
import 'dart:async';

import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/documents_list_notifier.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/documents/data/upload/upload_controller.dart';
import 'package:cerebro_mobile/features/documents/data/upload/upload_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_documents_repository.dart';
import 'fake_upload_services.dart';

void main() {
  late CallLog log;
  late FakeUploadApi api;
  late FakeStorageUploader storage;
  late FakeDocumentsRepository documents;
  late ProviderContainer container;

  setUp(() {
    log = CallLog();
    api = FakeUploadApi(log);
    storage = FakeStorageUploader(log);
    documents = FakeDocumentsRepository();
    container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        uploadApiProvider.overrideWithValue(api),
        storageUploaderProvider.overrideWithValue(storage),
        documentsRepositoryProvider.overrideWithValue(documents),
      ],
    );
  });

  tearDown(() => container.dispose());

  UploadController controller() => container.read(uploadsProvider.notifier);
  List<UploadItem> items() => container.read(uploadsProvider);

  test('success: init → put → confirm, in that order, then drops its row',
      () async {
    await controller().upload(fakePickedUpload());

    expect(log.entries, ['init', 'put', 'confirm']);
    expect(items(), isEmpty, reason: 'the row is removed once it is done');
  });

  test('success refreshes the document list when it is on screen', () async {
    // The Documents screen has built the list (one fetch).
    await container.read(documentsListProvider.future);
    expect(documents.listCalls, 1);

    await controller().upload(fakePickedUpload());

    expect(documents.listCalls, 2, reason: 'refreshed exactly once');
  });

  test('success does not build (and double-fetch) a list nobody is showing',
      () async {
    await controller().upload(fakePickedUpload());

    expect(documents.listCalls, 0);
  });

  test('walks selecting → uploading → confirming → done while in flight',
      () async {
    final putGate = Completer<void>();
    final confirmGate = Completer<void>();
    storage.putGate = putGate;
    api.confirmGate = confirmGate;

    final running = controller().upload(fakePickedUpload());
    await pumpEventQueue();
    expect(items().single.flow.stage, UploadStage.uploading);
    expect(log.entries, ['init', 'put'], reason: 'confirm not yet called');

    putGate.complete();
    await pumpEventQueue();
    expect(items().single.flow.stage, UploadStage.confirming);
    expect(log.entries, ['init', 'put', 'confirm']);

    confirmGate.complete();
    await running;
    expect(items(), isEmpty);
  });

  group('failure at each call → failed at that stage', () {
    test('upload-init fails: failed while uploading, nothing else is called',
        () async {
      api.initError = const NetworkUnreachableException();

      await controller().upload(fakePickedUpload());

      final flow = items().single.flow;
      expect(flow.stage, UploadStage.failed);
      expect(flow.failedAt, UploadStage.uploading);
      expect(flow.error, isA<NetworkUnreachableException>());
      expect(log.entries, ['init'], reason: 'no PUT, no confirm');
    });

    test('the PUT fails: failed while uploading, and confirm is NEVER called',
        () async {
      storage.putError = const NetworkUnreachableException();

      await controller().upload(fakePickedUpload());

      final flow = items().single.flow;
      expect(flow.stage, UploadStage.failed);
      expect(flow.failedAt, UploadStage.uploading);
      expect(log.entries, ['init', 'put']);
      expect(log.entries, isNot(contains('confirm')));
      expect(documents.listCalls, 0, reason: 'nothing to show yet');
    });

    test('upload-confirm fails: failed while confirming, never reaches done',
        () async {
      api.confirmError = const RequestRejectedException(
        'No uploaded object found for this document yet',
        code: 'upload_not_found',
      );

      await controller().upload(fakePickedUpload());

      final flow = items().single.flow;
      expect(flow.stage, UploadStage.failed);
      expect(flow.failedAt, UploadStage.confirming);
      expect(flow.documentId, 'doc-1');
      expect(
        (flow.error as RequestRejectedException).message,
        'No uploaded object found for this document yet',
      );
      expect(log.entries, ['init', 'put', 'confirm']);
      expect(documents.listCalls, 0, reason: 'never reached done');
    });

    test('a failed row stays until dismissed, and Dismiss removes it',
        () async {
      storage.putError = const ServerErrorException(503);
      await controller().upload(fakePickedUpload());
      final id = items().single.id;

      controller().dismiss(id);

      expect(items(), isEmpty);
    });
  });

  group('client-side validation fails before any network call', () {
    test('an unsupported type', () async {
      await controller().upload(
        fakePickedUpload(name: 'archive.zip', mime: null),
      );

      final flow = items().single.flow;
      expect(flow.stage, UploadStage.failed);
      expect(flow.failedAt, UploadStage.selecting);
      expect(
        (flow.error as RequestRejectedException).message,
        'Unsupported file type: .zip',
      );
      expect(log.entries, isEmpty);
    });

    test('a file one byte over 50 MiB', () async {
      await controller().upload(fakePickedUpload(sizeBytes: 52428801));

      final flow = items().single.flow;
      expect(flow.failedAt, UploadStage.selecting);
      expect(
        (flow.error as RequestRejectedException).message,
        'File exceeds the 50MB upload limit',
      );
      expect(log.entries, isEmpty);
    });

    test('a file exactly at 50 MiB is sent', () async {
      await controller().upload(fakePickedUpload(sizeBytes: 52428800));

      expect(log.entries, ['init', 'put', 'confirm']);
    });
  });

  test('an unexpected non-AppException error cannot leave the row stuck '
      'uploading forever', () async {
    api.initError = StateError('something nobody anticipated');

    await controller().upload(fakePickedUpload());

    final flow = items().single.flow;
    expect(flow.stage, UploadStage.failed);
    expect(flow.error, isA<UnknownApiException>());
  });

  test('reports real progress while the bytes go to Storage', () async {
    final putGate = Completer<void>();
    storage
      ..putGate = putGate
      ..progressEvents = [(25, 100), (50, 100)];

    final running = controller().upload(fakePickedUpload());
    await pumpEventQueue();

    expect(items().single.progress, 0.5);

    putGate.complete();
    await running;
  });

  test('two uploads run independently', () async {
    final putGate = Completer<void>();
    storage.putGate = putGate;

    final first = controller().upload(fakePickedUpload(name: 'a.txt'));
    final second = controller().upload(fakePickedUpload(name: 'b.txt'));
    await pumpEventQueue();

    expect(items().map((i) => i.filename), ['a.txt', 'b.txt']);
    expect(items().map((i) => i.flow.stage), everyElement(UploadStage.uploading));

    putGate.complete();
    await Future.wait([first, second]);
    expect(items(), isEmpty);
    expect(log.entries.where((e) => e == 'confirm'), hasLength(2));
  });
}
