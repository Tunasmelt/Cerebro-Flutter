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
    final subscription = repository.userIdChanges.listen(
      _onUserIdChanged,
      onError: _onAuthStreamError,
    );
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

  /// Errors that arrive on the auth stream instead of being thrown from a
  /// call — chiefly a failed confirmation deep link. Without a handler
  /// these surface as unhandled zone errors and the user sees nothing.
  void _onAuthStreamError(Object error, StackTrace stackTrace) {
    final message = error is AuthFailureException
        ? error.message
        : 'Something went wrong. Try again.';
    switch (state) {
      // A background failure (e.g. a token refresh) must not knock a
      // signed-in user out or paint an error over the app.
      case Authenticated():
      case AuthLoading():
        return;
      case AwaitingEmailConfirmation(:final email):
        state = AwaitingEmailConfirmation(email, errorMessage: message);
      case Unauthenticated():
        state = Unauthenticated(errorMessage: message);
    }
  }

  /// Drops stale status — a previous screen's error, or a finished
  /// sign-up's "check your email" state — when an auth screen opens.
  /// Auth state is app-wide, so without this an error from Sign in shows
  /// up on Sign up, and re-opening Sign up after a typo'd address lands
  /// on "Check your email" again instead of a fresh form.
  void clearStatus() {
    if (state is Unauthenticated || state is AwaitingEmailConfirmation) {
      state = const Unauthenticated();
    }
  }

  /// Returns a plain-language error message, or null on success. Kept out
  /// of [state] on purpose: a resend is a side action on the Check-your-
  /// email screen, not a change in who is signed in.
  Future<String?> resendConfirmation(String email) async {
    try {
      await ref.read(authRepositoryProvider).resendConfirmation(email: email);
      return null;
    } on AuthFailureException catch (e) {
      return e.message;
    }
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
