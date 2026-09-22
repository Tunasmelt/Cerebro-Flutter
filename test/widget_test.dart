import 'package:cerebro_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('token showcase renders button, input, and badges', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CerebroApp());
    await tester.tap(find.text('Design tokens'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('button_default')), findsOneWidget);
    expect(find.byKey(const Key('button_disabled')), findsOneWidget);
    expect(find.byKey(const Key('input_default')), findsOneWidget);
    expect(find.byKey(const Key('badge_locked')), findsOneWidget);
    expect(find.byKey(const Key('badge_success')), findsOneWidget);
    expect(find.byKey(const Key('badge_secondary')), findsOneWidget);

    final disabledButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('button_disabled')),
    );
    expect(disabledButton.onPressed, isNull);
  });
}
