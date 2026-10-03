import 'package:chopper/chopper.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/generated/cerebro_api.swagger.dart';
import 'documents_error_mapper.dart';

/// `DELETE /documents/{id}`: removes the document's stored file (best
/// effort) and its row, which cascades chunks, ingest job and graph edges.
/// `200` when deleted; `404 not_found` when there is no such document (never
/// existed, or already deleted).
abstract interface class DeleteDocumentApi {
  Future<void> delete(String documentId);
}

class ApiDeleteDocumentApi implements DeleteDocumentApi {
  ApiDeleteDocumentApi(this._api);

  final CerebroApi _api;

  @override
  Future<void> delete(String documentId) async {
    final Response response;
    try {
      response = await _api.apiV1DocumentsDocumentIdDelete(
        documentId: documentId,
      );
    } catch (error) {
      throw DocumentsErrorMapper.ofException(error);
    }
    if (!response.isSuccessful) {
      throw DocumentsErrorMapper.ofResponse(response);
    }
  }
}

/// "Already gone" is the state the user asked for, so a 404 from the server
/// counts as a successful delete rather than an error to show.
bool isAlreadyDeleted(AppException error) =>
    error is RequestRejectedException && error.code == 'not_found';
