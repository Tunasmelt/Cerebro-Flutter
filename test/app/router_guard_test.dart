import 'package:cerebro_mobile/app/router.dart';
import 'package:cerebro_mobile/features/auth/data/auth_notifier.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/auth/fake_auth_repository.dart';

void main() {
  testWidgets(
    'an unauthenticated user cannot reach Documents by any navigation '
    'path, including a direct deep link to the route',
    (tester) async {
      final fakeRepository = FakeAuthRepository();
      addTearDown(fakeRepository.dispose);

      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fakeRepository)],
      );
      addTearDown(container.dispose);

      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Launching the app while unauthenticated lands on Sign in, not
      // the app shell.
      expect(find.byKey(const Key('sign_in_submit')), findsOneWidget);

      // Directly deep-linking to a protected route redirects back to
      // Sign in instead of rendering it.
      router.go(AppRoutes.documents);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('sign_in_submit')), findsOneWidget);
      expect(find.byKey(const Key('documents_placeholder')), findsNothing);
    },
  );
}
