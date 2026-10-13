import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A screen under QA: the widget plus whatever providers it needs to render
/// real-looking content without a network.
class QaScreen {
  const QaScreen({
    required this.name,
    required this.home,
    this.overrides = const [],
    this.settle,
  });

  final String name;
  final Widget home;
  final List<Override> overrides;

  /// Extra time-advancing for screens that animate forever or load in steps;
  /// defaults to a bounded series of pumps (never `pumpAndSettle`, which would
  /// hang on a looping animation).
  final Future<void> Function(WidgetTester tester)? settle;
}

/// The phone and tablet shapes every screen must hold up in.
const qaSizes = <String, Size>{
  'small phone': Size(320, 640),
  'phone': Size(400, 800),
  'tablet': Size(840, 900),
};

/// Text scales every screen must hold up at (1.3 is the "large text" a lot of
/// people actually run).
const qaTextScales = <double>[1.0, 1.3];

/// Pumps [screen] on a surface of [size] at [textScale], and lets it load.
Future<void> pumpQaScreen(
  WidgetTester tester,
  QaScreen screen, {
  required Size size,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: screen.overrides,
      child: MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screen.home,
      ),
    ),
  );
  if (screen.settle != null) {
    await screen.settle!(tester);
  } else {
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

/// Fails if the last frame threw (an overflow, a layout assertion).
void expectNoLayoutError(WidgetTester tester, String where) {
  final error = tester.takeException();
  expect(error, isNull, reason: 'layout error at $where: $error');
}
