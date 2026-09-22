import 'package:cerebro_mobile/core/network/connection_status_notifier.dart';

/// Test double for [ConnectionStatusNotifier] — overrides only the one
/// network call, never touches `apiClientProvider`/Supabase. Widget
/// tests that render `SettingsScreen` incidentally (e.g. auth or nav
/// tests) should override [connectionStatusProvider] with an instance
/// of this configured to succeed immediately, so they don't perform a
/// real network call.
class FakeConnectionStatusNotifier extends ConnectionStatusNotifier {
  FakeConnectionStatusNotifier(this._outcome);

  final Future<void> Function() _outcome;

  int checkCount = 0;

  @override
  Future<void> checkConnection() {
    checkCount++;
    return _outcome();
  }
}
