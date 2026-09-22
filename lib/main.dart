import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'features/auth/presentation/sign_in_screen.dart';
import 'features/auth/presentation/sign_up_screen.dart';
import 'features/graph/presentation/graph_screen.dart';
import 'features/kanban/presentation/board_screen.dart';
import 'features/playground/presentation/playground_screen.dart';
import 'features/sealed/presentation/sealed_document_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'shared/theme/app_theme.dart';
import 'shared/tokens/app_colors.dart';
import 'shared/tokens/app_radius.dart';
import 'shared/tokens/app_spacing.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Awaiting this restores any persisted session before the app's first
  // frame, which is what makes "session persists across restarts" work
  // without extra code — supabase_flutter handles the persistence.
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  runApp(const CerebroApp());
}

class CerebroApp extends StatelessWidget {
  const CerebroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Cerebro',
        theme: AppTheme.dark,
        home: const DebugLauncherScreen(),
      ),
    );
  }
}

/// DEMO-ONLY: a way to view each wireframe screen before real app
/// navigation exists (Milestone 1.2). Delete once the real app shell is
/// built and these screens are reachable through it instead.
class DebugLauncherScreen extends StatelessWidget {
  const DebugLauncherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screens = <String, WidgetBuilder>{
      'Design tokens': (_) => const TokenShowcaseScreen(),
      'Sign in': (_) => const SignInScreen(),
      'Sign up': (_) => const SignUpScreen(),
      'Board (Todo + Kanban)': (_) => const BoardScreen(),
      'Token Playground': (_) => const PlaygroundScreen(),
      'Sealed document unlock': (_) => const SealedDocumentScreen(),
      'Settings': (_) => const SettingsScreen(),
      'Graph': (_) => const GraphScreen(),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Cerebro — screen index')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s4),
        children: screens.entries
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: e.value)),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(e.key),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Milestone 0.2 functional test screen: one button, one input, one
/// badge in default/pressed/disabled states, for manual side-by-side
/// comparison against the web design system's component sheet.
class TokenShowcaseScreen extends StatefulWidget {
  const TokenShowcaseScreen({super.key});

  @override
  State<TokenShowcaseScreen> createState() => _TokenShowcaseScreenState();
}

class _TokenShowcaseScreenState extends State<TokenShowcaseScreen> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cerebro — Design Tokens')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Button', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.s3),
              Row(
                children: [
                  ElevatedButton(
                    key: const Key('button_default'),
                    onPressed: () {},
                    child: const Text('Default'),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  ElevatedButton(
                    key: const Key('button_disabled'),
                    onPressed: null,
                    child: const Text('Disabled'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              Text('Input', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.s3),
              TextField(
                key: const Key('input_default'),
                controller: _controller,
                decoration: const InputDecoration(hintText: 'Ask Cerebro…'),
              ),
              const SizedBox(height: AppSpacing.s8),
              Text('Badge', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.s3),
              Wrap(
                spacing: AppSpacing.s2,
                children: [
                  _Badge(
                    key: const Key('badge_locked'),
                    label: 'Sealed',
                    color: AppColors.accentLocked,
                  ),
                  _Badge(
                    key: const Key('badge_success'),
                    label: 'Ready',
                    color: AppColors.accentSuccess,
                  ),
                  _Badge(
                    key: const Key('badge_secondary'),
                    label: 'Info',
                    color: AppColors.accentSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}
