import 'package:cerebro_mobile/features/kanban/presentation/board_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'BoardScreen renders Board tab by default and switches to Todo',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.dark, home: const BoardScreen()),
      );

      // Defaults to the Board (kanban) tab.
      expect(find.text('Research Board'), findsOneWidget);
      expect(find.text('BACKLOG'), findsOneWidget);

      // Tapping the Todo segment switches the content view.
      await tester.tap(find.text('Todo'));
      await tester.pumpAndSettle();

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('TODAY'), findsOneWidget);
    },
  );
}
