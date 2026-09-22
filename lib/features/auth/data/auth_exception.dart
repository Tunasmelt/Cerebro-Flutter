/// Plain-language auth error. `AuthNotifier` never lets a raw Supabase
/// `AuthException` reach the UI layer — same rule as
/// `core/network/app_exception.dart` for networking errors.
final class AuthFailureException implements Exception {
  const AuthFailureException(this.message);

  final String message;
}
