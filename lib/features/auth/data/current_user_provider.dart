import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_notifier.dart';
import 'auth_state.dart';

/// The signed-in user's id, or null when nobody is signed in.
///
/// Anything that holds one user's data (their document list, their
/// in-flight uploads) must `ref.watch` this, so the provider rebuilds —
/// and drops that data — the moment the user changes. Providers live as
/// long as the app's `ProviderScope`, not as long as a session: without
/// this, the next person to sign in on the same device would see the
/// previous user's data until a manual refresh (reproduced in
/// `test/app/user_scoped_state_test.dart`).
///
/// A `Provider` only notifies dependents when its *value* changes, so a
/// token refresh that re-emits the same user doesn't reset anything.
final currentUserIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authNotifierProvider);
  return auth is Authenticated ? auth.userId : null;
});
