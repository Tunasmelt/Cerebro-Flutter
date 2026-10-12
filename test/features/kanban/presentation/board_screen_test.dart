import 'package:cerebro_mobile/features/todo/data/todo_api.dart';
import '../../todo/fake_todo_api.dart';
import 'package:cerebro_mobile/features/documents/data/documents_list_notifier.dart';
import 'dart:async';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/kanban/data/kanban_api.dart';
import 'package:cerebro_mobile/features/kanban/presentation/board_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:cerebro_mobile/shared/widgets/app_screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../documents/fake_documents_repository.dart';
import '../fake_kanban_api.dart';

final owner = StateProvider<String?>((_) => 'owner');
void main() {
  late FakeKanbanApi api;
  Future<void> mount(WidgetTester tester) async {
    api = FakeKanbanApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => ref.watch(owner)),
          kanbanApiProvider.overrideWithValue(api),
          todoApiProvider.overrideWithValue(FakeTodoApi()),
          documentsRepositoryProvider.overrideWithValue(
            FakeDocumentsRepository(
              documents: [
                DocumentSummary(
                  id: 'doc',
                  title: 'Research.txt',
                  mime: 'text/plain',
                  sizeBytes: 10,
                  originalSizeBytes: null,
                  status: DocumentStatus.ready,
                  createdAt: DateTime(2026),
                ),
              ],
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const BoardScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('server board renders and existing Todo segment still switches', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('My Board'), findsOneWidget);
    expect(find.text('3 cards'), findsOneWidget);
    await tester.tap(find.text('Todo'));
    await tester.pumpAndSettle();
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    // The open count sits in the header, as the card count does on Board.
    expect(find.text('1 open'), findsOneWidget);
  });
  testWidgets('uses the shared header, and fits a 320px phone on both tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester);

    expect(find.byType(AppScreenHeader), findsOneWidget);
    expect(find.text('My Board'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Todo'));
    await tester.pumpAndSettle();
    expect(find.text('Tasks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'blank title is rejected; create saves optional document and closes',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byTooltip('Create card'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('kanban_save')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a title.'), findsOneWidget);
      expect(api.creates, isEmpty);
      await tester.enterText(
        find.byKey(const Key('kanban_title')),
        ' New card ',
      );
      await tester.tap(find.byKey(const Key('kanban_document')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Research.txt').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('kanban_save')));
      await tester.pumpAndSettle();
      expect(api.creates.single, ('Backlog', 'New card', '', 'doc'));
      expect(find.text('Create card'), findsNothing);
      expect(find.text('Research.txt'), findsOneWidget);
    },
  );
  testWidgets('failed save preserves title and enables retry', (tester) async {
    await mount(tester);
    api.writeError = StateError('private details');
    await tester.tap(find.byTooltip('Create card'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('kanban_title')), 'Keep draft');
    await tester.tap(find.byKey(const Key('kanban_save')));
    await tester.pumpAndSettle();
    expect(find.text('Keep draft'), findsOneWidget);
    expect(find.textContaining('private details'), findsNothing);
    api.writeError = null;
    await tester.tap(find.byKey(const Key('kanban_save')));
    await tester.pumpAndSettle();
    expect(find.text('Create card'), findsNothing);
    expect(api.creates, hasLength(2));
  });
  testWidgets('save cannot be submitted twice while pending', (tester) async {
    await mount(tester);
    api.writeGate = Completer<void>();
    await tester.tap(find.byTooltip('Create card'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('kanban_title')), 'One card');
    await tester.tap(find.byKey(const Key('kanban_save')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('kanban_save')));
    await tester.pump();
    expect(api.creates, hasLength(1));
    api.writeGate!.complete();
    await tester.pumpAndSettle();
  });
  testWidgets('delete requires confirmation and refreshes board', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byKey(const ValueKey('kanban_actions_a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.deleted, isEmpty);
    await tester.tap(find.byKey(const ValueKey('kanban_actions_a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(api.deleted, ['a']);
    expect(find.text('Alpha'), findsNothing);
  });
  testWidgets(
    'changing accounts closes old draft without dropdown assertions',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byTooltip('Create card'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('kanban_title')),
        'Old owner draft',
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BoardScreen)),
      );
      api.loadGate = Completer();
      container.read(owner.notifier).state = 'other';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.text('Create card'), findsNothing);
      expect(api.creates, isEmpty);
      api.loadGate!.complete(testBoard);
      await tester.pumpAndSettle();
    },
  );
  testWidgets('removed selected document requires a new selection', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byTooltip('Create card'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('kanban_title')),
      'Linked card',
    );
    await tester.tap(find.byKey(const Key('kanban_document')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Research.txt').last);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BoardScreen)),
    );
    container.read(documentsListProvider.notifier).removeDocument('doc');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('kanban_save')));
    await tester.pumpAndSettle();
    expect(api.creates, isEmpty);
    expect(find.text('Choose an available document.'), findsOneWidget);
  });
}
