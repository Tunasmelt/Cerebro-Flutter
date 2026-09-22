import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/router.dart';
import 'core/config/supabase_config.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Awaiting this restores any persisted session before the app's first
  // frame, which is what makes "session persists across restarts" work
  // without extra code — supabase_flutter handles the persistence.
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  runApp(const ProviderScope(child: CerebroApp()));
}

class CerebroApp extends ConsumerWidget {
  const CerebroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Cerebro',
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
