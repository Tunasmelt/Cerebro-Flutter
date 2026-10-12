import 'package:cerebro_mobile/features/auth/data/auth_notifier.dart';
import 'package:cerebro_mobile/features/auth/data/auth_exception.dart';
import 'package:cerebro_mobile/features/auth/presentation/auth_card.dart';
import 'package:cerebro_mobile/features/auth/presentation/sign_in_screen.dart';
import 'package:cerebro_mobile/features/auth/presentation/sign_up_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repo;

  Widget app(Widget home) => ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(theme: AppTheme.dark, home: home),
  );

  setUp(() => repo = FakeAuthRepository());
  tearDown(() => repo.dispose());

  TextField fieldOf(WidgetTester tester, String key) =>
      tester.widget<TextField>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(TextField),
        ),
      );

  group('Sign in', () {
    testWidgets('an empty submit names the missing fields and sends nothing', (
      tester,
    ) async {
      await tester.pumpWidget(app(const SignInScreen()));
      await tester.tap(find.byKey(const Key('sign_in_submit')));
      await tester.pump();

      expect(find.text('Enter your email.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(repo.signInCalls, 0);
    });

    testWidgets('no complaint before the first attempt', (tester) async {
      await tester.pumpWidget(app(const SignInScreen()));
      expect(find.text('Enter your email.'), findsNothing);
      expect(find.text('Enter your password.'), findsNothing);
    });

    testWidgets('a call-out clears as soon as the field is filled', (
      tester,
    ) async {
      await tester.pumpWidget(app(const SignInScreen()));
      await tester.tap(find.byKey(const Key('sign_in_submit')));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('sign_in_email')), 'a@b.co');
      await tester.pump();
      expect(find.text('Enter your email.'), findsNothing);
      expect(find.text('Enter your password.'), findsOneWidget);
    });

    testWidgets('the password can be revealed, and starts hidden', (
      tester,
    ) async {
      await tester.pumpWidget(app(const SignInScreen()));
      expect(fieldOf(tester, 'sign_in_password').obscureText, isTrue);

      await tester.tap(find.byKey(const Key('app_text_field_toggle')));
      await tester.pump();
      expect(fieldOf(tester, 'sign_in_password').obscureText, isFalse);
    });

    testWidgets('Next on the keyboard moves on; Done submits', (tester) async {
      await tester.pumpWidget(app(const SignInScreen()));
      expect(
        fieldOf(tester, 'sign_in_email').textInputAction,
        TextInputAction.next,
      );
      expect(
        fieldOf(tester, 'sign_in_password').textInputAction,
        TextInputAction.done,
      );
    });

    testWidgets('the card follows the screen width up to a cap', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      tester.view.physicalSize = const Size(320, 700);
      await tester.pumpWidget(app(const SignInScreen()));
      // 320 wide minus 24px padding either side: fills it, no overflow.
      expect(tester.getSize(find.byType(AuthCard)).width, 272);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(1200, 800);
      await tester.pumpWidget(app(const SignInScreen()));
      await tester.pump();
      expect(tester.getSize(find.byType(AuthCard)).width, AuthCard.maxWidth);
    });

    testWidgets('shows the brand mark and a heading', (tester) async {
      await tester.pumpWidget(app(const SignInScreen()));
      expect(find.byType(AuthBrand), findsOneWidget);
      expect(find.bySemanticsLabel('Cerebro'), findsOneWidget);
    });

    testWidgets('a rejected sign-in is announced to screen readers', (
      tester,
    ) async {
      repo.nextResult = const AuthFailureException(
        'Incorrect email or password.',
      );
      await tester.pumpWidget(app(const SignInScreen()));
      await tester.enterText(find.byKey(const Key('sign_in_email')), 'a@b.co');
      await tester.enterText(find.byKey(const Key('sign_in_password')), 'x');
      await tester.tap(find.byKey(const Key('sign_in_submit')));
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(
        find.byKey(const Key('sign_in_error')),
      );
      expect(semantics.flagsCollection.isLiveRegion, isTrue);
    });
  });

  group('Sign up', () {
    testWidgets('an empty submit names the missing fields and sends nothing', (
      tester,
    ) async {
      await tester.pumpWidget(app(const SignUpScreen()));
      await tester.tap(find.byKey(const Key('sign_up_submit')));
      await tester.pump();

      expect(find.text('Enter your email.'), findsOneWidget);
      expect(find.text('Choose a password.'), findsOneWidget);
      expect(repo.signUpCalls, 0);
    });

    testWidgets('both password fields can be revealed', (tester) async {
      await tester.pumpWidget(app(const SignUpScreen()));
      expect(find.byKey(const Key('app_text_field_toggle')), findsNWidgets(2));
    });

    testWidgets('mismatched passwords still show the existing message', (
      tester,
    ) async {
      await tester.pumpWidget(app(const SignUpScreen()));
      await tester.enterText(find.byKey(const Key('sign_up_email')), 'a@b.co');
      await tester.enterText(find.byKey(const Key('sign_up_password')), 'one');
      await tester.enterText(
        find.byKey(const Key('sign_up_confirm_password')),
        'two',
      );
      await tester.tap(find.byKey(const Key('sign_up_submit')));
      await tester.pump();

      expect(find.byKey(const Key('sign_up_error')), findsOneWidget);
      expect(find.text("Passwords don't match."), findsOneWidget);
      expect(repo.signUpCalls, 0);
    });

    testWidgets('keyboard actions go Next, Next, Done', (tester) async {
      await tester.pumpWidget(app(const SignUpScreen()));
      expect(
        fieldOf(tester, 'sign_up_email').textInputAction,
        TextInputAction.next,
      );
      expect(
        fieldOf(tester, 'sign_up_password').textInputAction,
        TextInputAction.next,
      );
      expect(
        fieldOf(tester, 'sign_up_confirm_password').textInputAction,
        TextInputAction.done,
      );
    });

    testWidgets('shows the same brand mark as sign in', (tester) async {
      await tester.pumpWidget(app(const SignUpScreen()));
      expect(find.byType(AuthBrand), findsOneWidget);
    });
  });
}
