// Real milestone 5.3 check using the production app, UI and providers.
// Create a disposable fixture containing the query and answer below, then:
// flutter run -d <device> -t scripts/sealed_expiry_check.dart \
//   --dart-define=SEALED_TEST_DOCUMENT_ID=<id>
// Open Seal/Unlock; the harness fills a public synthetic test passphrase.
// Tap the production confirmation buttons. Wait the real 15 minutes.
// Restore lib/main.dart afterward. No keys/passphrases/tokens are logged.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:chopper/chopper.dart' as chopper;
import 'package:cryptography/cryptography.dart';

import 'package:cerebro_mobile/main.dart' show CerebroApp;
import 'package:cerebro_mobile/app/router.dart';
import 'package:cerebro_mobile/core/config/supabase_config.dart';
import 'package:cerebro_mobile/core/network/api_client.dart'
    show kDefaultApiBaseUrl;
import 'package:cerebro_mobile/core/network/generated_api_client.dart';
import 'package:cerebro_mobile/features/auth/data/supabase_session_token_provider.dart';
import 'package:cerebro_mobile/core/network/generated_api_client_provider.dart';
import 'package:cerebro_mobile/core/network/generated/cerebro_api.swagger.dart';
import 'package:cerebro_mobile/features/chat/data/chat_controller.dart';
import 'package:cerebro_mobile/features/chat/data/chat_message.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/document_detail_provider.dart';
import 'package:cerebro_mobile/features/sealed/data/unlock_session.dart';

const _id = String.fromEnvironment('SEALED_TEST_DOCUMENT_ID');
const _contentHash = String.fromEnvironment('SEALED_TEST_CONTENT_SHA256');
const _query = 'What is the cobalt orchard access phrase?';
const _answer = 'zephyr-maple-7391';
const _fixturePassphrase = 'Milestone-5.3-test-only';
bool _unlockFailed = false;

// Device automation only. Fill the real field/controller exactly, avoiding
// ADB keyboard event timing corrupting this disposable fixture's password.
void _fillFixturePassphrase() {
  var filled = false;
  Timer.periodic(const Duration(seconds: 1), (_) {
    TextField? field;
    void visit(Element element) {
      final widget = element.widget;
      if (widget is TextField && widget.key == const Key('sealed_passphrase')) {
        field = widget;
      }
      element.visitChildren(visit);
    }

    final root = WidgetsBinding.instance.rootElement;
    if (root != null) visit(root);
    if (field == null) {
      filled = false;
    } else if (!filled && field!.enabled != false) {
      field!.controller!.text = _fixturePassphrase;
      field!.onChanged?.call(_fixturePassphrase);
      filled = true;
      debugPrint('MILESTONE_5_3_SYNTHETIC_INPUT_MATCH');
    }
  });
}

// Verification-only observer: keep the production auth/JSON transport and
// generic UI, but distinguish a rejected unlock from an unattended prompt.
class _StatusObserver implements chopper.Interceptor {
  @override
  Future<chopper.Response<T>> intercept<T>(chopper.Chain<T> chain) async {
    final response = await chain.proceed(chain.request);
    if (!response.isSuccessful &&
        chain.request.method == 'POST' &&
        (chain.request.url.path.endsWith('/unlock') ||
            chain.request.url.path.endsWith('/unseal'))) {
      _unlockFailed = true;
      final retry = int.tryParse(response.headers['retry-after'] ?? '');
      var code = 'unknown';
      try {
        final candidate = jsonDecode(response.bodyString)['error']?['code'];
        if (const {
          'invalid_key',
          'claim_expired',
          'rate_limited',
          'unauthorized',
          'unauthenticated',
          'claim_not_found',
          'claim_scope_mismatch',
        }.contains(candidate)) {
          code = candidate as String;
        }
      } catch (_) {}
      debugPrint(
        'MILESTONE_5_3_UNLOCK_HTTP_${response.statusCode}_ERROR_${code}_RETRY_SECONDS_${retry ?? 0}',
      );
    }
    return response;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_id.isEmpty) throw StateError('Provide a disposable document ID');
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  final auth = Supabase.instance.client.auth;
  if (auth.currentSession?.isExpired == true) await auth.refreshSession();
  final client = CerebroApi.create(
    baseUrl: Uri.parse(kDefaultApiBaseUrl),
    interceptors: [
      const GeneratedApiAuthInterceptor(SupabaseSessionTokenProvider()),
      _StatusObserver(),
    ],
  );
  final container = ProviderContainer(
    overrides: [generatedApiClientProvider.overrideWithValue(client)],
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const CerebroApp()),
  );
  _fillFixturePassphrase();
  container.read(routerProvider).go(AppRoutes.documentDetail(_id));
  var started = false;
  container.listen(documentDetailProvider(_id), (_, detail) {
    if (!started && detail.valueOrNull?.status == DocumentStatus.sealed) {
      started = true;
      unawaited(_verify(container));
    }
  });
}

Future<void> _verify(ProviderContainer container) async {
  final sessions = <String>{};
  var stage = 'LOCKED_CHAT';
  var allPassed = true;
  Future<void> chat(String stage, bool expectContent) async {
    final controller = container.read(chatControllerProvider.notifier);
    controller.newChat(); // Previous answers must not supply the private fact.
    await controller.send(_query);
    final state = container.read(chatControllerProvider);
    if (state.sessionId != null) sessions.add(state.sessionId!);
    final answer = state.messages.last;
    if (answer.status != ChatMessageStatus.complete || !answer.retrievalDone) {
      debugPrint(
        'MILESTONE_5_3_${stage}_INCOMPLETE_RETRIEVED_${answer.retrievedDocumentIds.contains(_id)}_ANSWER_${answer.text.contains(_answer)}',
      );
      throw StateError('Chat did not finish');
    }
    if (answer.retrievedDocumentIds.contains(_id) != expectContent ||
        answer.text.contains(_answer) != expectContent) {
      throw StateError('Retrieval or answer mismatch');
    }
    debugPrint('MILESTONE_5_3_${stage}_PASS');
  }

  try {
    await chat('LOCKED_CHAT', false);
    debugPrint('MILESTONE_5_3_READY_TO_UNLOCK');
    stage = 'UNLOCK';
    final deadline = DateTime.now().add(const Duration(minutes: 5));
    ActiveUnlock? unlock;
    while (unlock == null) {
      if (_unlockFailed || DateTime.now().isAfter(deadline)) {
        throw StateError('Unlock incomplete');
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      unlock = container.read(unlockSessionProvider)[_id];
    }
    final expiry = unlock.expiresAt;
    if (_contentHash.isNotEmpty) {
      final digest = await Sha256().hash(utf8.encode(unlock.content));
      final actual = digest.bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      if (actual != _contentHash) throw StateError('Fixture content mismatch');
      debugPrint('MILESTONE_5_3_CONTENT_HASH_PASS');
    }
    debugPrint(
      'MILESTONE_5_3_REAL_EXPIRY_UTC_${expiry.toUtc().toIso8601String()}',
    );
    stage = 'UNLOCKED_CHAT';
    try {
      await chat(stage, true);
    } catch (_) {
      allPassed = false;
      debugPrint('MILESTONE_5_3_VERIFICATION_INCOMPLETE_AT_$stage');
      // A failed backend chat turn must not prevent independent expiry checks.
    }
    stage = 'AUTOMATIC_RELOCK';
    final remaining =
        expiry.difference(DateTime.now()) + const Duration(seconds: 3);
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    if (container.read(unlockSessionProvider).containsKey(_id)) {
      throw StateError('Local claim did not expire');
    }
    debugPrint('MILESTONE_5_3_AUTOMATIC_RELOCK_PASS');
    stage = 'SERVER_EXPIRY';
    final expired = await container
        .read(generatedApiClientProvider)
        .apiV1DocumentsDocumentIdUnsealPost(
          documentId: _id,
          body: UnsealBody(claimId: unlock.claimId, key: unlock.key),
        );
    final error = jsonDecode(expired.bodyString) as Map<String, dynamic>;
    if (expired.statusCode != 401 ||
        error['error']?['code'] != 'claim_expired') {
      throw StateError('Expected server claim_expired/401');
    }
    debugPrint('MILESTONE_5_3_SERVER_EXPIRY_PASS');
    stage = 'EXPIRED_CHAT';
    await chat(stage, false);
    debugPrint(
      allPassed
          ? 'MILESTONE_5_3_DEVICE_FUNCTIONAL_PASS'
          : 'MILESTONE_5_3_DEVICE_FUNCTIONAL_INCOMPLETE',
    );
  } catch (_) {
    debugPrint('MILESTONE_5_3_VERIFICATION_INCOMPLETE_AT_$stage');
  } finally {
    for (final session in sessions) {
      try {
        await container.read(chatHistoryApiProvider).delete(session);
        debugPrint('MILESTONE_5_3_TEST_CHAT_DELETED');
      } catch (_) {
        debugPrint('MILESTONE_5_3_TEST_CHAT_CLEANUP_INCOMPLETE');
      }
    }
  }
}
