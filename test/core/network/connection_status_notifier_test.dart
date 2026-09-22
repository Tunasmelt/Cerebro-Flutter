// Milestone 1.3 functional test: real network calls against the real
// deployed Render backend — no mocking, mirroring
// api_client_integration_test.dart's established pattern. This is the
// automatable stand-in for "device network disabled": `flutter test`
// runs in the Dart VM, which has no airplane-mode toggle, so a
// deliberately unreachable host produces the same NetworkUnreachableException
// a disabled device radio would. Requires internet access to run.
import 'package:cerebro_mobile/core/network/api_client.dart';
import 'package:cerebro_mobile/core/network/api_client_provider.dart';
import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/core/network/connection_status_notifier.dart';
import 'package:cerebro_mobile/core/network/session_token_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedTokenProvider implements SessionTokenProvider {
  @override
  String? get currentAccessToken => 'not-a-real-token';
}

void main() {
  group('ConnectionStatusNotifier — real backend integration', () {
    test(
      'resolves successfully against the real deployed backend — the '
      "connected state, distinct from either error state",
      () async {
        final container = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(
              ApiClient(tokenProvider: _FixedTokenProvider()),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(connectionStatusProvider.future);

        expect(
          container.read(connectionStatusProvider),
          const AsyncData<void>(null),
        );
      },
      // Render free-tier instances cold-start; same headroom as
      // api_client_integration_test.dart's own real /health call.
      timeout: const Timeout(Duration(seconds: 75)),
    );

    test(
      'an unreachable host resolves to NetworkUnreachableException, not a '
      'spinner that never settles — the offline state a disabled network '
      'device would also produce',
      () async {
        final container = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(
              ApiClient(
                tokenProvider: _FixedTokenProvider(),
                baseUrl: 'https://this-host-does-not-exist.invalid',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await expectLater(
          container.read(connectionStatusProvider.future),
          throwsA(isA<NetworkUnreachableException>()),
        );

        final state = container.read(connectionStatusProvider);
        expect(state.hasError, isTrue);
        expect(state.error, isA<NetworkUnreachableException>());
      },
    );
  });
}
