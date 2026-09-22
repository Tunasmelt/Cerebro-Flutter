import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/core/network/auth_interceptor.dart';
import 'package:cerebro_mobile/core/network/session_token_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTokenProvider implements SessionTokenProvider {
  _FakeTokenProvider(this.token);

  final String? token;

  @override
  String? get currentAccessToken => token;
}

void main() {
  group('AuthInterceptor', () {
    test('attaches the Authorization header from the current session', () {
      final interceptor = AuthInterceptor(_FakeTokenProvider('abc123'));
      final options = RequestOptions(path: '/documents');
      final handler = _RecordingHandler();

      interceptor.onRequest(options, handler);

      expect(handler.rejected, isFalse);
      expect(handler.nextOptions, isNotNull);
      expect(handler.nextOptions?.headers['Authorization'], 'Bearer abc123');
    });

    test(
      'fails fast with UnauthenticatedException when there is no session',
      () {
        final interceptor = AuthInterceptor(_FakeTokenProvider(null));
        final options = RequestOptions(path: '/documents');
        final handler = _RecordingHandler();

        interceptor.onRequest(options, handler);

        expect(handler.rejected, isTrue);
        expect(handler.nextOptions, isNull);
        expect(handler.rejectedError?.error, isA<UnauthenticatedException>());
      },
    );
  });
}

/// Minimal recording double for [RequestInterceptorHandler] — the real
/// class can't be constructed directly outside Dio's internals, so this
/// tracks what the interceptor decided (next vs. reject) without
/// needing the full Dio request pipeline running.
class _RecordingHandler implements RequestInterceptorHandler {
  RequestOptions? nextOptions;
  bool rejected = false;
  DioException? rejectedError;

  @override
  void next(RequestOptions requestOptions) {
    nextOptions = requestOptions;
  }

  @override
  void reject(
    DioException error, [
    bool callFollowingErrorInterceptor = false,
  ]) {
    rejected = true;
    rejectedError = error;
  }

  @override
  void resolve(
    Response response, [
    bool callFollowingResponseInterceptor = false,
  ]) {
    throw UnimplementedError('not exercised by these tests');
  }

  @override
  void noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
