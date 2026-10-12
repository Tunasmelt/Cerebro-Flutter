// Normal app with an explicit verification API URL. SDK auth and all widgets
// remain unchanged. Use ADB reverse for a local API backed by real Supabase.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cerebro_mobile/main.dart' show CerebroApp;
import 'package:cerebro_mobile/core/config/supabase_config.dart';
import 'package:cerebro_mobile/core/network/api_client.dart';
import 'package:cerebro_mobile/core/network/api_client_provider.dart';
import 'package:cerebro_mobile/core/network/generated_api_client.dart';
import 'package:cerebro_mobile/core/network/generated_api_client_provider.dart';
import 'package:cerebro_mobile/features/auth/data/supabase_session_token_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  const base = String.fromEnvironment(
    'CHAT_TEST_API_BASE',
    defaultValue: kDefaultApiBaseUrl,
  );
  runApp(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWith(
          (ref) => ApiClient(
            baseUrl: base,
            tokenProvider: const SupabaseSessionTokenProvider(),
          ),
        ),
        generatedApiClientProvider.overrideWith(
          (ref) => buildGeneratedApiClient(
            baseUrl: base,
            tokenProvider: const SupabaseSessionTokenProvider(),
          ),
        ),
      ],
      child: const CerebroApp(),
    ),
  );
}
