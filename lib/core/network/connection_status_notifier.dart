import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client_provider.dart';

final connectionStatusProvider = AsyncNotifierProvider<ConnectionStatusNotifier, void>(
  ConnectionStatusNotifier.new,
);

/// Drives Settings' "Connection" row: a real call to the deployed
/// backend's `/health` endpoint via the app's single [ApiClient] (see
/// `api_client.dart`'s `health()`), so Milestone 1.3's shared
/// error-display framework has one real, wired-in caller — offline vs.
/// server-error vs. connected is a genuine network outcome here, not a
/// simulated state, even though no feature screen with its own
/// real backend calls exists yet (that's Phase 2).
class ConnectionStatusNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() => checkConnection();

  /// Not private, on purpose: tests fake just this one call (a real
  /// `ApiClient.health()` needs a real network round trip and, through
  /// `apiClientProvider`, a real initialized Supabase instance for the
  /// token — neither of which belongs in an ordinary widget test) by
  /// subclassing and overriding this method, rather than reaching
  /// through the whole provider graph.
  @visibleForTesting
  Future<void> checkConnection() async {
    await ref.read(apiClientProvider).health();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(checkConnection);
  }
}
