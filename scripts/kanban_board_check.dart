// Real-device Kanban persistence check through the production UI and API.
// Sign in normally, then run with a unique KANBAN_TEST_PREFIX and optional
// KANBAN_TEST_DOCUMENT_ID. Create three cards named <prefix>-A/B/C in the
// first column, move A to the last column, and drag C above B. Force-stop
// and relaunch this build after MILESTONE_6_1_READY_FOR_RESTART_PASS.
// Restore lib/main.dart afterward; delete only the disposable test cards.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cerebro_mobile/app/router.dart';
import 'package:cerebro_mobile/core/config/supabase_config.dart';
import 'package:cerebro_mobile/features/kanban/data/kanban_api.dart';
import 'package:cerebro_mobile/features/kanban/data/kanban_board.dart';
import 'package:cerebro_mobile/features/kanban/data/kanban_controller.dart';
import 'package:cerebro_mobile/main.dart' show CerebroApp;

const _prefix = String.fromEnvironment('KANBAN_TEST_PREFIX');
const _document = String.fromEnvironment('KANBAN_TEST_DOCUMENT_ID');
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_prefix.startsWith('m61-test-')) {
    throw StateError('Use a disposable test prefix');
  }
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  final auth = Supabase.instance.client.auth;
  if (auth.currentSession?.isExpired == true) await auth.refreshSession();
  if (auth.currentUser == null) {
    throw StateError('Sign in the test owner first');
  }
  final preferences = await SharedPreferences.getInstance();
  final key = 'kanban-verification-$_prefix-${auth.currentUser!.id}';
  final expected = preferences.getString(key);
  final container = ProviderContainer();
  runApp(
    UncontrolledProviderScope(container: container, child: const CerebroApp()),
  );
  container.read(routerProvider).go(AppRoutes.board);
  bool verifying = false, done = false;
  List<Map<String, Object?>> snapshot(KanbanBoard board) => [
    for (final column in board.columns)
      for (final card in board.inColumn(column))
        if (card.title.startsWith('$_prefix-'))
          {
            'id': card.id,
            'title': card.title,
            'column': card.column,
            'position': card.position,
            'document': card.documentId,
          },
  ];
  Future<void> verify(KanbanBoard board) async {
    if (verifying || done) return;
    verifying = true;
    try {
      // Fresh authenticated HTTP GET, separate from the controller's response.
      final persisted = await container.read(kanbanApiProvider).get(board.id);
      final cards = snapshot(persisted);
      if (expected != null) {
        if (jsonEncode(cards) != expected) {
          throw StateError('Persisted state mismatch');
        }
        done = true;
        debugPrint('MILESTONE_6_1_RESTART_SERVER_ORDER_AND_DOCUMENT_PASS');
        return;
      }
      final a = persisted.cards
          .where((c) => c.title == '$_prefix-A')
          .singleOrNull;
      final first = persisted
          .inColumn(persisted.columns.first)
          .where((c) => c.title.startsWith('$_prefix-'))
          .map((c) => c.title)
          .toList();
      if (cards.length != 3 ||
          a?.column != persisted.columns.last ||
          jsonEncode(first) != jsonEncode(['$_prefix-C', '$_prefix-B'])) {
        return;
      }
      if (_document.isNotEmpty && a?.documentId != _document) {
        throw StateError('Missing linked document');
      }
      if (!await preferences.setString(key, jsonEncode(cards))) {
        throw StateError('Checkpoint failed');
      }
      done = true;
      debugPrint('MILESTONE_6_1_READY_FOR_RESTART_PASS');
    } catch (_) {
      // Never print credentials, user titles, or raw responses.
      debugPrint('MILESTONE_6_1_VERIFICATION_INCOMPLETE');
    } finally {
      verifying = false;
    }
  }

  container.listen(kanbanControllerProvider, (_, state) {
    if (!state.loading &&
        !state.saving &&
        state.error == null &&
        state.board != null) {
      unawaited(verify(state.board!));
    }
  }, fireImmediately: true);
}
