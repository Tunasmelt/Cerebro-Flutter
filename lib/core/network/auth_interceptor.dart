import 'package:dio/dio.dart';

import 'app_exception.dart';
import 'session_token_provider.dart';

/// Attaches the Supabase session JWT to every outgoing request. A single
/// interceptor here, rather than each call site remembering to attach
/// it — one point of failure instead of N, per flutter-rules.md.
///
/// **Documented policy for no active session:** fail fast. The request
/// is rejected with [UnauthenticatedException] before it's sent, rather
/// than silently going out with no `Authorization` header. A request
/// that needs auth and has none isn't a request worth making.
final class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenProvider);

  final SessionTokenProvider _tokenProvider;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final token = _tokenProvider.currentAccessToken;
    if (token == null) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: const UnauthenticatedException(),
          type: DioExceptionType.unknown,
        ),
      );
      return;
    }

    options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }
}
