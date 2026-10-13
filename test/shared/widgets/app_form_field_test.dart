import 'package:cerebro_mobile/shared/tokens/app_spacing.dart';
import 'package:cerebro_mobile/shared/widgets/app_form_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );

  testWidgets('the label sits above its control', (tester) async {
    await tester.pumpWidget(
      host(
        const AppFormField(
          label: 'Title',
          child: TextField(key: Key('control')),
        ),
      ),
    );

    final label = tester.getBottomLeft(find.text('Title'));
    final control = tester.getTopLeft(find.byKey(const Key('control')));
    expect(label.dy, lessThanOrEqualTo(control.dy));
    expect(label.dx, control.dx, reason: 'left edges line up');
  });

  testWidgets('consecutive fields never touch', (tester) async {
    await tester.pumpWidget(
      host(
        Column(
          children: const [
            AppFormField(
              label: 'One',
              child: TextField(key: Key('one')),
            ),
            AppFormField(
              label: 'Two',
              child: TextField(key: Key('two')),
            ),
          ],
        ),
      ),
    );

    final gap =
        tester.getTopLeft(find.text('Two')).dy -
        tester.getBottomLeft(find.byKey(const Key('one'))).dy;
    expect(gap, greaterThanOrEqualTo(AppSpacing.s4));
  });
}
