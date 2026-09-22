import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/supabase_session_token_provider.dart';
import 'api_client.dart';

/// The app's single [ApiClient] instance — flutter-rules.md's "one HTTP
/// client instance" rule, realized via Riverpod instead of a loose
/// global. Depends on Supabase having been initialized before this
/// provider is first read (true for the whole app, since
/// `Supabase.initialize()` runs before `runApp()` in `main.dart`).
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(tokenProvider: const SupabaseSessionTokenProvider());
});
