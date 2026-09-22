import 'package:cerebro_mobile/features/auth/data/auth_notifier.dart';
import 'package:cerebro_mobile/features/auth/data/auth_repository.dart';
import 'package:cerebro_mobile/features/auth/presentation/sign_up_screen.dart';
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
      child: MaterialApp(theme: AppTheme.dark, home: const SignUpScreen()),
    );
  }

  setUp(() => fakeRepository = FakeAuthRepository());
  tearDown(() => fakeRepository.dispose());

  testWidgets('mismatched passwords show a local error, no network call', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());

    await tester.enterText(
      find.byKey(const Key('sign_up_email')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('sign_up_password')),
      'password-one',
    );
    await tester.enterText(
      find.byKey(const Key('sign_up_confirm_password')),
      'password-two',
    );
    await tester.tap(find.byKey(const Key('sign_up_submit')));
    await tester.pumpAndSettle();

    expect(find.text("Passwords don't match."), findsOneWidget);
  });

  testWidgets(
    'sign-up needing confirmation shows the "check your email" state, the '
    'expected outcome on this project — not sending an immediate session',
    (tester) async {
      fakeRepository.nextResult = SignUpOutcome.needsEmailConfirmation;
      await tester.pumpWidget(buildApp());

      await tester.enterText(
        find.byKey(const Key('sign_up_email')),
        'new-person@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('sign_up_password')),
        'a-strong-password',
      );
      await tester.enterText(
        find.byKey(const Key('sign_up_confirm_password')),
        'a-strong-password',
      );
      await tester.tap(find.byKey(const Key('sign_up_submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('check_email_state')), findsOneWidget);
      expect(find.textContaining('new-person@example.com'), findsOneWidget);
    },
  );
}
