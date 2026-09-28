import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/config/supabase_config.dart';
import 'auth_error_mapper.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final supabase.GoTrueClient _auth;

  @override
  String? get currentUserId => _auth.currentSession?.user.id;

  @override
  Stream<String?> get userIdChanges => _auth.onAuthStateChange
      .map((data) => data.session?.user.id)
      .transform(
        StreamTransformer<String?, String?>.fromHandlers(
          handleError: (error, stackTrace, sink) =>
              sink.addError(mapAuthStreamError(error), stackTrace),
        ),
      );

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithPassword(email: email, password: password);
    } on supabase.AuthException catch (e) {
      throw mapAuthException(e);
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
      throw mapAuthException(e);
    }
  }

  @override
  Future<void> resendConfirmation({required String email}) async {
    try {
      await _auth.resend(
        type: supabase.OtpType.signup,
        email: email,
        emailRedirectTo: SupabaseConfig.emailRedirectTo,
      );
    } on supabase.AuthException catch (e) {
      throw mapAuthException(e);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
