// Milestone 0.3 functional test: real network calls against the real
// deployed Render backend — no mocking. Requires internet access to run.
import 'package:cerebro_mobile/core/network/api_client.dart';
import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/core/network/session_token_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoSessionTokenProvider implements SessionTokenProvider {
  @override
  String? get currentAccessToken => null;
}

class _FixedTokenProvider implements SessionTokenProvider {
  @override
  String? get currentAccessToken => 'not-a-real-token';
}

void main() {
  group('ApiClient — real backend integration', () {
    test(
      'GET /health against the real deployed Render service succeeds',
      () async {
        final client = ApiClient(tokenProvider: _FixedTokenProvider());

        final response = await client.health();

        expect(response.statusCode, 200);
        expect(response.data?['status'], 'ok');
      },
      // Render free-tier instances cold-start; give it room. Must stay
      // above ApiClient's own receiveTimeout (60s) or the outer test
      // timeout fires first and masks the real behavior being tested.
      timeout: const Timeout(Duration(seconds: 75)),
    );

    test(
      'a request to a deliberately wrong host produces NetworkUnreachableException, not a crash',
      () async {
        final client = ApiClient(
          tokenProvider: _FixedTokenProvider(),
          baseUrl: 'https://this-host-does-not-exist.invalid',
        );

        await expectLater(
          client.health(),
          throwsA(isA<NetworkUnreachableException>()),
        );
      },
    );

    test(
      'a request with no active session fails fast with UnauthenticatedException before hitting the network',
      () async {
        final client = ApiClient(tokenProvider: _NoSessionTokenProvider());

        await expectLater(
          client.health(),
          throwsA(isA<UnauthenticatedException>()),
        );
      },
    );
  });
}
