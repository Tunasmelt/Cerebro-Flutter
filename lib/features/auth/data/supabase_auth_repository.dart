import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/config/supabase_config.dart';
import 'auth_exception.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final supabase.GoTrueClient _auth;

  @override
  String? get currentUserId => _auth.currentSession?.user.id;

  @override
  Stream<String?> get userIdChanges =>
      _auth.onAuthStateChange.map((data) => data.session?.user.id);

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithPassword(email: email, password: password);
    } on supabase.AuthException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: SupabaseConfig.emailRedirectTo,
      );
      return response.session != null
          ? SignUpOutcome.sessionCreated
          : SignUpOutcome.needsEmailConfirmation;
    } on supabase.AuthException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  /// Maps to a plain-language message. `code` is preferred but has been
  /// reported unreliable (null on some genuinely coded errors) even on
  /// current supabase_flutter — falls back to matching `message` text,
  /// then a generic fallback. Never lets the raw exception through.
  AuthFailureException _mapError(supabase.AuthException e) {
    final code = e.code;
    final message = e.message.toLowerCase();

    if (code == 'invalid_credentials' || message.contains('invalid login credentials')) {
      return const AuthFailureException('Incorrect email or password.');
    }
    if (code == 'email_not_confirmed' || message.contains('email not confirmed')) {
      return const AuthFailureException(
        'Check your email to confirm your account before signing in.',
      );
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        message.contains('already registered')) {
      return const AuthFailureException('An account with this email already exists.');
    }
    if (code == 'weak_password' || message.contains('password')) {
      return const AuthFailureException(
        'Password is too weak. Use at least 6 characters.',
      );
    }
    if (code == 'email_address_invalid' || message.contains('email')) {
      return const AuthFailureException('Enter a valid email address.');
    }
    return const AuthFailureException('Something went wrong. Try again.');
  }
}
