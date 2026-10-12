import 'dart:async';

import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/todo/data/todo_api.dart';
import 'package:cerebro_mobile/features/todo/presentation/todo_view.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:cerebro_mobile/shared/tokens/app_colors.dart';
import 'package:cerebro_mobile/shared/widgets/app_skeleton.dart';
import 'package:cerebro_mobile/shared/widgets/status_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../documents/fake_documents_repository.dart';
import '../fake_todo_api.dart';

void main() {
  late FakeTodoApi api;

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    bool settle = true,
    Completer<List<TodoTask>>? gate,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    api = FakeTodoApi()..listGate = gate;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('owner'),
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
    if (settle) await tester.pumpAndSettle();
  }

  group('priorityStyle', () {
    test('high is red, medium teal, low grey, in words', () {
      expect(priorityStyle(TodoPriority.high).label, 'High');
      expect(priorityStyle(TodoPriority.high).color, AppColors.danger);
      expect(priorityStyle(TodoPriority.medium).label, 'Medium');
      expect(
        priorityStyle(TodoPriority.medium).color,
        AppColors.accentSecondary,
      );
      expect(priorityStyle(TodoPriority.low).label, 'Low');
      expect(priorityStyle(TodoPriority.low).color, AppColors.textSecondary);
    });

    test('amber (sealed-only) is never used for a priority', () {
      for (final p in TodoPriority.values) {
        expect(priorityStyle(p).color, isNot(AppColors.accentLocked));
      }
    });
  });

  testWidgets('a task row shows its priority as a coloured pill', (
    tester,
  ) async {
    await mount(tester);
    final pill = tester.widget<StatusPill>(
      find.byKey(const ValueKey('todo_priority_a')),
    );
    expect(pill.label, 'Medium'); // the sample task has the default priority
    expect(pill.color, AppColors.accentSecondary);

    await tester.tap(find.byKey(const Key('todo_completed_toggle')));
    await tester.pumpAndSettle();
    final high = tester.widget<StatusPill>(
      find.byKey(const ValueKey('todo_priority_b')),
    );
    expect(high.label, 'High');
    expect(high.color, AppColors.danger);
  });

  testWidgets('the filter chips are labelled in words', (tester) async {
    await mount(tester);
    for (final label in ['All', 'High', 'Medium', 'Low']) {
      expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
    }
  });

  testWidgets('the priority filter chips start at the left edge', (
    tester,
  ) async {
    // Wide enough that all the chips fit on one line, so centring would show.
    await mount(tester, size: const Size(1200, 800));
    final left = tester.getTopLeft(find.widgetWithText(ChoiceChip, 'All')).dx;
    expect(left, lessThan(24)); // the 16px gutter, not centred
  });

  testWidgets('loading shows skeleton rows, not a spinner', (tester) async {
    final gate = Completer<List<TodoTask>>();
    await mount(tester, settle: false, gate: gate);
    await tester.pump();
    expect(find.byType(AppSkeletonList), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    gate.complete(sampleTasks);
    await tester.pumpAndSettle();
  });

  testWidgets('no active tasks shows an icon and the message', (tester) async {
    await mount(tester);
    api.tasks = [];
    await tester.tap(find.byTooltip('Refresh tasks'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todo_empty')), findsOneWidget);
    expect(find.text('No active tasks. Add one above.'), findsOneWidget);
  });

  testWidgets('the Tasks header and the task editor fit a 320px-wide phone', (
    tester,
  ) async {
    await mount(tester, size: const Size(320, 640));
    await tester.tap(find.byKey(const Key('todo_add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todo_title')), findsOneWidget);
    expect(tester.takeException(), isNull);
    final dialog = tester.getSize(find.byType(AlertDialog));
    expect(dialog.width, lessThanOrEqualTo(320));
  });
}
