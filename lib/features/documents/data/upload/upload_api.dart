import 'package:chopper/chopper.dart';

import '../../../../core/network/app_exception.dart';
import '../../../../core/network/generated/cerebro_api.swagger.dart';
import '../documents_error_mapper.dart';

/// `upload-init`'s `201` body: the new document's id and a short-lived
/// (60s, per the backend) Supabase signed upload URL.
class UploadInit {
  const UploadInit({required this.documentId, required this.uploadUrl});

  final String documentId;
  final Uri uploadUrl;
}

/// `upload-confirm`'s `200` body. `state` is the job's new state —
/// `normalizing` once the server has verified the object exists.
class UploadConfirmation {
  const UploadConfirmation({
    required this.documentId,
    required this.state,
    required this.sizeBytes,
  });

  final String documentId;
  final String state;
  final int sizeBytes;
}

/// The two backend calls that bracket the direct-to-Storage PUT. Shapes
/// confirmed from `services/api/app/routes/documents.py` (the OpenAPI
/// spec has no response schemas — see Milestone 0.4's finding).
abstract interface class UploadApi {
  Future<UploadInit> init({
    required String filename,
    required String mime,
    required int sizeBytes,
  });

  Future<UploadConfirmation> confirm(String documentId);
}

class ApiUploadApi implements UploadApi {
  ApiUploadApi(this._api);

  final CerebroApi _api;

  @override
  Future<UploadInit> init({
    required String filename,
    required String mime,
    required int sizeBytes,
  }) async {
    final response = await _run(
      _api.apiV1DocumentsUploadInitPost(
        body: UploadInitBody(
          filename: filename,
          mime: mime,
          sizeBytes: sizeBytes,
        ),
      ),
    );
    final body = _asMap(response);
    return UploadInit(
      documentId: body['id'] as String,
      uploadUrl: Uri.parse(body['upload_url'] as String),
    );
  }

  @override
  Future<UploadConfirmation> confirm(String documentId) async {
    final response = await _run(
      _api.apiV1DocumentsDocumentIdUploadConfirmPost(documentId: documentId),
    );
    final body = _asMap(response);
    return UploadConfirmation(
      documentId: body['id'] as String,
      state: body['state'] as String,
      sizeBytes: (body['size_bytes'] as num).toInt(),
    );
  }

  Map<String, dynamic> _asMap(Response response) {
    final body = response.body;
    if (body is Map<String, dynamic>) return body;
    throw const UnknownApiException('Unexpected response from the server.');
  }

  /// Same contract as `ApiDocumentsRepository._run`: a raw exception or a
  /// failed-but-not-thrown `Response` never escapes this class.
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
