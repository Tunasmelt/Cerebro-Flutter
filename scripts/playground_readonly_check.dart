// Verifies a real read-only prompt selected through the production UI.
// Supply public IDs and a SHA-256 of the normalized deployed GET response.
// Never supply credentials or prompt content through defines. Restore main.dart.
import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cerebro_mobile/app/router.dart';
import 'package:cerebro_mobile/core/config/supabase_config.dart';
import 'package:cerebro_mobile/features/playground/data/playground_api.dart';
import 'package:cerebro_mobile/main.dart' show CerebroApp;

const _session = String.fromEnvironment('PLAYGROUND_TEST_SESSION');
const _message = String.fromEnvironment('PLAYGROUND_TEST_MESSAGE');
const _expected = String.fromEnvironment('PLAYGROUND_EXPECTED_SHA256');
String _snapshot(PromptBreakdown prompt) => jsonEncode({
  'model': prompt.model,
  'sections': [
    for (final section in prompt.sections)
      {
        'label': section.label,
        'content': section.content,
        'tokens': section.tokens,
        'citation': section.citation,
      },
  ],
  'response': {'content': prompt.response, 'tokens': prompt.responseTokens},
  'total_tokens': prompt.totalTokens,
  'cost': prompt.cost.toStringAsFixed(6),
});
Future<String> _digest(PromptBreakdown prompt) async => (await Sha256().hash(
  utf8.encode(_snapshot(prompt)),
)).bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

class _Observer extends ProviderObserver {
  bool verifying = false;
  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (verifying ||
        provider !=
            playgroundPromptProvider((
              sessionId: _session,
              messageId: _message,
            )) ||
        newValue is! AsyncData<PromptBreakdown>) {
      return;
    }
    verifying = true;
    unawaited(_verify(newValue.value, container));
  }

  Future<void> _verify(
    PromptBreakdown displayed,
    ProviderContainer container,
  ) async {
    try {
      final fresh = await container
          .read(playgroundApiProvider)
          .prompt(_session, _message);
      if (await _digest(displayed) != _expected ||
          await _digest(fresh) != _expected) {
        throw StateError('Breakdown mismatch');
      }
      debugPrint('MILESTONE_6_3_UI_AND_FRESH_BACKEND_BREAKDOWN_PASS');
    } catch (_) {
      debugPrint('MILESTONE_6_3_VERIFICATION_INCOMPLETE');
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_session.isEmpty ||
      _message.isEmpty ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(_expected)) {
    throw StateError('Use public IDs and a normalized response digest');
  }
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  if (Supabase.instance.client.auth.currentUser == null) {
    throw StateError('Sign in normally first');
  }
  final container = ProviderContainer(observers: [_Observer()]);
  runApp(
    UncontrolledProviderScope(container: container, child: const CerebroApp()),
  );
  container.read(routerProvider).go(AppRoutes.playground);
}
