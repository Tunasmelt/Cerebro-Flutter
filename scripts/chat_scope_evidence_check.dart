// Real-backend diagnostic. Override only the API base URL; keep production
// widgets/controllers and SDK auth. Deletes only its own synthetic sessions.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cerebro_mobile/main.dart' show CerebroApp;
import 'package:cerebro_mobile/app/router.dart';
import 'package:cerebro_mobile/core/config/supabase_config.dart';
import 'package:cerebro_mobile/core/network/api_client.dart';
import 'package:cerebro_mobile/core/network/api_client_provider.dart';
import 'package:cerebro_mobile/core/network/generated_api_client.dart';
import 'package:cerebro_mobile/core/network/generated_api_client_provider.dart';
import 'package:cerebro_mobile/features/auth/data/supabase_session_token_provider.dart';
import 'package:cerebro_mobile/features/chat/data/chat_controller.dart';
import 'package:cerebro_mobile/features/chat/data/chat_message.dart';
import 'package:cerebro_mobile/features/chat/data/citation_evidence.dart';
import 'package:cerebro_mobile/features/chat/data/answer_segments.dart';
import 'package:cerebro_mobile/features/chat/data/resolved_answer.dart';
import 'package:cerebro_mobile/features/chat/presentation/citation_chip.dart';
import 'package:cerebro_mobile/features/graph/data/graph_models.dart';
import 'package:cerebro_mobile/features/chat/presentation/citation_evidence_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  final auth = Supabase.instance.client.auth;
  if (auth.currentSession?.isExpired == true) await auth.refreshSession();
  final owner = auth.currentUser?.id;
  if (owner == null) {
    debugPrint('CHAT_FIX_SIGN_IN_REQUIRED');
    return;
  }
  const apiBase = String.fromEnvironment(
    'CHAT_TEST_API_BASE',
    defaultValue: kDefaultApiBaseUrl,
  );
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWith(
        (ref) => ApiClient(
          baseUrl: apiBase,
          tokenProvider: const SupabaseSessionTokenProvider(),
        ),
      ),
      generatedApiClientProvider.overrideWith(
        (ref) => buildGeneratedApiClient(
          baseUrl: apiBase,
          tokenProvider: const SupabaseSessionTokenProvider(),
        ),
      ),
    ],
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const CerebroApp()),
  );
  await Future<void>.delayed(const Duration(seconds: 2));
  final controller = container.read(chatControllerProvider.notifier);
  final fixtures = <String>{};
  final keepers = <ProviderSubscription<dynamic>>[];
  Future<void> remember() async {
    final id = container.read(chatControllerProvider).sessionId;
    if (id != null) fixtures.add(id);
  }

  try {
    container.read(routerProvider).go(AppRoutes.chat);
    await controller.send('explain this').timeout(const Duration(minutes: 2));
    await remember();
    final vague = container.read(chatControllerProvider).messages.last;
    if (vague.status != ChatMessageStatus.complete ||
        vague.retrievedChunkIds.isNotEmpty ||
        !vague.text.contains('Which document')) {
      throw StateError('clarification');
    }
    debugPrint('CHAT_FIX_CLARIFICATION_PASS');
    final api = container.read(apiClientProvider).dio;
    final graphResponse = await api.get('/api/v1/graph/nodes');
    final nodes = [
      for (final row in (graphResponse.data as Map)['nodes'] as List)
        ?GraphNodeData.fromJson(row),
    ];
    final node = nodes.firstWhere(
      (node) => node.title.toLowerCase().contains('architecture-and-security'),
    );
    await controller
        .chatAboutDocument(node.id, node.title)
        .timeout(const Duration(minutes: 3));
    await remember();
    final answer = container.read(chatControllerProvider).messages.last;
    if (answer.status != ChatMessageStatus.complete ||
        answer.retrievedDocumentIds.isEmpty ||
        answer.retrievedDocumentIds.any((id) => id != node.id)) {
      throw StateError('scope');
    }
    debugPrint(
      'CHAT_FIX_SCOPE_STATUS_${answer.status.name}_RETRIEVED_${answer.retrievedChunkIds.length}_CITED_${answer.citedDocuments.length}',
    );
    final parts = resolveAnswer(
      parseAnswerSegments(answer.text),
      retrievedChunkIds: answer.retrievedChunkIds,
      citedDocuments: answer.citedDocuments,
    );
    final citation = parts.whereType<ChipPart>().first;
    debugPrint('CHAT_FIX_SELECTED_SOURCE_PASS');
    await Future<void>.delayed(const Duration(seconds: 1));
    CitationChip? chip;
    void visit(Element element) {
      final widget = element.widget;
      if (widget is CitationChip && widget.enabled) chip ??= widget;
      element.visitChildElements(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildElements(visit);
    if (chip == null) throw StateError('citation control');
    chip!.onTap();
    await Future<void>.delayed(const Duration(seconds: 1));
    var evidencePageVisible = false;
    void checkPage(Element element) {
      if (element.widget is CitationEvidenceScreen) evidencePageVisible = true;
      element.visitChildElements(checkPage);
    }

    WidgetsBinding.instance.rootElement?.visitChildElements(checkPage);
    if (!evidencePageVisible) {
      throw StateError('wrong destination');
    }
    final evidence = await container.read(
      citationEvidenceProvider(citation.chunkId).future,
    );
    if (evidence['chunk_id'] != citation.chunkId ||
        (evidence['document'] as Map)['id'] != node.id) {
      throw StateError('wrong evidence');
    }
    debugPrint('CHAT_FIX_CITATION_EXCERPT_PASS');
    final imageNode = nodes
        .where((node) => node.type == GraphNodeType.image)
        .first;
    final chunkResponse = await api.get(
      '/api/v1/graph/nodes/${imageNode.id}/chunks',
    );
    final chunkId =
        (((chunkResponse.data as Map)['chunks'] as List).first as Map)['id']
            as String;
    keepers.add(container.listen(citationEvidenceProvider(chunkId), (_, _) {}));
    final imageEvidence = await container.read(
      citationEvidenceProvider(chunkId).future,
    );
    final url = imageEvidence['render_url'] as String?;
    if (url == null) {
      throw StateError('image evidence URL');
    }
    keepers.add(container.listen(evidenceImageProvider(url), (_, _) {}));
    if ((await container.read(evidenceImageProvider(url).future)).isEmpty) {
      throw StateError('image evidence');
    }
    container.read(routerProvider).go(AppRoutes.citationEvidence(chunkId));
    debugPrint('CHAT_FIX_IMAGE_EVIDENCE_PASS');
    await Future<void>.delayed(const Duration(seconds: 15));
  } catch (error) {
    debugPrint(
      'CHAT_FIX_FAILURE_${error is StateError ? error.message : error.runtimeType}',
    );
    await remember();
    debugPrint('CHAT_FIX_CHECK_INCOMPLETE');
  } finally {
    controller.stop();
    if (auth.currentUser?.id == owner) {
      final history = container.read(chatHistoryApiProvider);
      try {
        for (final id in fixtures) {
          await history.delete(id);
        }
        final remaining = await history.list();
        if (remaining.any((session) => fixtures.contains(session.id))) {
          throw StateError('cleanup');
        }
        debugPrint('CHAT_FIX_FIXTURE_CLEANUP_PASS');
      } catch (_) {
        debugPrint('CHAT_FIX_FIXTURE_CLEANUP_INCOMPLETE');
      }
    }
    controller.newChat();
    for (final keeper in keepers) {
      keeper.close();
    }
  }
}
