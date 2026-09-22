/// App-level networking errors. Never let a raw [DioException] or
/// platform exception reach the UI layer — always map to one of these
/// first, per flutter-rules.md's error-handling rule.
sealed class AppException implements Exception {
  const AppException(this.message);

  /// Plain-language, UI-safe message. Never a raw exception string.
  final String message;
}

/// No route to the server at all: offline, DNS failure, connection
/// refused, timeout before any response arrived. Distinct from
/// [ServerErrorException] — "no internet" and "server said no" are
/// different UI states, never collapsed into one generic error widget.
final class NetworkUnreachableException extends AppException {
  const NetworkUnreachableException()
    : super("Can't reach Cerebro. Check your connection.");
}

/// A response came back, but the server reported failure (5xx).
final class ServerErrorException extends AppException {
  const ServerErrorException(this.statusCode)
    : super('Something went wrong on our end. Try again shortly.');

  final int statusCode;
}

/// The server rejected the request as unauthorized (401) — an expired
/// or invalid token was actually sent and refused.
final class UnauthorizedException extends AppException {
  const UnauthorizedException() : super('Your session has expired. Sign in again.');
}

/// No local session existed at all when the request was built — caught
/// client-side by [AuthInterceptor] before anything was sent over the
/// network. Distinct from [UnauthorizedException] (server-refused vs.
/// never-attempted), per Milestone 0.3's documented fail-fast policy.
final class UnauthenticatedException extends AppException {
  const UnauthenticatedException() : super('Sign in to continue.');
}

/// Anything else: unexpected status codes, malformed responses,
/// cancellations. A safe fallback, never a crash.
final class UnknownApiException extends AppException {
  const UnknownApiException([String? detail])
    : super(detail ?? 'Something unexpected happened.');
}
