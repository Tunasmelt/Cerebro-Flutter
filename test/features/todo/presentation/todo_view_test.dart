import 'package:cerebro_mobile/features/todo/presentation/todo_view.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TodoView renders its sections without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: TodoView()),
      ),
    );

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('UPCOMING'), findsOneWidget);
    expect(find.text('Review retrieval benchmark'), findsOneWidget);

    // The Completed section is further down the list — scroll it into
    // view before asserting on it (ListView builds lazily).
    await tester.scrollUntilVisible(find.text('Completed'), 200);
    expect(find.text('Completed'), findsOneWidget);
  });
}
