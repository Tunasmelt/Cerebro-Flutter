import 'dart:async';

import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/core/network/connection_status_notifier.dart';
import 'package:cerebro_mobile/features/auth/data/auth_notifier.dart';
import 'package:cerebro_mobile/features/settings/presentation/settings_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../core/network/fake_connection_status_notifier.dart';
import '../../auth/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository fakeRepository;

  Widget buildApp({required List<Override> extraOverrides}) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeRepository),
        ...extraOverrides,
      ],
      child: MaterialApp(theme: AppTheme.dark, home: const SettingsScreen()),
    );
  }

  Override connectedOverride() => connectionStatusProvider.overrideWith(
    () => FakeConnectionStatusNotifier(() async {}),
  );

  setUp(() => fakeRepository = FakeAuthRepository());
  tearDown(() => fakeRepository.dispose());

  testWidgets('SettingsScreen renders without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp(extraOverrides: [connectedOverride()]));
    await tester.pump();

    expect(find.text('Settings'), findsOneWidget);
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

  testWidgets('tapping sign out calls the auth repository', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp(extraOverrides: [connectedOverride()]));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings_sign_out')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('settings_sign_out')));
    await tester.pumpAndSettle();

    expect(fakeRepository.currentUserId, isNull);
  });

  group('Connection status section (Milestone 1.3)', () {
    testWidgets('shows a checking state while the health check is in flight', (
      tester,
    ) async {
      // The Connection section sits below the fold in Settings' ListView,
      // which doesn't build offscreen children — a tall surface keeps it
      // in the tree without scroll gymnastics.
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildApp(
          extraOverrides: [
            connectionStatusProvider.overrideWith(
              () => FakeConnectionStatusNotifier(() => Completer<void>().future),
            ),
          ],
        ),
      );
      // A bounded pump, not pumpAndSettle: the fake's future never
      // resolves, by design, to capture the loading state.
      await tester.pump();

      expect(
        find.byKey(const Key('connection_status_checking')),
        findsOneWidget,
      );
      expect(find.text('Checking connection…'), findsOneWidget);
    });

    testWidgets('shows connected once the health check succeeds', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildApp(extraOverrides: [connectedOverride()]));
      await tester.pump();

      expect(
        find.byKey(const Key('connection_status_connected')),
        findsOneWidget,
      );
      expect(find.text('Connected to Cerebro'), findsOneWidget);
    });

    testWidgets(
      'shows the offline ErrorView on NetworkUnreachableException, '
      'visually distinct from a server error',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildApp(
            extraOverrides: [
              connectionStatusProvider.overrideWith(
                () => FakeConnectionStatusNotifier(
                  () async => throw const NetworkUnreachableException(),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('error_view_offline')),
          findsOneWidget,
        );
        expect(
          find.text("Can't reach Cerebro. Check your connection."),
          findsOneWidget,
        );
        // A NetworkUnreachableException never renders as the
        // server-error treatment — that would collapse the two
        // distinct states this milestone requires stay distinct.
        expect(find.byKey(const Key('error_view_serverError')), findsNothing);
      },
    );

    testWidgets(
      'shows the server-error ErrorView on ServerErrorException, distinct '
      'from offline',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildApp(
            extraOverrides: [
              connectionStatusProvider.overrideWith(
                () => FakeConnectionStatusNotifier(
                  () async => throw const ServerErrorException(503),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('error_view_serverError')), findsOneWidget);
        expect(
          find.text('Something went wrong on our end. Try again shortly.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('error_view_offline')), findsNothing);
      },
    );

    testWidgets('tapping Retry re-runs the health check', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fake = FakeConnectionStatusNotifier(
        () async => throw const NetworkUnreachableException(),
      );

      await tester.pumpWidget(
        buildApp(
          extraOverrides: [
            connectionStatusProvider.overrideWith(() => fake),
          ],
        ),
      );
      await tester.pump();

      expect(fake.checkCount, 1);

      await tester.tap(find.byKey(const Key('error_view_retry')));
      await tester.pump();

      expect(fake.checkCount, 2);
    });
  });
}
