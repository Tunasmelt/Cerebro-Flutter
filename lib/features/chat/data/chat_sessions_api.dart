import 'package:chopper/chopper.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/generated/cerebro_api.swagger.dart';
import '../../documents/data/documents_error_mapper.dart';

/// `POST /chat/sessions`: starts a conversation and returns its id.
abstract interface class ChatSessionsApi {
  Future<String> create();
}

class ApiChatSessionsApi implements ChatSessionsApi {
  ApiChatSessionsApi(this._api);

  final CerebroApi _api;

  @override
  Future<String> create() async {
    final Response response;
    try {
      response = await _api.apiV1ChatSessionsPost();
    } catch (error) {
      throw DocumentsErrorMapper.ofException(error);
    }
    if (!response.isSuccessful) {
      throw DocumentsErrorMapper.ofResponse(response);
    }
    final body = response.body;
    final id = body is Map<String, dynamic> ? body['id'] : null;
    if (id is! String || id.isEmpty) {
      throw const UnknownApiException('Unexpected response from the server.');
    }
    return id;
  }
}
