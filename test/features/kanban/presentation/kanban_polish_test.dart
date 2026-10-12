import 'package:cerebro_mobile/features/kanban/presentation/kanban_view.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:cerebro_mobile/shared/widgets/status_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_kanban_api.dart';

void main() {
  Future<void> mount(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: KanbanView(
            board: testBoard,
            onMove: (_, _, _) {},
            onCreate: (_) {},
            onDelete: (_) {},
            onOpenDocument: (_) {},
          ),
        ),
      ),
    );
  }

  double columnWidth(WidgetTester tester) =>
      tester.getSize(find.byKey(const ValueKey('kanban_column_Backlog'))).width;

  group('column width follows the screen, within limits', () {
    testWidgets('a phone shows most of a column and a hint of the next', (
      tester,
    ) async {
      await mount(tester, const Size(400, 800));
      expect(columnWidth(tester), closeTo(328, 0.5)); // 82% of 400
    });

    testWidgets('a very small phone never goes below 260', (tester) async {
      await mount(tester, const Size(300, 800));
      expect(columnWidth(tester), 260);
    });

    testWidgets('a tablet is capped at 340', (tester) async {
      await mount(tester, const Size(1200, 800));
      expect(columnWidth(tester), 340);
    });
  });

  testWidgets('each column header carries its card count as a pill', (
    tester,
  ) async {
    await mount(tester, const Size(1100, 700));
    final labels = [
      for (final p in tester.widgetList<StatusPill>(find.byType(StatusPill)))
        p.label,
    ];
    final expected = [
      for (final c in testBoard.columns) '${testBoard.inColumn(c).length}',
    ];
    expect(labels, expected);
  });

  testWidgets('picking a card up gives a selection haptic, dropping a light '
      'impact', (tester) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await mount(tester, const Size(1100, 700));

    final gesture = await tester.startGesture(
      tester.getTopLeft(find.byKey(const ValueKey('kanban_card_a'))) +
          const Offset(20, 25),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(haptics, ['HapticFeedbackType.selectionClick']);

    await gesture.moveTo(
      tester.getCenter(find.byKey(const Key('kanban_drop_Done'))),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(haptics.last, 'HapticFeedbackType.lightImpact');
  });

  testWidgets('the card being dragged is lifted and enlarged', (tester) async {
    await mount(tester, const Size(1100, 700));
    final before = tester.getSize(find.byKey(const ValueKey('kanban_card_a')));

    final gesture = await tester.startGesture(
      tester.getTopLeft(find.byKey(const ValueKey('kanban_card_a'))) +
          const Offset(20, 25),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();

    // The feedback copy is the one under the Overlay, scaled 3% larger.
    final scaled = tester
        .widgetList<Transform>(find.byType(Transform))
        .where((t) => t.transform.getMaxScaleOnAxis() > 1.02);
    expect(scaled, isNotEmpty);
    expect(before.width, greaterThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
