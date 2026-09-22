import 'package:cerebro_mobile/features/playground/presentation/playground_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: child,
    );
  }

  testWidgets('PlaygroundScreen renders without crashing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(const PlaygroundScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Token Playground'), findsOneWidget);
    expect(find.text('Model'), findsOneWidget);
    expect(find.text('Prompt'), findsOneWidget);
    expect(find.text('Response'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Run prompt'), findsOneWidget);
  });

  testWidgets('Run prompt button shows a running state then completes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(const PlaygroundScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Run prompt'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('COMPLETED'), findsOneWidget);
  });
}
