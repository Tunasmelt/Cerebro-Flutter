import 'package:cerebro_mobile/app/router.dart';
import 'package:cerebro_mobile/features/auth/data/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeRedirect', () {
    test('unauthenticated user hitting a protected route is sent to sign-in', () {
      final redirect = computeRedirect(
        authState: const Unauthenticated(),
        matchedLocation: AppRoutes.documents,
      );
      expect(redirect, AppRoutes.signIn);
    });

    test('unauthenticated user already on sign-in is not redirected', () {
      final redirect = computeRedirect(
        authState: const Unauthenticated(),
        matchedLocation: AppRoutes.signIn,
      );
      expect(redirect, isNull);
    });

    test('unauthenticated user on sign-up is not redirected', () {
      final redirect = computeRedirect(
        authState: const Unauthenticated(),
        matchedLocation: AppRoutes.signUp,
      );
      expect(redirect, isNull);
    });

    test('a mid-sign-in AuthLoading state is treated as unauthenticated for routing', () {
      final redirect = computeRedirect(
        authState: const AuthLoading(),
        matchedLocation: AppRoutes.board,
      );
      expect(redirect, AppRoutes.signIn);
    });

    test('AwaitingEmailConfirmation keeps the user on the auth flow, not redirected away', () {
      final redirect = computeRedirect(
        authState: const AwaitingEmailConfirmation('person@example.com'),
        matchedLocation: AppRoutes.signUp,
      );
      expect(redirect, isNull);
    });

    test('authenticated user hitting sign-in is redirected to Documents', () {
      final redirect = computeRedirect(
        authState: const Authenticated('user-123'),
        matchedLocation: AppRoutes.signIn,
      );
      expect(redirect, AppRoutes.documents);
    });

    test('authenticated user on a protected route stays put', () {
      final redirect = computeRedirect(
        authState: const Authenticated('user-123'),
        matchedLocation: AppRoutes.board,
      );
      expect(redirect, isNull);
    });
  });
}
