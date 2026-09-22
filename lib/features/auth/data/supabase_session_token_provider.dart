import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/network/session_token_provider.dart';

/// The real [SessionTokenProvider] implementation, deferred until
/// Milestone 1.1 per `core/network/session_token_provider.dart`'s
/// original design note — `AuthInterceptor` was built decoupled from
/// `supabase_flutter` specifically so this could be wired in later
/// without touching Milestone 0.3's code.
class SupabaseSessionTokenProvider implements SessionTokenProvider {
  const SupabaseSessionTokenProvider();

  @override
  String? get currentAccessToken =>
      supabase.Supabase.instance.client.auth.currentSession?.accessToken;
}
