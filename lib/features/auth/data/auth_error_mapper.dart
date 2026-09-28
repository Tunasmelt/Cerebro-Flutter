import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'auth_exception.dart';

/// Maps a Supabase auth failure to a plain-language message. `code` is
/// preferred but has been reported unreliable (null on some genuinely
/// coded errors) even on current supabase_flutter, so this falls back to
/// matching `message` text, then a generic fallback. Never lets the raw
/// exception through.
///
/// Order matters: rate limiting is checked first because its message
/// ("email rate limit exceeded") also contains "email", which the
/// generic invalid-email branch below would otherwise claim.
AuthFailureException mapAuthException(supabase.AuthException e) {
  final code = e.code;
  final message = e.message.toLowerCase();

  if (code == 'over_email_send_rate_limit' ||
      code == 'over_request_rate_limit' ||
      e.statusCode == '429' ||
      message.contains('rate limit')) {
    return const AuthFailureException(
      'Too many attempts. Wait a few minutes and try again.',
    );
  }
  if (code == 'invalid_credentials' ||
      message.contains('invalid login credentials')) {
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
    return const AuthFailureException(
      'An account with this email already exists.',
    );
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

/// Maps an error that arrives on `onAuthStateChange` (rather than being
/// thrown from a call) — chiefly a failed confirmation deep link, which
/// supabase_flutter catches and re-emits as a stream error. Transient
/// network failures from background token refresh are distinguished so
/// they aren't mislabelled as a bad link.
AuthFailureException mapAuthStreamError(Object error) {
  if (error is supabase.AuthRetryableFetchException) {
    return const AuthFailureException(
      "Can't reach Cerebro. Check your connection.",
    );
  }
  if (error is supabase.AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('code verifier') ||
        message.contains('expired') ||
        message.contains('invalid') ||
        message.contains('otp') ||
        message.contains('flow state') ||
        error.code == 'otp_expired' ||
        error.code == 'flow_state_not_found' ||
        error.code == 'flow_state_expired') {
      return const AuthFailureException(
        'That confirmation link is invalid or has expired. '
        'Request a new one.',
      );
    }
    return mapAuthException(error);
  }
  return const AuthFailureException('Something went wrong. Try again.');
}
