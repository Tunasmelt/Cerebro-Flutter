// Live Phase C diagnostic. Uses the persisted test-device session, normal
// production controllers/widgets and deployed API. Logs only pass/fail markers.
// Deletes only the conversation it creates. Restore lib/main.dart afterward.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cerebro_mobile/main.dart' show CerebroApp;
import 'package:cerebro_mobile/app/router.dart';
import 'package:cerebro_mobile/core/config/supabase_config.dart';
import 'package:cerebro_mobile/features/chat/data/chat_controller.dart';
import 'package:cerebro_mobile/features/chat/data/chat_message.dart';
import 'package:cerebro_mobile/features/chat/data/answer_segments.dart';
import 'package:cerebro_mobile/features/chat/data/resolved_answer.dart';
import 'package:cerebro_mobile/features/chat/data/export_markdown.dart';
import 'package:flutter/services.dart';
import 'package:cerebro_mobile/features/chat/presentation/citation_chip.dart';
import 'package:cerebro_mobile/features/documents/data/document_file_provider.dart';

Widget? findRenderedWidget(bool Function(Widget) matches) {
  Widget? result;
  void visit(Element element) {
    if (matches(element.widget)) result = element.widget;
    element.visitChildElements(visit);
  }

  final root = WidgetsBinding.instance.rootElement;
  if (root != null) visit(root);
  return result;
}

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
    debugPrint('UI_C_SIGN_IN_REQUIRED');
    return;
  }
  final container = ProviderContainer();
  runApp(
    UncontrolledProviderScope(container: container, child: const CerebroApp()),
  );
  await Future<void>.delayed(const Duration(seconds: 2));
  container.read(routerProvider).go(AppRoutes.chat);
  final controller = container.read(chatControllerProvider.notifier);
  String? fixture;
  try {
    debugPrint('UI_C_LIVE_TURN_STARTED');
    await controller
        .send(
          'UX-C-live-${DateTime.now().millisecondsSinceEpoch}: Using architecture-and-security.md, summarize the retrieval pipeline. Use a bold heading, a short bullet list and a fenced text code block for a pipeline diagram. Cite the document for every claim.',
        )
        .timeout(const Duration(minutes: 3));
    final state = container.read(chatControllerProvider);
    fixture = state.sessionId;
    final answer = state.messages.last;
    final parts = resolveAnswer(
      parseAnswerSegments(answer.text),
      retrievedChunkIds: answer.retrievedChunkIds,
      citedDocuments: answer.citedDocuments,
    );
    if (answer.status != ChatMessageStatus.complete ||
        !answer.text.contains('```') ||
        !answer.text.contains('**') ||
        !RegExp(r'(^|\n)\s*[-*] ').hasMatch(answer.text) ||
        parts.whereType<ChipPart>().isEmpty) {
      throw StateError('Missing live formatting/citation evidence');
    }
    debugPrint('UI_C_LIVE_MARKDOWN_CITATIONS_PASS');
    final saved = await container
        .read(chatHistoryApiProvider)
        .messages(fixture!);
    if (saved.messages.last.text.trim() != answer.text.trim()) {
      throw StateError('Saved response differs');
    }
    debugPrint('UI_C_SAVED_RESPONSE_PASS');
    final exported = exportConversationMarkdown(
      startedAt:
          state.startedAt ?? state.messages.first.createdAt ?? DateTime.now(),
      messages: saved.messages,
    );
    if (exported.contains('[[chunk:') || !exported.contains('**Sources**')) {
      throw StateError('Export is not clean');
    }
    debugPrint('UI_C_EXPORT_PASS');
    await Future<void>.delayed(const Duration(seconds: 1));
    final copy =
        findRenderedWidget(
              (widget) =>
                  widget is IconButton &&
                  widget.key == ValueKey('chat_copy_${answer.id}'),
            )
            as IconButton?;
    if (copy == null || copy.onPressed == null) {
      throw StateError('Copy control missing');
    }
    await (copy.onPressed as dynamic)();
    final copied = await Clipboard.getData('text/plain');
    if (copied?.text == null || copied!.text!.contains('[[chunk:')) {
      throw StateError('Copy contains raw markers');
    }
    debugPrint('UI_C_PLATFORM_COPY_PASS');
    final source = parts.whereType<ChipPart>().first;
    final chip =
        findRenderedWidget(
              (widget) =>
                  widget is SourceChip &&
                  widget.key == ValueKey('source_chip_${source.documentId}'),
            )
            as SourceChip?;
    if (chip == null || !chip.enabled) {
      throw StateError('Source control missing');
    }
    chip.onTap();
    await Future<void>.delayed(const Duration(seconds: 1));
    final bytes = await container.read(
      documentFileProvider(source.documentId).future,
    );
    if (bytes.isEmpty) throw StateError('Source preview empty');
    debugPrint('UI_C_SOURCE_PREVIEW_PASS');
    // Leave enough time for a local screenshot/inspection of the real widget.
    await Future<void>.delayed(const Duration(seconds: 45));
  } catch (_) {
    debugPrint('UI_C_CHECK_INCOMPLETE');
  } finally {
    fixture ??= container.read(chatControllerProvider).sessionId;
    controller.stop();
    if (fixture != null && auth.currentUser?.id == owner) {
      try {
        final history = container.read(chatHistoryApiProvider);
        await history.delete(fixture);
        if ((await history.list()).any((session) => session.id == fixture)) {
          throw StateError('Fixture remains');
        }
        controller.newChat();
        debugPrint('UI_C_FIXTURE_CLEANUP_PASS');
      } catch (_) {
        debugPrint('UI_C_FIXTURE_CLEANUP_INCOMPLETE');
      }
    }
  }
}
