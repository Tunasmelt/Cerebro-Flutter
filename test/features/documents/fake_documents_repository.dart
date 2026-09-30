import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository.dart';

/// Test double for [DocumentsRepository] — never touches the real
/// generated client/Supabase. Defaults to an empty list, which is all
/// most nav/auth tests need; configure [documents] or [nextListError]
/// for tests that actually exercise Documents' states.
class FakeDocumentsRepository implements DocumentsRepository {
  FakeDocumentsRepository({List<DocumentSummary>? documents})
    : _documents = documents ?? const [];

  final List<DocumentSummary> _documents;

  /// Set to make the next `listDocuments()` call throw instead.
  Object? nextListError;

  int listCalls = 0;

  @override
  Future<List<DocumentSummary>> listDocuments() async {
    listCalls++;
    final error = nextListError;
    if (error != null) throw error;
    return _documents;
  }

  @override
  Future<DocumentDetail> getDocument(String documentId) async {
    final match = _documents.where((d) => d.id == documentId);
    if (match.isEmpty) {
      throw StateError('No fake document configured for id $documentId');
    }
    final summary = match.first;
    return DocumentDetail(
      id: summary.id,
      title: summary.title,
      mime: summary.mime,
      sizeBytes: summary.sizeBytes,
      status: summary.status,
      createdAt: summary.createdAt,
      ingestState: null,
      lastError: null,
    );
  }
}
