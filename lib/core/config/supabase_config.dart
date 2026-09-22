/// Same Supabase project as web (`Cerebro 2.0/apps/web/.env.local`).
///
/// The anon/publishable key is meant to be public — it's the client-side
/// key, safe to embed and commit; RLS is the real security boundary, not
/// key secrecy. Never put the `service_role` key here or anywhere in
/// this app.
abstract final class SupabaseConfig {
  static const url = 'https://vuwrefjsvtinnsvgeftq.supabase.co';
  static const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ1d3JlZmpzdnRpbm5zdmdlZnRxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc5MzkyODQsImV4cCI6MjEwMzUxNTI4NH0.-XKMiJr1LOSrJjUsms7U72AL5nU9QrXwIHxu-aYeKN8';

  /// PKCE deep-link redirect target for email confirmation / magic
  /// links. Must be registered as an Additional Redirect URL in the
  /// Supabase project's Auth settings, and match the scheme/host
  /// registered in AndroidManifest.xml and Info.plist exactly.
  static const emailRedirectTo = 'cerebro://confirm-email';
}
