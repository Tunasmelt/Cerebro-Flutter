import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/network/app_exception.dart';
import '../../../../core/network/generated_api_client_provider.dart';
import '../../../auth/data/supabase_session_token_provider.dart';
import '../documents_list_notifier.dart';
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
  return DioStorageUploader(
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

  @override
  List<UploadItem> build() => const [];

  Future<void> upload(PickedUpload file) async {
    final id = _nextId++;
    _add(
      UploadItem(
        id: id,
        filename: file.name,
        flow: const UploadFlowState.selecting(),
      ),
    );

    final invalid = validateUpload(mime: file.mime, sizeBytes: file.sizeBytes);
    if (invalid != null) {
      _step(id, (flow) => flow.fail(RequestRejectedException(invalid)));
      return;
    }
    final mime = file.mime!;

    _step(id, (flow) => flow.startUpload());

    UploadInit? init;
    final uploadError = await _attempt(() async {
      init = await ref
          .read(uploadApiProvider)
          .init(
            filename: file.name,
            mime: mime,
            sizeBytes: file.sizeBytes,
          );
      await ref
          .read(storageUploaderProvider)
          .put(
            uploadUrl: init!.uploadUrl,
            file: file,
            mime: mime,
            onProgress: (sent, total) => _progress(id, sent, total),
          );
    });
    if (uploadError != null) {
      _step(id, (flow) => flow.fail(uploadError));
      return;
    }
    _step(id, (flow) => flow.uploaded(init!.documentId));

    final confirmError = await _attempt(
      () => ref.read(uploadApiProvider).confirm(init!.documentId),
    );
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
    dismiss(id);
  }

  void dismiss(int id) {
    state = [
      for (final item in state)
        if (item.id != id) item,
    ];
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
        if (item.id == id)
          item.copyWith(flow: transition(item.flow))
        else
          item,
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
