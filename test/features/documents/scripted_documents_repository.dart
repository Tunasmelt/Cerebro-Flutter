import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository.dart';

DocumentDetail detailAt(
  String? ingestState, {
  DocumentStatus status = DocumentStatus.processing,
  String? lastError,
  String id = 'doc-1',
  DateTime? createdAt,
}) => DocumentDetail(
  id: id,
  title: 'report.pdf',
  mime: 'application/pdf',
  sizeBytes: 100,
  status: status,
  createdAt: createdAt ?? DateTime.utc(2026),
  ingestState: ingestState,
  lastError: lastError,
);

DocumentSummary summaryWith(
  DocumentStatus status, {
  String id = 'doc-1',
  int sizeBytes = 100,
  DateTime? createdAt,
}) => DocumentSummary(
  id: id,
  title: 'report.pdf',
  mime: 'application/pdf',
  sizeBytes: sizeBytes,
  originalSizeBytes: sizeBytes,
  status: status,
  createdAt: createdAt ?? DateTime.utc(2026),
);

/// Replays scripted answers in order, then repeats the last one — so a
/// test describes "what the backend says over time" without a timer of
/// its own. An entry that is an [Exception]/[Error] is thrown instead.
class ScriptedDocumentsRepository implements DocumentsRepository {
  ScriptedDocumentsRepository({
    this.details = const [],
    this.lists = const [],
  });

  final List<Object> details;
  final List<Object> lists;

  int detailCalls = 0;
  int listCalls = 0;

  T _next<T>(List<Object> script, int call) {
    final entry = script[call < script.length ? call : script.length - 1];
    if (entry is Exception || entry is Error) throw entry;
    return entry as T;
  }

  @override
  Future<DocumentDetail> getDocument(String documentId) async =>
      _next<DocumentDetail>(details, detailCalls++);

  @override
  Future<List<DocumentSummary>> listDocuments() async =>
      _next<List<DocumentSummary>>(lists, listCalls++);
}
