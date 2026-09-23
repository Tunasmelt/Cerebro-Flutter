import 'dart:async';

import 'package:cerebro_mobile/features/auth/data/auth_exception.dart';
import 'package:cerebro_mobile/features/auth/data/auth_repository.dart';

/// Shared test double for widget tests that render [SignInScreen] /
/// [SignUpScreen] — never touches a real Supabase client.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({String? initialUserId}) : _userId = initialUserId;

  final _controller = StreamController<String?>.broadcast();
  String? _userId;

  /// Configure what the next signIn/signUp call does: a `String` user
  /// id (success), an [AuthFailureException] (failure), or a
  /// [SignUpOutcome] (for signUp).
  Object? nextResult;

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

  /// Set to an [AuthFailureException] to make the next resend fail.
  Object? nextResendResult;
  final resendCalls = <String>[];

  @override
  Future<void> resendConfirmation({required String email}) async {
    resendCalls.add(email);
    final result = nextResendResult;
    if (result is AuthFailureException) throw result;
  }

  /// Simulates an error arriving on the auth stream, e.g. a failed
  /// confirmation deep link.
  void emitStreamError(Object error) => _controller.addError(error);

  @override
  Future<void> signOut() async {
    _userId = null;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}
