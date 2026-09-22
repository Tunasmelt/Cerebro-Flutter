import 'package:cerebro_mobile/features/auth/data/auth_notifier.dart';
import 'package:cerebro_mobile/features/settings/presentation/settings_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../auth/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository fakeRepository;

  setUp(() => fakeRepository = FakeAuthRepository());
  tearDown(() => fakeRepository.dispose());

  testWidgets('SettingsScreen renders without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fakeRepository)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const SettingsScreen(),
        ),
      ),
    );

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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fakeRepository)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const SettingsScreen(),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings_sign_out')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('settings_sign_out')));
    await tester.pumpAndSettle();

    expect(fakeRepository.currentUserId, isNull);
  });
}
