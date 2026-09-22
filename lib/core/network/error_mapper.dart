import 'package:dio/dio.dart';

import 'app_exception.dart';

/// Maps a [DioException] to a typed [AppException]. The only place this
/// mapping happens — call sites never inspect `DioExceptionType` or
/// status codes themselves.
abstract final class ErrorMapper {
  static AppException map(DioException error) {
    // AuthInterceptor rejects with our own typed exception already
    // attached — pass it straight through instead of re-mapping it.
    final carried = error.error;
    if (carried is AppException) return carried;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return const NetworkUnreachableException();
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401) return const UnauthorizedException();
        if (statusCode != null && statusCode >= 500) {
          return ServerErrorException(statusCode);
        }
        return UnknownApiException('Unexpected status code $statusCode');
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return UnknownApiException(error.message);
    }
  }
}
