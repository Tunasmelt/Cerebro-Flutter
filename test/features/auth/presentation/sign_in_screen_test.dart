import 'package:cerebro_mobile/features/auth/data/auth_exception.dart';
import 'package:cerebro_mobile/features/auth/data/auth_notifier.dart';
import 'package:cerebro_mobile/features/auth/presentation/sign_in_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_auth_repository.dart';

void main() {
  late FakeAuthRepository fakeRepository;

  Widget buildApp() {
    return ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(fakeRepository)],
      child: MaterialApp(theme: AppTheme.dark, home: const SignInScreen()),
    );
  }

  setUp(() => fakeRepository = FakeAuthRepository());
  tearDown(() => fakeRepository.dispose());

  testWidgets('renders email, password, and submit', (tester) async {
    await tester.pumpWidget(buildApp());

    expect(find.byKey(const Key('sign_in_email')), findsOneWidget);
    expect(find.byKey(const Key('sign_in_password')), findsOneWidget);
    expect(find.byKey(const Key('sign_in_submit')), findsOneWidget);
  });

  testWidgets(
    'a wrong-password failure shows the plain-language error inline, not a crash',
    (tester) async {
      fakeRepository.nextResult = const AuthFailureException(
        'Incorrect email or password.',
      );
      await tester.pumpWidget(buildApp());

      await tester.enterText(
        find.byKey(const Key('sign_in_email')),
        'person@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('sign_in_password')),
        'wrong-password',
      );
      await tester.tap(find.byKey(const Key('sign_in_submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sign_in_error')), findsOneWidget);
      expect(find.text('Incorrect email or password.'), findsOneWidget);
    },
  );

  testWidgets('a successful sign-in clears any error state', (tester) async {
    fakeRepository.nextResult = 'user-123';
    await tester.pumpWidget(buildApp());

    await tester.enterText(
      find.byKey(const Key('sign_in_email')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('sign_in_password')),
      'correct-password',
    );
    await tester.tap(find.byKey(const Key('sign_in_submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sign_in_error')), findsNothing);
  });
}
