import 'package:cerebro_mobile/core/network/connection_status_notifier.dart';
import 'package:cerebro_mobile/features/auth/data/auth_notifier.dart';
import 'package:cerebro_mobile/features/graph/presentation/graph_screen.dart';
import 'package:cerebro_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/network/fake_connection_status_notifier.dart';
import '../features/auth/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository fakeRepository;

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeRepository),
        // Settings' "Connection" section (Milestone 1.3) calls the real
        // backend by default — faked here so nav tests unrelated to it
        // stay fast and network-free.
        connectionStatusProvider.overrideWith(
          () => FakeConnectionStatusNotifier(() async {}),
        ),
      ],
      child: const CerebroApp(),
    );
  }

  setUp(() => fakeRepository = FakeAuthRepository(initialUserId: 'user-1'));
  tearDown(() => fakeRepository.dispose());

  testWidgets('an authenticated user lands on Documents by default', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('documents_placeholder')), findsOneWidget);
    expect(find.byKey(const Key('app_nav_docs')), findsOneWidget);
  });

  testWidgets('tapping the Chat destination renders the Chat screen', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('app_nav_chat')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('chat_placeholder')), findsOneWidget);
  });

  testWidgets('tapping the Graph destination renders the Graph screen', (
    tester,
  ) async {
    // GraphScreen drives a repeating pulse animation that never settles
    // (see graph_screen_test.dart) — bounded pumps only here, no
    // pumpAndSettle for the rest of this test once it's mounted.
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('app_nav_graph')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(GraphScreen), findsOneWidget);
  });

  testWidgets('tapping the Board destination renders the Board screen', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('app_nav_board')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Research Board'), findsOneWidget);
  });

  testWidgets('tapping the Play destination renders the Playground screen', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('app_nav_play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Token Playground'), findsOneWidget);
  });

  testWidgets(
    'tapping the Settings destination renders the Settings screen',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('app_nav_settings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Alex Stone'), findsOneWidget);
    },
  );

  testWidgets('signing out from Settings redirects to Sign in', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('app_nav_settings')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The button is below the fold in Settings' ListView, so scroll it
    // into the tree first (ListView doesn't build offscreen children).
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings_sign_out')),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // Invoke the callback directly rather than a pixel-offset tap:
    // go_router's StatefulShellRoute keeps every branch's Navigator
    // mounted in an IndexedStack, which made a coordinate-based tap
    // here land on the wrong target — this still exercises the exact
    // same callback a real tap fires.
    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('settings_sign_out')),
    );
    button.onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('sign_in_submit')), findsOneWidget);
  });
}
