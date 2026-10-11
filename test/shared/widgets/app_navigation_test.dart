import 'package:cerebro_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'dart:ui' show Tristate;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'five semantic destinations keep icon and label positions stable',
    (tester) async {
      final handle = tester.ensureSemantics();

      var selected = 0;
      Widget app(int index) => MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(
            currentIndex: index,
            onTap: (value) => selected = value,
          ),
        ),
      );
      await tester.pumpWidget(app(0));
      expect(find.byType(Icon), findsNWidgets(5));
      expect(find.text('Play'), findsNothing);
      final position = tester.getTopLeft(find.text('Docs'));
      final node = tester.getSemantics(find.byKey(const Key('app_nav_docs')));
      expect(node.label, 'Docs');
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(
        tester.getSize(find.byKey(const Key('app_nav_docs'))).height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(find.byKey(const Key('app_nav_graph')));
      expect(selected, 2);
      await tester.pumpWidget(app(2));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Docs')), position);
      for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
        expect(icon.size, 22);
      }
      handle.dispose();
    },
  );

  testWidgets('narrow navigation handles text scaling and reduced motion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(1.3),
            disableAnimations: true,
          ),
          child: Scaffold(
            bottomNavigationBar: AppBottomNav(currentIndex: 0, onTap: (_) {}),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer).first)
          .duration,
      Duration.zero,
    );
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('rail stays usable with short landscape height', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AppNavigationRail(currentIndex: 0, onTap: (_) {}),
              const Expanded(child: Text('Content')),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Settings'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Settings'), findsOneWidget);
  });
}
