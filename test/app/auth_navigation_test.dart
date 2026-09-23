// Router-level regression tests for the Phase 1 audit's findings 2-5
// (see CHANGELOG "Phase 1 audit"). Each drives the real go_router through
// CerebroApp, because the original defects only showed up there: the
// screens were tested in isolation and the router tests never opened
// Sign up.
//
// Every wait is a full pumpAndSettle. The audit's first draft reported a
// "stale Sign-up screen" that was really just a route transition still
// running when a 400ms probe looked; the group below that covers it is a
// guard against that ever becoming true, not a regression of a defect.
import 'package:cerebro_mobile/app/router.dart';
import 'package:cerebro_mobile/core/network/connection_status_notifier.dart';
import 'package:cerebro_mobile/features/auth/data/auth_exception.dart';
import 'package:cerebro_mobile/features/auth/data/auth_notifier.dart';
import 'package:cerebro_mobile/features/auth/data/auth_repository.dart';
import 'package:cerebro_mobile/features/auth/presentation/sign_up_screen.dart';
import 'package:cerebro_mobile/main.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/network/fake_connection_status_notifier.dart';
import '../features/auth/fake_auth_repository.dart';

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle();

void main() {
  late FakeAuthRepository repo;

  Widget app() => ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      connectionStatusProvider.overrideWith(
        () => FakeConnectionStatusNotifier(() async {}),
      ),
    ],
    child: const CerebroApp(),
  );

  Future<void> openSignUp(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('sign_in_go_to_sign_up')));
    await tester.tap(find.byKey(const Key('sign_in_go_to_sign_up')));
    await settle(tester);
    expect(find.byKey(const Key('sign_up_email')), findsOneWidget);
  }

  Future<void> submitSignUp(WidgetTester tester, String email) async {
    repo.nextResult = SignUpOutcome.needsEmailConfirmation;
    await tester.enterText(find.byKey(const Key('sign_up_email')), email);
    await tester.enterText(find.byKey(const Key('sign_up_password')), 'secret1');
    await tester.enterText(
      find.byKey(const Key('sign_up_confirm_password')),
      'secret1',
    );
    await tester.tap(find.byKey(const Key('sign_up_submit')));
    await settle(tester);
    expect(find.byKey(const Key('check_email_state')), findsOneWidget);
  }

  setUp(() => repo = FakeAuthRepository());
  tearDown(() => repo.dispose());

  group('guard: Sign up must not linger over the app after auth', () {
    testWidgets(
      'a session arriving outside the form (the confirmation link) replaces '
      'Sign up with the shell',
      (tester) async {
        await tester.pumpWidget(app());
        await settle(tester);
        await openSignUp(tester);

        repo.nextResult = 'user-9';
        await repo.signIn(email: 'a@b.co', password: 'x');
        await settle(tester);

        expect(find.byKey(const Key('documents_placeholder')), findsOneWidget);
        expect(find.byKey(const Key('sign_up_email')), findsNothing);
        expect(find.byType(SignUpScreen), findsNothing);
      },
    );

    testWidgets(
      'the same holds from the Check-your-email screen, which is where a '
      'real user is when they tap the link',
      (tester) async {
        await tester.pumpWidget(app());
        await settle(tester);
        await openSignUp(tester);
        await submitSignUp(tester, 'new@b.co');

        repo.nextResult = 'user-9';
        await repo.signIn(email: 'new@b.co', password: 'secret1');
        await settle(tester);

        expect(find.byKey(const Key('documents_placeholder')), findsOneWidget);
        expect(find.byKey(const Key('check_email_state')), findsNothing);
      },
    );

    testWidgets('Sign up is reachable and dismissible with back', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await settle(tester);
      await openSignUp(tester);

      await tester.pageBack();
      await settle(tester);

      expect(find.byKey(const Key('sign_up_email')), findsNothing);
      expect(find.byKey(const Key('sign_in_submit')), findsOneWidget);
    });
  });

  group('finding 2: Check your email is not a dead end', () {
    testWidgets(
      'leaving and re-opening Sign up shows a fresh form, not the old '
      'confirmation screen',
      (tester) async {
        await tester.pumpWidget(app());
        await settle(tester);
        await openSignUp(tester);
        await submitSignUp(tester, 'typo@b.co');

        await tester.pageBack();
        await settle(tester);
        await openSignUp(tester);

        expect(find.byKey(const Key('check_email_state')), findsNothing);
      },
    );

    testWidgets(
      '"Use a different email" returns to the form with the typed values kept',
      (tester) async {
        await tester.pumpWidget(app());
        await settle(tester);
        await openSignUp(tester);
        await submitSignUp(tester, 'typo@b.co');

        await tester.tap(find.byKey(const Key('check_email_change')));
        await settle(tester);

        expect(find.byKey(const Key('check_email_state')), findsNothing);
        expect(find.byKey(const Key('sign_up_email')), findsOneWidget);
        expect(find.text('typo@b.co'), findsOneWidget);
      },
    );

    testWidgets('"Back to sign in" goes to Sign in', (tester) async {
      await tester.pumpWidget(app());
      await settle(tester);
      await openSignUp(tester);
      await submitSignUp(tester, 'p@b.co');

      await tester.tap(find.byKey(const Key('check_email_back_to_sign_in')));
      await settle(tester);

      expect(find.byKey(const Key('sign_in_submit')), findsOneWidget);
      expect(find.byKey(const Key('sign_up_email')), findsNothing);
    });

    testWidgets('Resend sends to the address and confirms', (tester) async {
      await tester.pumpWidget(app());
      await settle(tester);
      await openSignUp(tester);
      await submitSignUp(tester, 'p@b.co');

      await tester.tap(find.byKey(const Key('check_email_resend')));
      await settle(tester);

      expect(repo.resendCalls, ['p@b.co']);
      expect(find.byKey(const Key('check_email_resent')), findsOneWidget);
      expect(find.byKey(const Key('check_email_error')), findsNothing);
    });

    testWidgets('a failed Resend shows the plain-language reason', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await settle(tester);
      await openSignUp(tester);
      await submitSignUp(tester, 'p@b.co');

      repo.nextResendResult = const AuthFailureException(
        'Too many attempts. Wait a few minutes and try again.',
      );
      await tester.tap(find.byKey(const Key('check_email_resend')));
      await settle(tester);

      expect(find.byKey(const Key('check_email_error')), findsOneWidget);
      expect(
        find.text('Too many attempts. Wait a few minutes and try again.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('check_email_resent')), findsNothing);
    });
  });

  group('finding 3: errors do not leak between auth screens', () {
    testWidgets('a failed sign-in error is not shown on Sign up', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await settle(tester);
      repo.nextResult = const AuthFailureException(
        'Incorrect email or password.',
      );
      await tester.enterText(find.byKey(const Key('sign_in_email')), 'a@b.co');
      await tester.enterText(find.byKey(const Key('sign_in_password')), 'x');
      await tester.tap(find.byKey(const Key('sign_in_submit')));
      await settle(tester);
      expect(find.text('Incorrect email or password.'), findsOneWidget);

      await openSignUp(tester);

      expect(
        find.descendant(
          of: find.byType(SignUpScreen),
          matching: find.text('Incorrect email or password.'),
        ),
        findsNothing,
      );
    });
  });

  group('finding 4: unknown routes never show the framework error page', () {
    Future<void> pumpWithRouter(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.dark,
            routerConfig: container.read(routerProvider),
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets(
      'a signed-in user opening /confirm-email lands in the app, with no '
      '"Page Not Found"',
      (tester) async {
        final signedIn = FakeAuthRepository(initialUserId: 'user-1');
        addTearDown(signedIn.dispose);
        final container = ProviderContainer(
          overrides: [authRepositoryProvider.overrideWithValue(signedIn)],
        );
        addTearDown(container.dispose);
        await pumpWithRouter(tester, container);

        container.read(routerProvider).go('/confirm-email');
        await settle(tester);

        expect(find.text('Page Not Found'), findsNothing);
        expect(find.byKey(const Key('documents_placeholder')), findsOneWidget);
      },
    );

    testWidgets('a signed-out user opening an unknown route lands on Sign in', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await pumpWithRouter(tester, container);

      container.read(routerProvider).go('/confirm-email');
      await settle(tester);

      expect(find.text('Page Not Found'), findsNothing);
      expect(find.byKey(const Key('sign_in_submit')), findsOneWidget);
    });
  });

  group('finding 5: a failed confirmation link is shown, not swallowed', () {
    testWidgets(
      'on the Check-your-email screen the error appears with Resend still '
      'available',
      (tester) async {
        await tester.pumpWidget(app());
        await settle(tester);
        await openSignUp(tester);
        await submitSignUp(tester, 'p@b.co');

        repo.emitStreamError(
          const AuthFailureException(
            'That confirmation link is invalid or has expired. '
            'Request a new one.',
          ),
        );
        await settle(tester);

        expect(find.byKey(const Key('check_email_error')), findsOneWidget);
        expect(
          find.text(
            'That confirmation link is invalid or has expired. '
            'Request a new one.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('check_email_resend')), findsOneWidget);
      },
    );

    testWidgets('on Sign in the error appears inline', (tester) async {
      await tester.pumpWidget(app());
      await settle(tester);

      repo.emitStreamError(
        const AuthFailureException('That confirmation link has expired.'),
      );
      await settle(tester);

      expect(find.byKey(const Key('sign_in_error')), findsOneWidget);
      expect(find.text('That confirmation link has expired.'), findsOneWidget);
    });
  });
}
