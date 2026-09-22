import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:cerebro_mobile/shared/widgets/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    );
  }

  testWidgets('renders the exception message and a keyed root per kind', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const ErrorView(exception: NetworkUnreachableException())),
    );

    expect(
      find.text("Can't reach Cerebro. Check your connection."),
      findsOneWidget,
    );
    expect(find.byKey(const Key('error_view_offline')), findsOneWidget);
  });

  testWidgets('shows a Retry button only when onRetry is given', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const ErrorView(exception: ServerErrorException(500))),
    );
    expect(find.byKey(const Key('error_view_retry')), findsNothing);

    var retried = false;
    await tester.pumpWidget(
      wrap(
        ErrorView(
          exception: const ServerErrorException(500),
          onRetry: () => retried = true,
        ),
      ),
    );
    expect(find.byKey(const Key('error_view_retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('error_view_retry')));
    expect(retried, isTrue);
  });

  testWidgets('expanded renders a full-section layout, still keyed the same', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ErrorView(
          exception: UnknownApiException('something odd'),
          expanded: true,
        ),
      ),
    );

    expect(find.byKey(const Key('error_view_unknown')), findsOneWidget);
    expect(find.text('something odd'), findsOneWidget);
  });
}
