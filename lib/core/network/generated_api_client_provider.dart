import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/supabase_session_token_provider.dart';
import 'generated/cerebro_api.swagger.dart';
import 'generated_api_client.dart';

/// The app's single generated-client instance, mirroring
/// `apiClientProvider`'s "one instance" rule for `ApiClient`.
final generatedApiClientProvider = Provider<CerebroApi>((ref) {
  return buildGeneratedApiClient(
    tokenProvider: const SupabaseSessionTokenProvider(),
  );
});
