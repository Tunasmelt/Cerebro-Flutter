import 'package:cerebro_mobile/features/graph/presentation/graph_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GraphScreen renders its chrome without crashing',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const GraphScreen(),
      ),
    );
    await tester.pump();

    expect(find.byType(GraphScreen), findsOneWidget);
    expect(find.text('Search nodes…'), findsOneWidget);
    expect(find.text('Ask about your documents…'), findsOneWidget);
    expect(find.text('node color = type'), findsOneWidget);
  });

  testWidgets('tapping a node opens the detail sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const GraphScreen(),
      ),
    );
    await tester.pump();

    // Node 0 ("Full Stack AI Developer.pdf") sits at fractional (0.50,
    // 0.42) of the canvas — tap near there.
    // Note: pumpAndSettle can't be used here — the graph canvas drives a
    // repeating pulse AnimationController (see GraphScreen's
    // `_pulseController`) that never settles, by design. Pump a bounded
    // duration instead to let the bottom sheet's own entrance animation
    // finish.
    final size = tester.getSize(find.byType(GraphScreen));
    await tester.tapAt(Offset(size.width * 0.50, size.height * 0.42));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Full Stack AI Developer.pdf'), findsOneWidget);
    expect(find.text('Chat about this'), findsOneWidget);
  });
}
