import 'package:cerebro_mobile/features/settings/presentation/settings_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SettingsScreen renders without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const SettingsScreen(),
      ),
    );

    expect(find.text('Settings'), findsNWidgets(2)); // title + nav bar label
    expect(find.text('Alex Stone'), findsOneWidget);
    expect(find.text('Data sources'), findsOneWidget);
    expect(find.text('Encryption & sealed docs'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Cerebro 2.0.0'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Cerebro 2.0.0'), findsOneWidget);
  });
}
