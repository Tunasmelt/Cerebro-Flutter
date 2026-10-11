import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/documents/data/upload/pending_upload_store.dart';
import 'package:cerebro_mobile/features/documents/data/upload/picked_upload.dart';
import 'package:cerebro_mobile/features/documents/data/upload/upload_api.dart';
import 'package:cerebro_mobile/features/documents/data/upload/upload_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_documents_repository.dart';
import 'fake_upload_services.dart';

class _RecoveryApi extends FakeUploadApi {
  _RecoveryApi(super.log, {this.objectPresent = false});
  final bool objectPresent;
  int probes = 0;
  @override
  Future<UploadConfirmation> confirm(String documentId) {
    if (probes++ == 0 && !objectPresent) {
      log.add('probe');
      throw const RequestRejectedException(
        'Not uploaded',
        code: 'upload_not_found',
      );
    }
    return super.confirm(documentId);
  }
}

class _RecoveryDocuments extends FakeDocumentsRepository {
  _RecoveryDocuments(this.stage);
  final String stage;
  @override
  Future<DocumentDetail> getDocument(String id) async => DocumentDetail(
    id: id,
    title: 'fixture.txt',
    mime: 'text/plain',
    sizeBytes: 11,
    status: stage == 'ready' ? DocumentStatus.ready : DocumentStatus.processing,
    createdAt: DateTime(2026),
    ingestState: stage,
    lastError: null,
  );
}

class _ObservedStore extends PendingUploadStore {
  _ObservedStore(super.directory);
  final cleared = Completer<void>();
  @override
  Future<void> clear(String owner) async {
    await super.clear(owner);
    cleared.complete();
  }
}

void main() {
  late Directory root;
  late PendingUploadStore store;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('cerebro-recovery-test-');
    store = PendingUploadStore(() async => root);
  });
  tearDown(() async => root.delete(recursive: true));

  test(
    'saved bytes and document identity survive a new store instance',
    () async {
      final saved = await store.save('owner-a', fakePickedUpload());
      saved.documentId = 'original-document';
      await saved.checkpoint();
      final reopened = PendingUploadStore(() async => root);
      final pending = (await reopened.load('owner-a')).single;
      expect(pending.documentId, 'original-document');
      expect(
        await pending.file.openRead().expand((chunk) => chunk).toList(),
        List.filled(11, 0),
      );
      final metadata =
          jsonDecode(
                await File(
                  '${pending.folder.path}/metadata.json',
                ).readAsString(),
              )
              as Map;
      expect(metadata.keys.toSet(), {'name', 'mime', 'size', 'document_id'});
      expect(await reopened.load('owner-b'), isEmpty);
      await reopened.clear('owner-b');
      expect(await reopened.load('owner-a'), hasLength(1));
    },
  );

  test(
    'a source exceeding its declared size cannot leave a recoverable copy',
    () async {
      final file = PickedUpload(
        name: 'fixture.txt',
        mime: 'text/plain',
        sizeBytes: 1,
        openRead: () => Stream.value([1, 2]),
      );
      await expectLater(store.save('owner', file), throwsFormatException);
      expect(await store.load('owner'), isEmpty);
    },
  );

  for (final damaged in ['{broken', '{"name":42}', null]) {
    test('damaged journal does not block other uploads: $damaged', () async {
      final bad = await store.save('owner', fakePickedUpload());
      final metadata = File('${bad.folder.path}/metadata.json');
      if (damaged == null) {
        await metadata.delete();
      } else {
        await metadata.writeAsString(damaged);
      }
      final good = await store.save('owner', fakePickedUpload());
      good.documentId = 'same-document';
      await good.checkpoint();
      final log = CallLog();
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('owner'),
          pendingUploadStoreProvider.overrideWithValue(store),
          uploadApiProvider.overrideWithValue(_RecoveryApi(log)),
          storageUploaderProvider.overrideWithValue(FakeStorageUploader(log)),
          documentsRepositoryProvider.overrideWithValue(
            _RecoveryDocuments('ready'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(uploadsProvider.notifier).restoration;
      final failed = container.read(uploadsProvider).single;
      expect(failed.filename, 'Saved upload');
      expect(log.entries, isEmpty);
      expect(await good.folder.exists(), isFalse);
      await container.read(uploadsProvider.notifier).dismiss(failed.id);
      expect(await store.load('owner'), isEmpty);
    });
  }

  for (final stage in ['uploading', 'normalizing', 'ready']) {
    test(
      'restart recovers $stage without creating a duplicate document',
      () async {
        final pending = await store.save('owner', fakePickedUpload());
        pending.documentId = 'same-document';
        await pending.checkpoint();
        final log = CallLog();
        final api = _RecoveryApi(log);
        final container = ProviderContainer(
          overrides: [
            currentUserIdProvider.overrideWithValue('owner'),
            pendingUploadStoreProvider.overrideWithValue(
              PendingUploadStore(() async => root),
            ),
            uploadApiProvider.overrideWithValue(api),
            storageUploaderProvider.overrideWithValue(FakeStorageUploader(log)),
            documentsRepositoryProvider.overrideWithValue(
              _RecoveryDocuments(stage),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(uploadsProvider.notifier).restoration;
        expect(
          log.entries,
          stage == 'uploading'
              ? ['probe', 'resume', 'put', 'confirm']
              : isEmpty,
        );
        expect(container.read(uploadsProvider), isEmpty);
        await pumpEventQueue();
        expect(await store.load('owner'), isEmpty);
      },
    );
  }

  test('bytes accepted before process death need only confirmation', () async {
    final pending = await store.save('owner', fakePickedUpload());
    pending.documentId = 'same-document';
    await pending.checkpoint();
    final log = CallLog();
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('owner'),
        pendingUploadStoreProvider.overrideWithValue(store),
        uploadApiProvider.overrideWithValue(
          _RecoveryApi(log, objectPresent: true),
        ),
        storageUploaderProvider.overrideWithValue(FakeStorageUploader(log)),
        documentsRepositoryProvider.overrideWithValue(
          _RecoveryDocuments('uploading'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(uploadsProvider.notifier).restoration;
    expect(log.entries, ['confirm']);
    expect(container.read(uploadsProvider), isEmpty);
  });

  test('failed renewal retains the saved file and makes no PUT', () async {
    final pending = await store.save('owner', fakePickedUpload());
    pending.documentId = 'same-document';
    await pending.checkpoint();
    final log = CallLog();
    final api = _RecoveryApi(log)
      ..resumeError = const NetworkUnreachableException();
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('owner'),
        pendingUploadStoreProvider.overrideWithValue(store),
        uploadApiProvider.overrideWithValue(api),
        storageUploaderProvider.overrideWithValue(FakeStorageUploader(log)),
        documentsRepositoryProvider.overrideWithValue(
          _RecoveryDocuments('uploading'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(uploadsProvider.notifier).restoration;
    expect(log.entries, ['probe', 'resume']);
    expect(
      container.read(uploadsProvider).single.flow.error,
      isA<NetworkUnreachableException>(),
    );
    expect((await store.load('owner')).single.documentId, 'same-document');
    await container
        .read(uploadsProvider.notifier)
        .dismiss(container.read(uploadsProvider).single.id);
    expect(await store.load('owner'), isEmpty);
  });

  test(
    'a different account cannot restore another owner\'s queued file',
    () async {
      final pending = await store.save('owner-a', fakePickedUpload());
      pending.documentId = 'private-document';
      await pending.checkpoint();
      final log = CallLog();
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('owner-b'),
          pendingUploadStoreProvider.overrideWithValue(store),
          uploadApiProvider.overrideWithValue(_RecoveryApi(log)),
          storageUploaderProvider.overrideWithValue(FakeStorageUploader(log)),
          documentsRepositoryProvider.overrideWithValue(
            _RecoveryDocuments('uploading'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(uploadsProvider.notifier).restoration;
      expect(log.entries, isEmpty);
      expect(container.read(uploadsProvider), isEmpty);
      expect(
        (await store.load('owner-a')).single.documentId,
        'private-document',
      );
    },
  );

  test(
    'a missing cached body is visible and cannot request a new PUT URL',
    () async {
      final pending = await store.save('owner', fakePickedUpload());
      pending.documentId = 'same-document';
      await pending.checkpoint();
      await File('${pending.folder.path}/bytes').delete();
      final log = CallLog();
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('owner'),
          pendingUploadStoreProvider.overrideWithValue(store),
          uploadApiProvider.overrideWithValue(_RecoveryApi(log)),
          storageUploaderProvider.overrideWithValue(FakeStorageUploader(log)),
          documentsRepositoryProvider.overrideWithValue(
            _RecoveryDocuments('uploading'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(uploadsProvider.notifier).restoration;
      expect(log.entries, ['probe']);
      final item = container.read(uploadsProvider).single;
      expect(
        (item.flow.error as RequestRejectedException).code,
        'saved_upload_missing',
      );
      await container.read(uploadsProvider.notifier).dismiss(item.id);
      expect(await store.load('owner'), isEmpty);
    },
  );

  test('signing out removes a failed owner queue from disk', () async {
    final observed = _ObservedStore(() async => root);
    final pending = await observed.save('owner', fakePickedUpload());
    pending.documentId = 'same-document';
    await pending.checkpoint();
    final identity = StateProvider<String?>((_) => 'owner');
    final log = CallLog();
    final api = _RecoveryApi(log)
      ..resumeError = const NetworkUnreachableException();
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => ref.watch(identity)),
        pendingUploadStoreProvider.overrideWithValue(observed),
        uploadApiProvider.overrideWithValue(api),
        storageUploaderProvider.overrideWithValue(FakeStorageUploader(log)),
        documentsRepositoryProvider.overrideWithValue(
          _RecoveryDocuments('uploading'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(uploadsProvider.notifier).restoration;
    expect(await observed.load('owner'), hasLength(1));
    container.read(identity.notifier).state = null;
    expect(container.read(uploadsProvider), isEmpty);
    await observed.cleared.future.timeout(const Duration(seconds: 5));
    expect(await observed.load('owner'), isEmpty);
    expect(log.entries, ['probe', 'resume']);
  });
}
