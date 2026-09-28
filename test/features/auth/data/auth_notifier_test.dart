import 'package:cerebro_mobile/features/auth/data/auth_exception.dart';
import 'package:cerebro_mobile/features/auth/data/auth_notifier.dart';
import 'package:cerebro_mobile/features/auth/data/auth_repository.dart';
import 'package:cerebro_mobile/features/auth/data/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_auth_repository.dart';

void main() {
  late FakeAuthRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fakeRepository)],
    );
  });

  tearDown(() {
    container.dispose();
    fakeRepository.dispose();
  });

  AuthNotifier notifier() => container.read(authNotifierProvider.notifier);
  AuthState state() => container.read(authNotifierProvider);

  group('AuthNotifier', () {
    test(
      'a mock sign-in success transitions state to Authenticated with a non-null user id',
      () async {
        fakeRepository.nextResult = 'user-123';

        await notifier().signIn(
          email: 'person@example.com',
          password: 'correct-password',
        );

        expect(state(), isA<Authenticated>());
        expect((state() as Authenticated).userId, 'user-123');
      },
    );

    test(
      'a mock sign-in failure transitions state to Unauthenticated with a plain-language message, not a raw exception',
      () async {
        fakeRepository.nextResult = const AuthFailureException(
          'Incorrect email or password.',
        );

        await notifier().signIn(
          email: 'person@example.com',
          password: 'wrong-password',
        );

        expect(state(), isA<Unauthenticated>());
        expect(
          (state() as Unauthenticated).errorMessage,
          'Incorrect email or password.',
        );
      },
    );

    test(
      'sign-up needing email confirmation transitions to AwaitingEmailConfirmation',
      () async {
        fakeRepository.nextResult = SignUpOutcome.needsEmailConfirmation;

        await notifier().signUp(
          email: 'new-person@example.com',
          password: 'a-strong-password',
        );

        expect(state(), isA<AwaitingEmailConfirmation>());
        expect(
          (state() as AwaitingEmailConfirmation).email,
          'new-person@example.com',
        );
      },
    );

    test('starts Authenticated when the repository already has a session', () {
      final signedIn = FakeAuthRepository(initialUserId: 'existing-user');
      final scoped = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(signedIn)],
      );
      addTearDown(scoped.dispose);
      addTearDown(signedIn.dispose);

      final s = scoped.read(authNotifierProvider);
      expect(s, isA<Authenticated>());
      expect((s as Authenticated).userId, 'existing-user');
    });
  });

  group('AuthNotifier.clearStatus', () {
    test('drops a stale sign-in error', () async {
      fakeRepository.nextResult = const AuthFailureException('nope');
      await notifier().signIn(email: 'a@b.co', password: 'x');
      expect((state() as Unauthenticated).errorMessage, 'nope');

      notifier().clearStatus();

      expect((state() as Unauthenticated).errorMessage, isNull);
    });

    test('drops a finished sign-up\'s "check your email" state', () async {
      fakeRepository.nextResult = SignUpOutcome.needsEmailConfirmation;
      await notifier().signUp(email: 'typo@b.co', password: 'secret1');
      expect(state(), isA<AwaitingEmailConfirmation>());

      notifier().clearStatus();

      expect(state(), isA<Unauthenticated>());
    });

    test('never signs anyone out', () async {
      fakeRepository.nextResult = 'user-1';
      await notifier().signIn(email: 'a@b.co', password: 'x');

      notifier().clearStatus();

      expect(state(), isA<Authenticated>());
    });
  });

  group('AuthNotifier auth-stream errors (failed confirmation link)', () {
    test('while signed out, surfaces a plain-language error', () async {
      // Keep the notifier alive so it is subscribed to the stream.
      notifier();
      fakeRepository.emitStreamError(
        const AuthFailureException('That confirmation link has expired.'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(state(), isA<Unauthenticated>());
      expect(
        (state() as Unauthenticated).errorMessage,
        'That confirmation link has expired.',
      );
    });

    test(
      'while awaiting confirmation, keeps the user on that screen with the error',
      () async {
        fakeRepository.nextResult = SignUpOutcome.needsEmailConfirmation;
        await notifier().signUp(email: 'p@b.co', password: 'secret1');

        fakeRepository.emitStreamError(
          const AuthFailureException('That confirmation link has expired.'),
        );
        await Future<void>.delayed(Duration.zero);

        final s = state() as AwaitingEmailConfirmation;
        expect(s.email, 'p@b.co');
        expect(s.errorMessage, 'That confirmation link has expired.');
      },
    );

    test('a background error never disturbs a signed-in user', () async {
      fakeRepository.nextResult = 'user-1';
      await notifier().signIn(email: 'a@b.co', password: 'x');

      fakeRepository.emitStreamError(const AuthFailureException('flaky'));
      await Future<void>.delayed(Duration.zero);

      expect(state(), isA<Authenticated>());
    });

    test('an unexpected non-auth error still gets a plain-language message', () async {
      notifier();
      fakeRepository.emitStreamError(StateError('boom'));
      await Future<void>.delayed(Duration.zero);

      expect(
        (state() as Unauthenticated).errorMessage,
        'Something went wrong. Try again.',
      );
    });
  });

  group('AuthNotifier.resendConfirmation', () {
    test('returns null on success and does not change auth state', () async {
      fakeRepository.nextResult = SignUpOutcome.needsEmailConfirmation;
      await notifier().signUp(email: 'p@b.co', password: 'secret1');

      final error = await notifier().resendConfirmation('p@b.co');

      expect(error, isNull);
      expect(fakeRepository.resendCalls, ['p@b.co']);
      expect(state(), isA<AwaitingEmailConfirmation>());
    });

    test('returns the plain-language message on failure', () async {
      fakeRepository.nextResendResult = const AuthFailureException(
        'Too many attempts. Wait a few minutes and try again.',
      );

      final error = await notifier().resendConfirmation('p@b.co');

      expect(error, 'Too many attempts. Wait a few minutes and try again.');
    });
  });
}
