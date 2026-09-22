import 'dart:async';

import 'package:cerebro_mobile/features/auth/data/auth_exception.dart';
import 'package:cerebro_mobile/features/auth/data/auth_notifier.dart';
import 'package:cerebro_mobile/features/auth/data/auth_repository.dart';
import 'package:cerebro_mobile/features/auth/data/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository();

  final _controller = StreamController<String?>.broadcast();
  String? _userId;

  /// Test hook: what the next signIn/signUp call should do.
  Object? nextResult; // String userId, AuthFailureException, or SignUpOutcome

  @override
  String? get currentUserId => _userId;

  @override
  Stream<String?> get userIdChanges => _controller.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    final result = nextResult;
    if (result is AuthFailureException) throw result;
    if (result is String) {
      _userId = result;
      _controller.add(result);
      return;
    }
    throw StateError('nextResult not configured for signIn');
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) async {
    final result = nextResult;
    if (result is AuthFailureException) throw result;
    if (result is SignUpOutcome) return result;
    throw StateError('nextResult not configured for signUp');
  }

  @override
  Future<void> signOut() async {
    _userId = null;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}

void main() {
  late _FakeAuthRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = _FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fakeRepository)],
    );
  });

  tearDown(() {
    container.dispose();
    fakeRepository.dispose();
  });

  group('AuthNotifier', () {
    test(
      'a mock sign-in success transitions state to Authenticated with a non-null user id',
      () async {
        fakeRepository.nextResult = 'user-123';

        await container.read(authNotifierProvider.notifier).signIn(
          email: 'person@example.com',
          password: 'correct-password',
        );

        final state = container.read(authNotifierProvider);
        expect(state, isA<Authenticated>());
        expect((state as Authenticated).userId, 'user-123');
      },
    );

    test(
      'a mock sign-in failure transitions state to Unauthenticated with a plain-language message, not a raw exception',
      () async {
        fakeRepository.nextResult = const AuthFailureException(
          'Incorrect email or password.',
        );

        await container.read(authNotifierProvider.notifier).signIn(
          email: 'person@example.com',
          password: 'wrong-password',
        );

        final state = container.read(authNotifierProvider);
        expect(state, isA<Unauthenticated>());
        expect(
          (state as Unauthenticated).errorMessage,
          'Incorrect email or password.',
        );
      },
    );

    test(
      'sign-up needing email confirmation transitions to AwaitingEmailConfirmation',
      () async {
        fakeRepository.nextResult = SignUpOutcome.needsEmailConfirmation;

        await container.read(authNotifierProvider.notifier).signUp(
          email: 'new-person@example.com',
          password: 'a-strong-password',
        );

        final state = container.read(authNotifierProvider);
        expect(state, isA<AwaitingEmailConfirmation>());
        expect(
          (state as AwaitingEmailConfirmation).email,
          'new-person@example.com',
        );
      },
    );

    test('starts Authenticated when the repository already has a session', () {
      final alreadySignedInRepository = _FakeAuthRepository();
      alreadySignedInRepository._userId = 'existing-user';
      final scopedContainer = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(alreadySignedInRepository),
        ],
      );
      addTearDown(scopedContainer.dispose);
      addTearDown(alreadySignedInRepository.dispose);

      final state = scopedContainer.read(authNotifierProvider);
      expect(state, isA<Authenticated>());
      expect((state as Authenticated).userId, 'existing-user');
    });
  });
}
