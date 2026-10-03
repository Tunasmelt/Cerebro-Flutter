import 'document.dart';

/// `ingest_jobs.state` — the real values, read from the deployed
/// backend's source (`documents_storage.py`, `ingest/*.py`), not the
/// empty OpenAPI schema. Captures start at `extracting` (they have no
/// normalize stage). `unknown` is the safety net for a value the server
/// adds later: shown as generic "Processing", never a crash.
enum IngestStage {
  uploading,
  normalizing,
  extracting,
  embedding,
  ready,
  failed,
  unknown;

  static IngestStage fromApi(String? value) {
    switch (value) {
      case 'uploading':
        return IngestStage.uploading;
      case 'normalizing':
        return IngestStage.normalizing;
      case 'extracting':
        return IngestStage.extracting;
      case 'embedding':
        return IngestStage.embedding;
      case 'ready':
        return IngestStage.ready;
      case 'failed':
        return IngestStage.failed;
      default:
        return IngestStage.unknown;
    }
  }

  /// Nothing further will happen on its own.
  bool get isTerminal =>
      this == IngestStage.ready || this == IngestStage.failed;

  String get label {
    switch (this) {
      case IngestStage.uploading:
        return 'Uploading';
      case IngestStage.normalizing:
        return 'Preparing file';
      case IngestStage.extracting:
        return 'Reading text';
      case IngestStage.embedding:
        return 'Indexing';
      case IngestStage.ready:
        return 'Ready';
      case IngestStage.failed:
        return 'Failed';
      case IngestStage.unknown:
        return 'Processing';
    }
  }

  /// 0..1 through the pipeline, for the progress bar; null when it can't
  /// be placed (unknown) so the bar stays indeterminate.
  double? get progress {
    switch (this) {
      case IngestStage.uploading:
        return 0.1;
      case IngestStage.normalizing:
        return 0.3;
      case IngestStage.extracting:
        return 0.55;
      case IngestStage.embedding:
        return 0.8;
      case IngestStage.ready:
        return 1;
      case IngestStage.failed:
      case IngestStage.unknown:
        return null;
    }
  }
}

/// Plain-language text for an `ingest_jobs.last_error` code. The codes are
/// the ones the backend's ingest pipeline writes; an unfamiliar one still
/// shows something honest (and keeps the raw code for support) instead of
/// hiding the failure or showing a blank.
String ingestErrorMessage(String? code) {
  switch (code) {
    case null:
    case '':
      return "This document couldn't be processed.";
    case 'file_too_large':
      return 'The file is larger than the 50MB limit.';
    case 'upload_expired':
      return 'The upload never finished, so the document was discarded.';
    case 'corrupt_pdf':
      return "This PDF looks damaged and couldn't be read.";
    case 'corrupt_image':
      return "This image looks damaged and couldn't be read.";
    case 'original_download_failed':
    case 'indexed_upload_failed':
    case 'document_not_found':
      return "The file couldn't be retrieved for processing. Try uploading it again.";
    case 'chunk_insert_failed':
    case 'chunk_update_failed':
      return "The document's text couldn't be saved. Try again in a moment.";
    case 'embed_call_failed':
      return 'The indexing service was unavailable. Try again in a moment.';
    case 'provider_not_configured':
      return "Indexing isn't set up on the server yet.";
    default:
      return "This document couldn't be processed ($code).";
  }
}

/// The document's real status, correcting for how the backend records a
/// retry: on failure it sets `documents.status = failed`, but a retry only
/// resets `ingest_jobs.state` — the document keeps reading `failed` while
/// the job runs again, and flips to `ready` only at the very end. So a
/// `failed` document whose job is running (or has just finished) is not
/// really failed. Everything else is taken at face value.
DocumentStatus effectiveDocumentStatus(DocumentDetail d) {
  if (d.status != DocumentStatus.failed) return d.status;
  switch (IngestStage.fromApi(d.ingestState)) {
    case IngestStage.uploading:
    case IngestStage.normalizing:
    case IngestStage.extracting:
    case IngestStage.embedding:
      return DocumentStatus.processing;
    case IngestStage.ready:
      return DocumentStatus.ready;
    case IngestStage.failed:
    case IngestStage.unknown:
      return DocumentStatus.failed;
  }
}

/// Whether offering "Retry" for this `last_error` can possibly help. False
/// only where there is structurally nothing to resume: the upload never
/// completed, the file was refused for size, or the document is gone.
/// Anything else — including a corrupt-looking file, which a truncated
/// download can cause, and codes the app doesn't know — may succeed.
bool ingestErrorRetryable(String? code) {
  switch (code) {
    case 'upload_expired':
    case 'file_too_large':
    case 'document_not_found':
      return false;
    default:
      return true;
  }
}
