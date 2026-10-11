import 'dart:async';
import 'package:cerebro_mobile/features/auth/data/auth_exception.dart';
import 'package:cerebro_mobile/features/auth/data/auth_notifier.dart';
import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/settings/data/account_settings.dart';
import 'package:cerebro_mobile/features/settings/presentation/account_settings_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/fake_auth_repository.dart';

const account = SettingsAccount(
  id: 'owner',
  email: 'owner@example.com',
  name: 'Owner',
);

void main() {
  test('rejects pasted avatars and oversized metadata; allows clearing', () {
    expect(validateProfile('', ''), isNull);
    expect(validateProfile('Owner', 'https://example.com/avatar.png'), isNull);
    expect(validateProfile('', 'data:image/png;base64,abc'), isNotNull);
    expect(validateProfile('', 'https://'), isNotNull);
    expect(validateProfile('a' * 201, ''), isNotNull);
    expect(validateProfile('', 'https://example.com/${'a' * 2000}'), isNotNull);
  });

  Future<void> mount(
    WidgetTester tester,
    UpdateSettingsAccount update, {
    List<Override> overrides = const [],
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('owner'),
          updateSettingsAccountProvider.overrideWithValue(update),
          ...overrides,
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const AccountSettingsScreen(account: account),
        ),
      ),
    );
  }

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  Future<void> tap(WidgetTester tester, String label) async {
    final target = find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pump();
  }

  testWidgets('confirmed wipe signs out only after backend success', (
    tester,
  ) async {
    final auth = FakeAuthRepository(initialUserId: 'owner');
    addTearDown(auth.dispose);
    var calls = 0;
    await mount(
      tester,
      (_, _) async {},
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        wipeVaultProvider.overrideWithValue(() async {
          expect(auth.currentUserId, 'owner');
          calls++;
        }),
      ],
    );
    await tester.enterText(field('Type DELETE to confirm'), 'DELETE');
    await tester.pump();
    await tap(tester, 'Delete vault data');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete vault data'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(auth.currentUserId, isNull);
  });

  testWidgets('failed wipe keeps session and allows retry', (tester) async {
    final auth = FakeAuthRepository(initialUserId: 'owner');
    addTearDown(auth.dispose);
    await mount(
      tester,
      (_, _) async {},
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        wipeVaultProvider.overrideWithValue(
          () async => throw const ServerErrorException(503),
        ),
      ],
    );
    await tester.enterText(field('Type DELETE to confirm'), 'DELETE');
    await tester.pump();
    await tap(tester, 'Delete vault data');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete vault data'));
    await tester.pumpAndSettle();
    expect(auth.currentUserId, 'owner');
    expect(find.byKey(const Key('settings_result')), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Delete vault data'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('saves trimmed profile through existing auth metadata', (
    tester,
  ) async {
    UserAttributes? sent;
    await mount(tester, (owner, attributes) async {
      expect(owner, 'owner');
      sent = attributes;
    });
    await tester.enterText(field('Display name'), ' New name ');
    await tap(tester, 'Save profile');
    await tester.pumpAndSettle();
    expect(sent?.data, {'display_name': 'New name', 'avatar_url': null});
    expect(find.text('Profile updated.'), findsOneWidget);
  });

  testWidgets('invalid avatar does not call auth; failures show safe message', (
    tester,
  ) async {
    var calls = 0;
    await mount(tester, (_, _) async {
      calls++;
      throw const AuthFailureException('Please sign in again.');
    });
    await tester.enterText(field('Avatar URL'), 'data:bad');
    await tap(tester, 'Save profile');
    expect(calls, 0);
    await tester.enterText(field('Avatar URL'), '');
    await tap(tester, 'Save profile');
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Please sign in again.'), findsOneWidget);
  });

  testWidgets(
    'email edit requests confirmation without changing displayed account',
    (tester) async {
      UserAttributes? sent;
      await mount(tester, (_, attributes) async => sent = attributes);
      await tester.enterText(field('Email address'), 'new@example.com');
      await tap(tester, 'Change email');
      await tester.pumpAndSettle();
      expect(sent?.email, 'new@example.com');
      expect(find.textContaining('Check your email'), findsOneWidget);
    },
  );

  testWidgets(
    'password validation stops mismatch and clears secrets after success',
    (tester) async {
      var calls = 0;
      await mount(tester, (_, attributes) async {
        calls++;
        expect(attributes.password, 'new-password');
      });
      await tester.enterText(field('New password'), 'new-password');
      await tap(tester, 'Update password');
      expect(calls, 0);
      await tester.enterText(field('Confirm password'), 'new-password');
      await tap(tester, 'Update password');
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        (tester.widget(field('New password')) as TextField).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets('busy saves cannot dispatch twice', (tester) async {
    final done = Completer<void>();
    var calls = 0;
    await mount(tester, (_, _) {
      calls++;
      return done.future;
    });
    await tap(tester, 'Save profile');
    await tester.tap(find.text('Save profile'));
    await tester.pump();
    expect(calls, 1);
    done.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('account changes hide fields and ignore late save results', (
    tester,
  ) async {
    final owner = StateProvider<String?>((ref) => 'owner');
    final done = Completer<void>();
    await mount(
      tester,
      (_, _) => done.future,
      overrides: [
        currentUserIdProvider.overrideWith((ref) => ref.watch(owner)),
      ],
    );
    await tap(tester, 'Save profile');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AccountSettingsScreen)),
    );
    container.read(owner.notifier).state = 'other';
    await tester.pump();
    done.complete();
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Profile updated.'), findsNothing);
  });

  testWidgets(
    'vault wipe requires exact confirmation and cancel never calls backend',
    (tester) async {
      var calls = 0;
      await mount(
        tester,
        (_, _) async {},
        overrides: [
          wipeVaultProvider.overrideWithValue(() async {
            calls++;
          }),
        ],
      );
      final button = find.widgetWithText(OutlinedButton, 'Delete vault data');
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      await tester.enterText(field('Type DELETE to confirm'), 'DELETE');
      await tester.pump();
      await tap(tester, 'Delete vault data');
      await tester.pumpAndSettle();
      expect(find.text('Permanently delete vault data?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, 0);
    },
  );
}
