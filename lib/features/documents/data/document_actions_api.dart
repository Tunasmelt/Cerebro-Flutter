import 'package:chopper/chopper.dart';

import '../../../core/network/generated/cerebro_api.swagger.dart';
import 'documents_error_mapper.dart';

/// Rename a document and capture a note. Both are thin wrappers over the
/// backend (`PATCH /documents/{id}` and `POST /documents/capture`); the rules
/// live there and are mirrored in [validateDocumentTitle] / [validateNoteText]
/// only to give fast feedback.
abstract interface class DocumentActionsApi {
  /// `PATCH /documents/{id}` with `{title}`. `404 not_found` if the document is
  /// gone, `422 empty_title`, `413 title_too_long`.
  Future<void> rename(String documentId, String title);

  /// `POST /documents/capture` with `{text, title?}`: a thought typed
  /// directly, run through the same extract and embed pipeline as an upload.
  /// Returns the new document's id.
  Future<String> createNote({required String text, String? title});
}

/// The server's limits (`MAX_CAPTURE_CHARS`, and the title cap in
/// `rename_document`).
const int maxNoteChars = 20000;
const int maxTitleChars = 500;

/// Null when [title] is acceptable, otherwise a message to show. The server
/// trims, so a title of spaces is empty.
String? validateDocumentTitle(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) return 'Enter a name.';
  if (trimmed.runes.length > maxTitleChars) {
    return 'Keep the name under $maxTitleChars characters.';
  }
  return null;
}

/// Null when [text] can be saved as a note. Length counts characters the way
/// the server does (code points, after trimming).
String? validateNoteText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 'Write something first.';
  if (trimmed.runes.length > maxNoteChars) {
    return 'A note can be up to $maxNoteChars characters.';
  }
  return null;
}

class ApiDocumentActionsApi implements DocumentActionsApi {
  ApiDocumentActionsApi(this._api);

  final CerebroApi _api;

  @override
  Future<void> rename(String documentId, String title) async {
    await _run(
      _api.apiV1DocumentsDocumentIdPatch(
        documentId: documentId,
        body: RenameDocumentBody(title: title),
      ),
    );
  }

  @override
  Future<String> createNote({required String text, String? title}) async {
    final response = await _run(
      _api.apiV1DocumentsCapturePost(
        body: CaptureBody(text: text, title: title),
      ),
    );
    final body = response.body;
    final id = body is Map<String, dynamic> ? body['id'] : null;
    if (id is! String || id.isEmpty) {
      throw DocumentsErrorMapper.ofException(
        const FormatException('capture response had no id'),
      );
    }
    return id;
  }

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
