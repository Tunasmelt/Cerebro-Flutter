/// Whether sign-up produced an immediate session or requires the user to
/// confirm their email first. This Supabase project requires email
/// confirmation (confirmed directly against the live project, see
/// CHANGELOG.md's Phase 1 audit entry) — `needsEmailConfirmation` is the
/// expected outcome for every real sign-up, not an edge case.
enum SignUpOutcome { sessionCreated, needsEmailConfirmation }

/// Abstraction over Supabase auth, kept separate from
/// `package:supabase_flutter` so `AuthNotifier` is unit-testable without
/// a real Supabase client or network access — same discipline as
/// `core/network/session_token_provider.dart`.
abstract interface class AuthRepository {
  /// The current user id, or `null` if there's no session. Supabase
  /// restores a persisted session before `Supabase.initialize()`
  /// completes, so this reflects "signed in from a previous app launch"
  /// correctly at startup.
  String? get currentUserId;

  /// Emits the user id on every session change (sign in, sign out,
  /// token refresh) — `null` when there's no session.
  Stream<String?> get userIdChanges;

  /// Throws [AuthFailureException] with a plain-language message on
  /// failure — never a raw Supabase exception.
  Future<void> signIn({required String email, required String password});

  /// Throws [AuthFailureException] with a plain-language message on
  /// failure — never a raw Supabase exception.
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  });

  Future<void> signOut();
}
