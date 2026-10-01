import '../../../../core/network/app_exception.dart';

/// `selecting → uploading → confirming → done`, with `failed` reachable
/// from any non-terminal stage. `uploading` covers `upload-init` and the
/// direct-to-Storage PUT (the web page's same grouping); `confirming` is
/// `upload-confirm`.
enum UploadStage { selecting, uploading, confirming, done, failed }

/// Thrown on a transition the flow must never make — e.g. reaching
/// `done` without `confirming` having succeeded. A programming error, not
/// a runtime condition: callers should never catch it.
final class IllegalUploadTransition extends StateError {
  IllegalUploadTransition(UploadStage from, String attempted)
    : super('Illegal upload transition: $attempted from ${from.name}');
}

/// Immutable local state of one upload's flow. The only way to change
/// stage is through the transition methods, each of which validates the
/// current stage — so "done without confirming" isn't representable.
final class UploadFlowState {
  const UploadFlowState._(
    this.stage, {
    this.failedAt,
    this.error,
    this.documentId,
  });

  const UploadFlowState.selecting() : this._(UploadStage.selecting);

  final UploadStage stage;

  /// The stage that was in progress when this flow failed.
  final UploadStage? failedAt;
  final AppException? error;

  /// Known once `upload-init` has succeeded and the bytes are in Storage.
  final String? documentId;

  bool get isTerminal =>
      stage == UploadStage.done || stage == UploadStage.failed;

  /// selecting → uploading
  UploadFlowState startUpload() {
    if (stage != UploadStage.selecting) {
      throw IllegalUploadTransition(stage, 'startUpload');
    }
    return const UploadFlowState._(UploadStage.uploading);
  }

  /// uploading → confirming (init succeeded AND the PUT succeeded)
  UploadFlowState uploaded(String documentId) {
    if (stage != UploadStage.uploading) {
      throw IllegalUploadTransition(stage, 'uploaded');
    }
    return UploadFlowState._(UploadStage.confirming, documentId: documentId);
  }

  /// confirming → done (only `upload-confirm` succeeding gets here)
  UploadFlowState confirmed() {
    if (stage != UploadStage.confirming) {
      throw IllegalUploadTransition(stage, 'confirmed');
    }
    return UploadFlowState._(UploadStage.done, documentId: documentId);
  }

  /// Any non-terminal stage → failed, remembering where it failed.
  UploadFlowState fail(AppException error) {
    if (isTerminal) throw IllegalUploadTransition(stage, 'fail');
    return UploadFlowState._(
      UploadStage.failed,
      failedAt: stage,
      error: error,
      documentId: documentId,
    );
  }
}
