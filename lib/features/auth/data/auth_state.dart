/// App-wide auth state. `AuthLoading` covers in-flight sign-in/sign-up;
/// `Unauthenticated.errorMessage` is a plain-language message from
/// [AuthFailureException], never a raw exception.
sealed class AuthState {
  const AuthState();
}

final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class Authenticated extends AuthState {
  const Authenticated(this.userId);

  final String userId;
}

final class Unauthenticated extends AuthState {
  const Unauthenticated({this.errorMessage});

  final String? errorMessage;
}

/// Sign-up succeeded but requires confirming the email before a session
/// exists — the expected outcome on this Supabase project (email
/// confirmation is required), not an edge case. See CHANGELOG.md's
/// Phase 1 audit entry.
final class AwaitingEmailConfirmation extends AuthState {
  const AwaitingEmailConfirmation(this.email, {this.errorMessage});

  final String email;

  /// Set when the confirmation link the user tapped failed (expired,
  /// already used, opened on another device) — shown on the Check-your-
  /// email screen so the user can resend instead of seeing nothing.
  final String? errorMessage;
}
