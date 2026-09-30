import 'package:chopper/chopper.dart';

import '../../../core/network/generated/cerebro_api.swagger.dart';
import 'document.dart';
import 'documents_error_mapper.dart';

/// Real backend contract confirmed from
/// `services/api/app/routes/documents.py` (the OpenAPI spec itself has
/// no schemas for these — see CHANGELOG): `GET /documents` is a flat,
/// RLS-scoped list, not cursor-paginated. No client-side pagination
/// exists here because the server has none to page through.
abstract interface class DocumentsRepository {
  Future<List<DocumentSummary>> listDocuments();
  Future<DocumentDetail> getDocument(String documentId);
}

class ApiDocumentsRepository implements DocumentsRepository {
  ApiDocumentsRepository(this._api);

  final CerebroApi _api;

  @override
  Future<List<DocumentSummary>> listDocuments() async {
    final response = await _run(_api.apiV1DocumentsGet());
    final body = response.body as Map<String, dynamic>;
    final rows = body['documents'] as List<dynamic>;
    return rows
        .map((row) => DocumentSummary.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<DocumentDetail> getDocument(String documentId) async {
    final response = await _run(
      _api.apiV1DocumentsDocumentIdGet(documentId: documentId),
    );
    return DocumentDetail.fromJson(response.body as Map<String, dynamic>);
  }

  /// The one place a Chopper call's outcome is inspected — never lets a
  /// raw exception or a failed-but-not-thrown `Response` escape this
  /// class, mirroring `ApiClient.get`'s same rule for the other stack.
  Future<Response> _run(Future<Response> request) async {
    final Response response;
    try {
      response = await request;
    } catch (error) {
      throw DocumentsErrorMapper.ofException(error);
    }
    if (!response.isSuccessful) {
      throw DocumentsErrorMapper.ofResponse(response);
    }
    return response;
  }
}
