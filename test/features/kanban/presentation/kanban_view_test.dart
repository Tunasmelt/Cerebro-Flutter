import 'package:cerebro_mobile/features/kanban/presentation/kanban_view.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('KanbanView renders its columns without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: KanbanView()),
      ),
    );

    expect(find.text('BACKLOG'), findsOneWidget);
    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('REVIEW'), findsOneWidget);
    expect(find.text('Drop cards here'), findsOneWidget);
  });
}
