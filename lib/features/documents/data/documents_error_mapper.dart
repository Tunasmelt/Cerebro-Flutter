import 'dart:async';
import 'dart:io';

import 'package:chopper/chopper.dart';

import '../../../core/network/app_exception.dart';

/// Maps a Chopper failure to the same [AppException] hierarchy
/// `ErrorMapper` (Milestone 0.3) uses for the hand-rolled `ApiClient` —
/// one error framework across both HTTP stacks, per Milestone 1.3's
/// "shared error-display pattern" requirement. Chopper doesn't throw on
/// a non-2xx response the way Dio does, so callers check
/// `response.isSuccessful` themselves and pass the failed response here;
/// [ofException] handles the connection-level failures Chopper does
/// throw for (no route to the server at all).
abstract final class DocumentsErrorMapper {
  static AppException ofResponse(Response response) {
    final statusCode = response.statusCode;
    if (statusCode == 401) return const UnauthorizedException();
    if (statusCode >= 500) return ServerErrorException(statusCode);
    if (statusCode == 404) {
      return const UnknownApiException('Not found');
    }
    return UnknownApiException('Unexpected status code $statusCode');
  }

  static AppException ofException(Object error) {
    if (error is StateError) {
      // GeneratedApiAuthInterceptor's fail-fast no-session signal.
      return const UnauthenticatedException();
    }
    if (error is SocketException ||
        error is TimeoutException ||
        error is HttpException) {
      return const NetworkUnreachableException();
    }
    return UnknownApiException(error.toString());
  }
}
