import 'package:cerebro_mobile/features/sealed/presentation/sealed_document_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SealedDocumentScreen renders without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const SealedDocumentScreen(),
      ),
    );

    expect(find.text('financial-notes.pdf'), findsOneWidget);
    expect(find.text('SEALED'), findsOneWidget);
    expect(find.text('This document is sealed'), findsOneWidget);
    expect(find.text('Unlock document'), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Default state: no error copy shown yet.
    expect(
      find.text("Couldn't unlock this document. Try again."),
      findsNothing,
    );

    // DEMO-ONLY state switcher drives the error state.
    await tester.tap(find.text('Error'));
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't unlock this document. Try again."),
      findsOneWidget,
    );

    // DEMO-ONLY state switcher drives the loading state. Plain pump()
    // here, not pumpAndSettle() — the progress indicator animates
    // indefinitely while loading, so settling would never complete.
    await tester.tap(find.text('Loading'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
