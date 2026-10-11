// Emulator smoke test for 7.1, not proof of physical Android power limits.
// Uses a disposable synthetic upload through the production controller and
// a paced real Storage stream. Press Home at STREAM_STARTED, wait for
// at least 20 seconds, then reopen. Deletes only its own fixture after success.
// Restore lib/main.dart after running. No credentials or user content logged.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:cerebro_mobile/features/auth/data/supabase_session_token_provider.dart';
import 'package:cerebro_mobile/features/documents/data/upload/storage_uploader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cerebro_mobile/core/config/supabase_config.dart';
import 'package:cerebro_mobile/core/network/generated_api_client.dart';
import 'package:cerebro_mobile/core/network/generated_api_client_provider.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_list_notifier.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/documents/data/delete_document_controller.dart';
import 'package:cerebro_mobile/features/documents/data/upload/picked_upload.dart';
import 'package:cerebro_mobile/features/documents/data/upload/pending_upload_store.dart';
import 'package:cerebro_mobile/features/documents/data/upload/upload_api.dart';
import 'package:cerebro_mobile/features/documents/data/upload/upload_controller.dart';
import 'package:cerebro_mobile/main.dart' show CerebroApp;

class _TrackingUpload implements UploadApi {
  _TrackingUpload(this.delegate, this.fixtureFilename);
  final UploadApi delegate;
  final String fixtureFilename;
  String? documentId;
  bool confirmed = false;
  @override
  Future<UploadInit> resume(String documentId) async {
    final result = await delegate.resume(documentId);
    if (this.documentId != documentId) return result;
    if (result.documentId != documentId || this.documentId != documentId) {
      throw StateError('Recovery changed document identity');
    }
    debugPrint('MILESTONE_7_1_SAME_DOCUMENT_RENEWAL_PASS');
    return result;
  }

  @override
  Future<UploadInit> init({
    required String filename,
    required String mime,
    required int sizeBytes,
  }) async {
    final result = await delegate.init(
      filename: filename,
      mime: mime,
      sizeBytes: sizeBytes,
    );
    if (filename == fixtureFilename) {
      documentId = result.documentId;
      debugPrint('MILESTONE_7_1_UPLOAD_INIT_CALLED');
    }
    return result;
  }

  @override
  Future<UploadConfirmation> confirm(String documentId) async {
    final result = await delegate.confirm(documentId);
    if (documentId == this.documentId) {
      confirmed = true;
      debugPrint('MILESTONE_7_1_UPLOAD_CONFIRMED');
    }
    return result;
  }
}

class _CountingDocuments implements DocumentsRepository {
  _CountingDocuments(this.delegate);
  final DocumentsRepository delegate;
  int reads = 0;
  @override
  Future<List<DocumentSummary>> listDocuments() {
    reads++;
    return delegate.listDocuments();
  }

  @override
  Future<DocumentDetail> getDocument(String id) => delegate.getDocument(id);
}

const _foregroundControl = bool.fromEnvironment('PLATFORM_FOREGROUND_CONTROL');
const _cleanupFilename = String.fromEnvironment('PLATFORM_CLEANUP_FILENAME');
const _verificationApi = String.fromEnvironment('PLATFORM_VERIFICATION_API');

class _PacedStorageUploader extends DioStorageUploader {
  _PacedStorageUploader({
    required super.tokenProvider,
    required super.apiKey,
    super.dio,
    super.retryAfterBackground,
    super.canContinue,
  });

  @override
  Future<void> put({
    required Uri uploadUrl,
    required PickedUpload file,
    required String mime,
    void Function(int, int)? onProgress,
  }) {
    final synthetic =
        file.name.startsWith('m71-background-') && file.sizeBytes == 645;
    return super.put(
      uploadUrl: uploadUrl,
      mime: mime,
      onProgress: onProgress,
      file: !synthetic
          ? file
          : PickedUpload(
              name: file.name,
              mime: file.mime,
              sizeBytes: file.sizeBytes,
              openRead: () async* {
                final bytes = await file
                    .openRead()
                    .expand((chunk) => chunk)
                    .toList();
                debugPrint('MILESTONE_7_1_STREAM_STARTED');
                for (var i = 0; i < 15; i++) {
                  await Future<void>.delayed(const Duration(seconds: 1));
                  yield bytes.sublist(i * 43, (i + 1) * 43);
                  if (i == 0 || i == 14) {
                    debugPrint('MILESTONE_7_1_CHUNK_${i + 1}_SENT');
                  }
                }
              },
            ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  final auth = Supabase.instance.client.auth;
  if (auth.currentSession?.isExpired == true) await auth.refreshSession();
  if (auth.currentUser == null) {
    runApp(const ProviderScope(child: CerebroApp()));
    debugPrint('MILESTONE_7_1_SIGN_IN_REQUIRED');
    await auth.onAuthStateChange.firstWhere((event) => event.session != null);
  }
  final ownerId = auth.currentUser!.id;
  final base = ProviderContainer(
    overrides: [
      if (_verificationApi.isNotEmpty)
        generatedApiClientProvider.overrideWithValue(
          buildGeneratedApiClient(
            tokenProvider: const SupabaseSessionTokenProvider(),
            baseUrl: _verificationApi,
          ),
        ),
    ],
  );
  final pendingStore = devicePendingUploadStore();
  final saved = (await pendingStore.load(ownerId))
      .where(
        (pending) =>
            pending.name.startsWith('m71-background-') &&
            pending.documentId != null,
      )
      .toList();
  if (saved.length > 1) {
    throw StateError('Multiple diagnostic fixtures need explicit cleanup');
  }
  final recovering = saved.isNotEmpty;
  final fixtureFilename = recovering
      ? saved.single.name
      : 'm71-background-${DateTime.now().millisecondsSinceEpoch}.txt';
  final upload = _TrackingUpload(base.read(uploadApiProvider), fixtureFilename);
  if (recovering) upload.documentId = saved.single.documentId;
  final productionStorage =
      base.read(storageUploaderProvider) as DioStorageUploader;
  final repository = _CountingDocuments(base.read(documentsRepositoryProvider));
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(minutes: 10),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (error, handler) {
        debugPrint(
          'MILESTONE_7_1_STORAGE_ERROR_${error.type.name}_HTTP_${error.response?.statusCode}_CAUSE_${error.error.runtimeType}',
        );
        final body = error.response?.data;
        if (body is Map) {
          final code = body['code']?.toString() ?? '';
          if (RegExp(r'^[A-Za-z_]{1,40}$').hasMatch(code)) {
            debugPrint('MILESTONE_7_1_STORAGE_CODE_$code');
          }
        }
        handler.next(error);
      },
    ),
  );
  final container = ProviderContainer(
    overrides: [
      pendingUploadStoreProvider.overrideWithValue(pendingStore),
      if (_verificationApi.isNotEmpty)
        generatedApiClientProvider.overrideWithValue(
          base.read(generatedApiClientProvider),
        ),
      storageUploaderProvider.overrideWithValue(
        _PacedStorageUploader(
          tokenProvider: const SupabaseSessionTokenProvider(),
          apiKey: SupabaseConfig.anonKey,
          dio: dio,
          retryAfterBackground: productionStorage.retryAfterBackground,
          canContinue: productionStorage.canContinue,
        ),
      ),
      uploadApiProvider.overrideWithValue(upload),
      documentsRepositoryProvider.overrideWithValue(repository),
    ],
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const CerebroApp()),
  );
  // Explicitly named fixtures can survive a killed diagnostic process. Never
  // delete by prefix: the operator must supply the exact synthetic filename.
  if (_cleanupFilename.isNotEmpty) {
    if (!RegExp(r'^m71-background-\d+\.txt$').hasMatch(_cleanupFilename)) {
      throw StateError('Invalid diagnostic fixture name');
    }
    final fixtures = (await repository.listDocuments()).where(
      (document) => document.title == _cleanupFilename,
    );
    for (final fixture in fixtures) {
      await container.read(deleteDocumentApiProvider).delete(fixture.id);
    }
    if ((await repository.listDocuments()).any(
      (document) => document.title == _cleanupFilename,
    )) {
      throw StateError('Diagnostic fixture cleanup failed');
    }
    debugPrint('MILESTONE_7_1_PREVIOUS_FIXTURE_CLEANUP_PASS');
  }
  var uploadFailed = false;
  container.listen(uploadsProvider, (previous, next) {
    for (final item in next) {
      if (item.filename == fixtureFilename && item.flow.error != null) {
        uploadFailed = true;
        debugPrint(
          'MILESTONE_7_1_UPLOAD_FAILED_${item.flow.error.runtimeType}',
        );
      }
    }
  });
  var backgrounded = false;
  var verifying = false;
  var readsBeforeResume = 0;
  Future<void> verify() async {
    if ((!backgrounded && !_foregroundControl && !recovering) || verifying) {
      return;
    }
    verifying = true;
    try {
      for (var i = 0; i < 300; i++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (uploadFailed) throw StateError('Real upload failed');
        final id = upload.documentId;
        final shown = container.read(documentsListProvider).valueOrNull;
        if (id == null || (!upload.confirmed && !recovering) || shown == null) {
          continue;
        }
        final row = shown.where((d) => d.id == id).singleOrNull;
        if (row?.status != DocumentStatus.ready) {
          if (i % 30 == 0) debugPrint('MILESTONE_7_1_WAITING_FOR_INGEST');
          continue;
        }
        final actual = await repository.getDocument(id);
        if (actual.status != DocumentStatus.ready ||
            repository.reads <= readsBeforeResume) {
          throw StateError('Resume did not refresh completed ingest');
        }
        debugPrint(
          recovering
              ? 'MILESTONE_7_1_PROCESS_DEATH_RECOVERY_PASS'
              : _foregroundControl
              ? 'MILESTONE_7_1_FOREGROUND_CONTROL_PASS'
              : 'MILESTONE_7_1_BACKGROUND_UPLOAD_AND_RESUME_PASS',
        );
        return;
      }
      throw StateError('Ready document was not restored on resume');
    } catch (_) {
      debugPrint('MILESTONE_7_1_CHECK_INCOMPLETE');
    } finally {
      final id = upload.documentId;
      if (id != null && auth.currentUser?.id == ownerId) {
        try {
          await container.read(deleteDocumentApiProvider).delete(id);
          await container.read(documentsListProvider.notifier).refresh();
          if ((await repository.listDocuments()).any((d) => d.id == id)) {
            throw StateError('Cleanup failed');
          }
          debugPrint('MILESTONE_7_1_FIXTURE_CLEANUP_PASS');
        } catch (_) {
          debugPrint('MILESTONE_7_1_FIXTURE_CLEANUP_INCOMPLETE');
        }
      }
    }
  }

  AppLifecycleListener(
    onPause: () {
      backgrounded = true;
      readsBeforeResume = repository.reads;
      debugPrint('MILESTONE_7_1_APP_BACKGROUNDED');
    },
    onResume: verify,
  );
  if (recovering) {
    debugPrint('MILESTONE_7_1_RECOVERING_SAVED_FIXTURE');
    await container.read(uploadsProvider.notifier).restoration;
    await verify();
    return;
  }
  await Future<void>.delayed(const Duration(seconds: 4));
  final chunk = utf8.encode('Synthetic platform upload background test.\n');
  await container
      .read(uploadsProvider.notifier)
      .upload(
        PickedUpload(
          name: fixtureFilename,
          mime: 'text/plain',
          sizeBytes: chunk.length * 15,
          openRead: () => Stream.value(
            List.generate(15, (_) => chunk).expand((bytes) => bytes).toList(),
          ),
        ),
      );
  if (_foregroundControl) await verify();
}
