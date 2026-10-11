// Observe real UI/API completion, then force-stop and relaunch this build.
// Use a new TODO_TEST_TITLE=m62-test-<unique> for each run. Sign in normally
// first, switch to Todo, create the task, and complete its checkbox. Restore
// lib/main.dart and remove only the disposable task after verification.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cerebro_mobile/app/router.dart';
import 'package:cerebro_mobile/core/config/supabase_config.dart';
import 'package:cerebro_mobile/features/todo/data/todo_api.dart';
import 'package:cerebro_mobile/features/todo/data/todo_controller.dart';
import 'package:cerebro_mobile/main.dart' show CerebroApp;

const _title = String.fromEnvironment('TODO_TEST_TITLE');
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_title.startsWith('m62-test-')) {
    throw StateError('Use a disposable test title');
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
  final key = 'todo-verification-$_title-${auth.currentUser!.id}';
  final expected = preferences.getString(key);
  final container = ProviderContainer();
  runApp(
    UncontrolledProviderScope(container: container, child: const CerebroApp()),
  );
  container.read(routerProvider).go(AppRoutes.board);
  var done = false;
  var verification = Future<void>.value();
  Future<void> verify() async {
    if (done) return;
    try {
      // Independent authenticated GET; no fake data or production-state cache.
      final tasks = await container.read(todoApiProvider).list();
      final task = tasks.where((task) => task.title == _title).singleOrNull;
      if (task == null || !task.completed || task.completedAt == null) {
        if (expected != null) {
          throw StateError('Completed task was not restored');
        }
        return;
      }
      final snapshot = jsonEncode({
        'id': task.id,
        'title': task.title,
        'completed': task.completed,
        'completed_at': task.completedAt!.toIso8601String(),
        'priority': task.priority.name,
      });
      if (expected != null) {
        if (snapshot != expected) throw StateError('Persisted state mismatch');
        done = true;
        debugPrint('MILESTONE_6_2_RESTART_COMPLETION_PASS');
      } else {
        if (!await preferences.setString(key, snapshot)) {
          throw StateError('Checkpoint failed');
        }
        done = true;
        debugPrint('MILESTONE_6_2_READY_FOR_RESTART_PASS');
      }
    } catch (_) {
      // Fixed markers only: never print credentials, private titles or responses.
      debugPrint('MILESTONE_6_2_VERIFICATION_INCOMPLETE');
    }
  }

  container.listen(todoControllerProvider, (_, state) {
    if (!state.loading &&
        !state.saving &&
        state.error == null &&
        state.tasks != null) {
      // Queue instead of dropping an update while the previous GET is pending.
      verification = verification.then((_) => verify());
      unawaited(verification);
    }
  }, fireImmediately: true);
}
