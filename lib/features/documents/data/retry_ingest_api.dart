import 'package:chopper/chopper.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/generated/cerebro_api.swagger.dart';
import 'documents_error_mapper.dart';

/// `POST /documents/{id}/retry-ingest`: resumes a failed job from the
/// stage it is safe to resume from (the server decides which). Answers
/// `202` once the job has been reset and the work scheduled; `404
/// not_found` when the document has no job, `409 not_retryable` when the
/// job isn't in a failed state (e.g. already retried from another device).
abstract interface class RetryIngestApi {
  Future<void> retry(String documentId);
}

class ApiRetryIngestApi implements RetryIngestApi {
  ApiRetryIngestApi(this._api);

  final CerebroApi _api;

  @override
  Future<void> retry(String documentId) async {
    final Response response;
    try {
      response = await _api.apiV1DocumentsDocumentIdRetryIngestPost(
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

/// Plain-language text for the two refusals the endpoint can give.
/// Anything else keeps the mapper's message.
AppException friendlyRetryError(AppException error) {
  if (error is RequestRejectedException) {
    switch (error.code) {
      case 'not_retryable':
        return const RequestRejectedException(
          "This document isn't in a failed state any more.",
          code: 'not_retryable',
        );
      case 'not_found':
        return const RequestRejectedException(
          'There is nothing left to retry for this document.',
          code: 'not_found',
        );
    }
  }
  return error;
}
