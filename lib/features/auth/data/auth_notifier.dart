import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'auth_exception.dart';
import 'auth_repository.dart';
import 'auth_state.dart';
import 'supabase_auth_repository.dart';

/// Overridden in tests with a fake — never touches a real Supabase
/// client in a unit test, per `core/network/session_token_provider.dart`'s
/// established pattern in this codebase.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(supabase.Supabase.instance.client.auth);
});

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final repository = ref.watch(authRepositoryProvider);
    final subscription = repository.userIdChanges.listen(_onUserIdChanged);
    ref.onDispose(subscription.cancel);

    final currentUserId = repository.currentUserId;
    return currentUserId != null
        ? Authenticated(currentUserId)
        : const Unauthenticated();
  }

  void _onUserIdChanged(String? userId) {
    // Sign-up's own AwaitingEmailConfirmation state shouldn't be
    // clobbered by a stray null-session event from the same call.
    if (state is AwaitingEmailConfirmation && userId == null) return;
    state = userId != null ? Authenticated(userId) : const Unauthenticated();
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AuthLoading();
    try {
      await ref.read(authRepositoryProvider).signIn(
        email: email,
        password: password,
      );
      // _onUserIdChanged also fires from the auth-state stream; setting
      // it here too keeps the transition synchronous for callers/tests
      // that don't want to wait a stream tick.
      final userId = ref.read(authRepositoryProvider).currentUserId;
      if (userId != null) state = Authenticated(userId);
    } on AuthFailureException catch (e) {
      state = Unauthenticated(errorMessage: e.message);
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    state = const AuthLoading();
    try {
      final outcome = await ref
          .read(authRepositoryProvider)
          .signUp(email: email, password: password);
      state = switch (outcome) {
        SignUpOutcome.needsEmailConfirmation => AwaitingEmailConfirmation(email),
        SignUpOutcome.sessionCreated => Authenticated(
          ref.read(authRepositoryProvider).currentUserId!,
        ),
      };
    } on AuthFailureException catch (e) {
      state = Unauthenticated(errorMessage: e.message);
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const Unauthenticated();
  }
}
