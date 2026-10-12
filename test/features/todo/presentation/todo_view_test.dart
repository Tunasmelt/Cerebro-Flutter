import 'dart:async';
import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/todo/data/todo_api.dart';
import 'package:cerebro_mobile/features/todo/presentation/todo_view.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../documents/fake_documents_repository.dart';
import '../fake_todo_api.dart';

final owner = StateProvider<String?>((_) => 'owner');
void main() {
  late FakeTodoApi api;
  Future<void> mount(WidgetTester tester, {Object? loadError}) async {
    api = FakeTodoApi()..listError = loadError;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => ref.watch(owner)),
          todoApiProvider.overrideWithValue(api),
          documentsRepositoryProvider.overrideWithValue(
            FakeDocumentsRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: TodoView()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'completed starts collapsed and checkbox moves tasks between groups',
    (tester) async {
      await mount(tester);
      expect(find.text('Active task'), findsOneWidget);
      expect(find.text('Finished task'), findsNothing);
      await tester.tap(find.byKey(const Key('todo_completed_toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Finished task'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('todo_check_a')));
      await tester.pumpAndSettle();
      expect(find.text('Completed (2)'), findsOneWidget);
      expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('todo_check_a')))
            .value,
        true,
      );
      await tester.tap(find.byKey(const ValueKey('todo_check_a')));
      await tester.pumpAndSettle();
      expect(find.text('Completed (1)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('todo_completed_toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Finished task'), findsNothing);
    },
  );
  testWidgets('create validates title, retains a failed draft and retries', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byKey(const Key('todo_add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo_save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a title.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('todo_title')), ' New task ');
    api.writeError = StateError('private details');
    await tester.tap(find.byKey(const Key('todo_save')));
    await tester.pumpAndSettle();
    expect(find.text(' New task '), findsOneWidget);
    expect(find.textContaining('private details'), findsNothing);
    api.writeError = null;
    await tester.tap(find.byKey(const Key('todo_save')));
    await tester.pumpAndSettle();
    expect(find.text('Create task'), findsNothing);
    expect(api.creates.last, ('New task', TodoPriority.medium));
  });
  testWidgets('pending mutation disables checkboxes and save duplication', (
    tester,
  ) async {
    await mount(tester);
    api.writeGate = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('todo_check_a')));
    await tester.pump();
    expect(
      tester
          .widget<Checkbox>(find.byKey(const ValueKey('todo_check_a')))
          .onChanged,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('todo_check_a')));
    expect(api.updates, hasLength(1));
    api.writeGate!.complete();
    await tester.pumpAndSettle();
  });
  testWidgets('priority filter applies to active and completed groups', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'High'));
    await tester.pumpAndSettle();
    expect(find.text('Active task'), findsNothing);
    expect(find.text('Completed (1)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('todo_completed_toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Finished task'), findsOneWidget);
  });
  testWidgets('load failure allows retry but disables creation', (
    tester,
  ) async {
    await mount(tester, loadError: const NetworkUnreachableException());
    expect(find.text('No active tasks. Add one above.'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('todo_add'))).onPressed,
      isNull,
    );
    api.listError = null;
    await tester.tap(find.byKey(const Key('error_view_retry')));
    await tester.pumpAndSettle();
    expect(find.text('Active task'), findsOneWidget);
  });
  testWidgets('account switch closes draft without saving', (tester) async {
    await mount(tester);
    await tester.tap(find.byKey(const Key('todo_add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('todo_title')),
      'Old owner draft',
    );
    ProviderScope.containerOf(
      tester.element(find.byType(TodoView)),
    ).read(owner.notifier).state = 'other';
    await tester.pumpAndSettle();
    expect(find.text('Create task'), findsNothing);
    expect(api.creates, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('edit changes task; delete requires confirmation', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byKey(const ValueKey('todo_actions_a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('todo_title')), 'Changed');
    await tester.tap(find.byKey(const Key('todo_save')));
    await tester.pumpAndSettle();
    expect(find.text('Changed'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('todo_actions_a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.deletes, isEmpty);
    await tester.tap(find.byKey(const ValueKey('todo_actions_a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(api.deletes, ['a']);
  });
}
