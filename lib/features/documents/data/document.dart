/// Real values confirmed from the deployed backend's actual source
/// (`services/api/app/core/documents_storage.py` and
/// `apps/web/src/lib/graph/types.ts`'s `DocumentStatus`), not the
/// (empty) OpenAPI schema — see this milestone's CHANGELOG entry for
/// why the spec alone wasn't enough. `unknown` is a safety net for a
/// value the server adds later, never a crash.
enum DocumentStatus { processing, ready, failed, sealed, unknown }

DocumentStatus _statusFromApi(String? value) {
  switch (value) {
    case 'processing':
      return DocumentStatus.processing;
    case 'ready':
      return DocumentStatus.ready;
    case 'failed':
      return DocumentStatus.failed;
    case 'sealed':
      return DocumentStatus.sealed;
    default:
      return DocumentStatus.unknown;
  }
}

/// One row of `GET /api/v1/documents`'s flat list — confirmed not
/// cursor-paginated in practice (see CHANGELOG), so this is simply
/// every field the server actually returns per document.
class DocumentSummary {
  const DocumentSummary({
    required this.id,
    required this.title,
    required this.mime,
    required this.sizeBytes,
    required this.originalSizeBytes,
    required this.status,
    required this.createdAt,
  });

  factory DocumentSummary.fromJson(Map<String, dynamic> json) {
    return DocumentSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      mime: json['mime'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      originalSizeBytes: (json['original_size_bytes'] as num?)?.toInt(),
      status: _statusFromApi(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String title;
  final String mime;
  final int sizeBytes;
  final int? originalSizeBytes;
  final DocumentStatus status;
  final DateTime createdAt;
}

/// `GET /api/v1/documents/{id}`'s shape — a real subset/superset
/// mismatch against the list row, confirmed from the same backend
/// source: no `original_size_bytes` here, but `ingest_state`/
/// `last_error` are folded in from the document's `ingest_jobs` row
/// (Stage 3.6's design — see the backend's own docstring).
class DocumentDetail {
  const DocumentDetail({
    required this.id,
    required this.title,
    required this.mime,
    required this.sizeBytes,
    required this.status,
    required this.createdAt,
    required this.ingestState,
    required this.lastError,
  });

  factory DocumentDetail.fromJson(Map<String, dynamic> json) {
    return DocumentDetail(
      id: json['id'] as String,
      title: json['title'] as String,
      mime: json['mime'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      status: _statusFromApi(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      ingestState: json['ingest_state'] as String?,
      lastError: json['last_error'] as String?,
    );
  }

  final String id;
  final String title;
  final String mime;
  final int sizeBytes;
  final DocumentStatus status;
  final DateTime createdAt;
  final String? ingestState;
  final String? lastError;
}
