import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/router.dart';
import 'core/config/supabase_config.dart';
import 'features/documents/data/upload/pending_upload_store.dart';
import 'features/documents/data/document_view_cache.dart';
import 'features/documents/data/upload/upload_controller.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await clearDocumentViewCache();
  // Awaiting this restores any persisted session before the app's first
  // frame, which is what makes "session persists across restarts" work
  // without extra code — supabase_flutter handles the persistence.
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  runApp(
    ProviderScope(
      overrides: [
        pendingUploadStoreProvider.overrideWithValue(
          devicePendingUploadStore(),
        ),
      ],
      child: const CerebroApp(),
    ),
  );
}

class CerebroApp extends ConsumerWidget {
  const CerebroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(uploadsProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Cerebro',
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
