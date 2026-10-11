import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/network/app_exception.dart';
import '../../../../core/network/generated_api_client_provider.dart';
import '../../../auth/data/current_user_provider.dart';
import '../../../auth/data/supabase_session_token_provider.dart';
import '../documents_list_notifier.dart';
import '../documents_repository_provider.dart';
import 'pending_upload_store.dart';
import 'picked_upload.dart';
import 'storage_uploader.dart';
import 'upload_api.dart';
import 'upload_constraints.dart';
import 'upload_picker.dart';
import 'upload_state.dart';

final uploadApiProvider = Provider<UploadApi>((ref) {
  return ApiUploadApi(ref.watch(generatedApiClientProvider));
});

final storageUploaderProvider = Provider<StorageUploader>((ref) {
  final owner = ref.read(currentUserIdProvider);
  var active = true;
  final cancellations = <VoidCallback>{};
  ref.listen(currentUserIdProvider, (_, next) {
    if (next == owner) return;
    active = false;
    for (final cancel in cancellations.toList()) {
      cancel();
    }
    ref.invalidateSelf();
  });
  ref.onDispose(() {
    active = false;
    for (final cancel in cancellations.toList()) {
      cancel();
    }
  });
  bool canContinue() =>
      active && owner != null && ref.read(currentUserIdProvider) == owner;
  Future<bool> retryAfterBackground() async {
    if (!canContinue()) return false;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != AppLifecycleState.paused &&
        lifecycle != AppLifecycleState.hidden &&
        lifecycle != AppLifecycleState.inactive) {
      return false;
    }
    final resumed = Completer<bool>();
    void finish(bool allowed) {
      if (!resumed.isCompleted) resumed.complete(allowed);
    }

    void cancel() => finish(false);
    final listener = AppLifecycleListener(onResume: () => finish(true));
    cancellations.add(cancel);
    try {
      return await resumed.future.timeout(
            const Duration(minutes: 10),
            onTimeout: () => false,
          ) &&
          canContinue();
    } finally {
      cancellations.remove(cancel);
      listener.dispose();
    }
  }

  return DioStorageUploader(
    canContinue: canContinue,
    retryAfterBackground: retryAfterBackground,
    tokenProvider: const SupabaseSessionTokenProvider(),
    apiKey: SupabaseConfig.anonKey,
  );
});

final uploadPickerProvider = Provider<UploadPicker>((ref) {
  return DeviceUploadPicker();
});

/// One in-flight (or just-failed) upload as the UI shows it.
class UploadItem {
  const UploadItem({
    required this.id,
    required this.filename,
    required this.flow,
    this.progress,
  });

  final int id;
  final String filename;
  final UploadFlowState flow;

  /// 0..1 while the bytes are going to Storage, null otherwise.
  final double? progress;

  UploadItem copyWith({UploadFlowState? flow, double? progress}) => UploadItem(
    id: id,
    filename: filename,
    flow: flow ?? this.flow,
    progress: progress,
  );
}

final uploadsProvider = NotifierProvider<UploadController, List<UploadItem>>(
  UploadController.new,
);

/// Runs `upload-init → PUT → upload-confirm` for each picked file,
/// stepping each one's [UploadFlowState] — which is what guarantees the
/// invariant this milestone exists to prove: `upload-confirm` is only ever
/// called after the PUT succeeded, and `done` is only reachable after
/// `upload-confirm` succeeded.
class UploadController extends Notifier<List<UploadItem>> {
  int _nextId = 0;

  /// Bumped every time the signed-in user changes (see `build`). An upload
  /// started under one user must never carry on under the next: after any
  /// `await` it compares against the generation it started with and stops.
  int _generation = 0;
  String? _owner;
  final _pending = <int, PendingUpload>{};
  Future<void>? _restoring;
  Future<void> get restoration => _restoring ?? Future<void>.value();

  @override
  List<UploadItem> build() {
    // Watched so the previous user's upload rows (filenames, errors) are
    // dropped when someone else signs in, and their flows are abandoned.
    final owner = ref.watch(currentUserIdProvider);
    _generation++;
    ref.onDispose(() => _generation++);
    final store = ref.read(pendingUploadStoreProvider);
    final previousOwner = _owner;
    _owner = owner;
    _pending.clear();
    if (store != null && previousOwner != null && previousOwner != owner) {
      unawaited(store.clear(previousOwner).catchError((Object _) {}));
    }
    final generation = _generation;
    _restoring = store != null && owner != null
        ? Future(() => _restore(store, owner, generation))
        : null;
    return const [];
  }

  Future<void> _restore(
    PendingUploadStore store,
    String owner,
    int generation,
  ) async {
    try {
      for (final pending in await store.load(owner)) {
        if (generation != _generation) return;
        await upload(pending.file, restored: pending);
      }
    } catch (_) {
      if (generation == _generation) {
        _add(
          UploadItem(
            id: _nextId++,
            filename: 'Saved upload',
            flow: const UploadFlowState.selecting().fail(
              const UnknownApiException(
                'Could not restore saved uploads. Reopen the app to try again.',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> upload(PickedUpload file, {PendingUpload? restored}) async {
    final generation = _generation;
    if (restored == null) await _restoring;
    if (generation != _generation) return;
    final id = _nextId++;
    if (restored != null) _pending[id] = restored;
    _add(
      UploadItem(
        id: id,
        filename: file.name,
        flow: const UploadFlowState.selecting(),
      ),
    );

    final invalid = validateUpload(
      mime: file.mime,
      sizeBytes: file.sizeBytes,
      fileName: file.name,
    );
    if (invalid != null) {
      _step(id, (flow) => flow.fail(RequestRejectedException(invalid)));
      return;
    }
    final mime = file.mime!;

    _step(id, (flow) => flow.startUpload());

    UploadInit? init;
    PendingUpload? pending = restored;
    var alreadyConfirmed = false;
    final uploadError = await _attempt(() async {
      final store = ref.read(pendingUploadStoreProvider);
      if (pending == null && store != null && _owner != null) {
        pending = await store.save(_owner!, file);
      }
      if (generation != _generation) {
        await pending?.remove();
        return;
      }
      if (pending != null) {
        _pending[id] = pending!;
        file = pending!.file;
      }
      final api = ref.read(uploadApiProvider);
      final documentId = pending?.documentId;
      if (documentId != null) {
        final document = await ref
            .read(documentsRepositoryProvider)
            .getDocument(documentId);
        if (generation != _generation) return;
        if (const [
          'normalizing',
          'extracting',
          'embedding',
          'ready',
        ].contains(document.ingestState)) {
          // A lost confirm response must not restart an active/finished ingest.
          alreadyConfirmed = true;
          return;
        }
        if (document.ingestState != 'uploading' &&
            document.lastError != 'upload_expired') {
          throw const RequestRejectedException(
            'This upload cannot be resumed.',
            code: 'upload_not_resumable',
          );
        }
        try {
          // The process may have died after Storage accepted the last byte.
          await api.confirm(documentId);
          alreadyConfirmed = true;
          return;
        } on RequestRejectedException catch (error) {
          if (error.code != 'upload_not_found') rethrow;
        }
        if (generation != _generation) return;
        await pending?.verifyBytes();
        if (generation != _generation) return;
        init = await api.resume(documentId);
      } else {
        await pending?.verifyBytes();
        if (generation != _generation) return;
        init = await api.init(
          filename: file.name,
          mime: mime,
          sizeBytes: file.sizeBytes,
        );
        pending?.documentId = init!.documentId;
        await pending?.checkpoint();
      }
      if (generation != _generation) return;
      if (alreadyConfirmed) return;
      await ref
          .read(storageUploaderProvider)
          .put(
            uploadUrl: init!.uploadUrl,
            file: file,
            mime: mime,
            onProgress: (sent, total) => _progress(id, sent, total),
          );
    });
    if (generation != _generation) return;
    if (uploadError != null) {
      _step(id, (flow) => flow.fail(uploadError));
      return;
    }
    if (alreadyConfirmed) {
      if (ref.exists(documentsListProvider)) {
        await ref.read(documentsListProvider.notifier).refresh();
      }
      if (generation != _generation) return;
      await dismiss(id);
      return;
    }
    _step(id, (flow) => flow.uploaded(init!.documentId));

    final confirmError = await _attempt(
      () => ref.read(uploadApiProvider).confirm(init!.documentId),
    );
    if (generation != _generation) return;
    if (confirmError != null) {
      _step(id, (flow) => flow.fail(confirmError));
      return;
    }
    _step(id, (flow) => flow.confirmed());

    // The real document now exists server-side; show it in the list, then
    // drop the in-flight row. Only refresh a list that has been built —
    // reading the notifier of one that hasn't would build it (one fetch)
    // and then refresh it (a second); an unbuilt list simply fetches
    // fresh the next time the Documents screen opens.
    if (ref.exists(documentsListProvider)) {
      await ref.read(documentsListProvider.notifier).refresh();
    }
    if (generation != _generation) return;
    await dismiss(id);
  }

  Future<void> dismiss(int id) async {
    final pending = _pending.remove(id);
    state = [
      for (final item in state)
        if (item.id != id) item,
    ];
    if (pending != null) await pending.remove().catchError((Object _) {});
  }

  /// Runs one network step. Anything that isn't already an [AppException]
  /// becomes a generic one, so a surprise (a malformed response, say) can
  /// never leave an upload stuck in `uploading` forever. Transitions run
  /// outside this, so a real `IllegalUploadTransition` bug still surfaces.
  Future<AppException?> _attempt(Future<void> Function() step) async {
    try {
      await step();
      return null;
    } on AppException catch (e) {
      return e;
    } catch (_) {
      return const UnknownApiException();
    }
  }

  void _add(UploadItem item) => state = [...state, item];

  void _step(int id, UploadFlowState Function(UploadFlowState) transition) {
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(flow: transition(item.flow)) else item,
    ];
  }

  void _progress(int id, int sent, int total) {
    if (total <= 0) return;
    state = [
      for (final item in state)
        if (item.id == id && item.flow.stage == UploadStage.uploading)
          item.copyWith(progress: sent / total)
        else
          item,
    ];
  }
}
