import 'package:cerebro_mobile/features/kanban/presentation/kanban_view.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../fake_kanban_api.dart';

void main() {
  final moves = <(String, String, int)>[];
  Future<void> mount(WidgetTester tester, {bool saving = false}) async {
    tester.view.physicalSize = const Size(1100, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    moves.clear();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: KanbanView(
            board: testBoard,
            saving: saving,
            onMove: (id, column, index) => moves.add((id, column, index)),
            onCreate: (_) {},
            onDelete: (_) {},
            onOpenDocument: (_) {},
          ),
        ),
      ),
    );
  }

  Future<void> drag(WidgetTester tester, String id, Finder target) async {
    final gesture = await tester.startGesture(
      tester.getTopLeft(find.byKey(ValueKey('kanban_card_$id'))) +
          const Offset(20, 25),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('renders actual server columns and card titles', (tester) async {
    await mount(tester);
    expect(find.text('BACKLOG'), findsOneWidget);
    expect(find.text('DONE'), findsOneWidget);
    expect(find.text('REVIEW'), findsNothing);
    expect(find.text('Alpha'), findsOneWidget);
  });
  testWidgets('long press reorders in same column using index after removal', (
    tester,
  ) async {
    await mount(tester);
    await drag(tester, 'b', find.byKey(const ValueKey('kanban_card_a')));
    expect(moves.single, ('b', 'Backlog', 0));
  });
  testWidgets('long press moves to another column', (tester) async {
    await mount(tester);
    await drag(tester, 'a', find.byKey(const ValueKey('kanban_drop_Done')));
    expect(moves.single, ('a', 'Done', 1));
  });
  testWidgets('move menu offers accessible reorder and column moves', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byKey(const ValueKey('kanban_actions_b')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move up'));
    await tester.pumpAndSettle();
    expect(moves.single, ('b', 'Backlog', 0));
  });
  testWidgets('saving disables dragging and card actions', (tester) async {
    await mount(tester, saving: true);
    await drag(tester, 'a', find.byKey(const ValueKey('kanban_drop_Done')));
    expect(moves, isEmpty);
    await tester.tap(find.byKey(const ValueKey('kanban_actions_b')));
    await tester.pumpAndSettle();
    expect(find.text('Move up'), findsNothing);
  });
  testWidgets(
    'stationary edge drop follows the column scrolled under the finger',
    (tester) async {
      await mount(tester);
      tester.view.physicalSize = const Size(400, 700);
      await tester.pump();
      final gesture = await tester.startGesture(
        tester.getTopLeft(find.byKey(const ValueKey('kanban_card_a'))) +
            const Offset(20, 25),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(const Offset(360, 24));
      // Pump frames separately so the timer's scrolling actually lays out.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(moves.single, ('a', 'Done', 1));
    },
  );
  testWidgets('canceling a drag over a valid target never saves a move', (
    tester,
  ) async {
    await mount(tester);
    final gesture = await tester.startGesture(
      tester.getTopLeft(find.byKey(const ValueKey('kanban_card_a'))) +
          const Offset(20, 25),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('kanban_drop_Done'))),
    );
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(moves, isEmpty);
  });
}
