/// Abstraction over "what's the current Supabase access token, if any."
///
/// Kept separate from `supabase_flutter` so [AuthInterceptor] is testable
/// without initializing Supabase (no widget tree, no platform channels —
/// same discipline as flutter-rules.md's state-management testability
/// rule). The real implementation, backed by
/// `Supabase.instance.client.auth.currentSession`, is wired in
/// Milestone 1.1 once auth exists; nothing here depends on that yet.
abstract interface class SessionTokenProvider {
  /// The current session's access token, or `null` if there is no
  /// active session.
  String? get currentAccessToken;
}
