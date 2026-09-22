// Milestone 1.1 functional tests: real calls against the real Supabase
// project — no mocking. Requires internet access to run.
//
// This Supabase project requires email confirmation before a session
// exists (confirmed directly against the live project — see
// CHANGELOG.md's Phase 1 audit entry). A plain `flutter test` can't
// click an emailed confirmation link, so:
//  - the sign-up test proves the real, expected outcome
//    (needsEmailConfirmation), which IS the correct behavior to prove
//    here, not a workaround around it.
//  - the wrong-password and "user exists in the Auth table" checks need
//    a pre-confirmed test account, which needs Supabase's admin API
//    (service_role key). That key is never hardcoded or committed —
//    passed only via --dart-define=SUPABASE_SERVICE_ROLE_KEY=... at
//    run time, and those tests skip cleanly (not fail) when it's
//    unset, which is the expected state in CI unless that secret is
//    deliberately added later.
//  - "session persists across a real app restart" is inherently a real
//    on-device behavior (this Supabase project's session persistence is
//    supabase_flutter's own tested responsibility) — verified live on
//    the emulator, not by this test file. See CHANGELOG.md.
//
// IMPORTANT: every test in this file that calls the real signUp()
// triggers a real confirmation EMAIL SEND, which is rate-limited by
// Supabase's built-in test SMTP (a handful per hour, shared across the
// whole project — burned through repeatedly during this session's own
// testing, see CHANGELOG.md's rate-limit finding). Unlike the /health
// checks elsewhere, this is NOT safe to run unconditionally on every CI
// trigger — it would make CI flaky from quota exhaustion, not real
// bugs, and could starve real users' signup emails on a shared project.
// Gated behind an explicit opt-in, same treatment as the
// service_role-gated tests below: skipped by default (including in
// CI), only runs with --dart-define=RUN_REAL_SIGNUP_TEST=true.
import 'dart:convert';
import 'dart:math';

import 'package:cerebro_mobile/core/config/supabase_config.dart';
import 'package:cerebro_mobile/features/auth/data/auth_exception.dart';
import 'package:cerebro_mobile/features/auth/data/auth_repository.dart';
import 'package:cerebro_mobile/features/auth/data/supabase_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

const _serviceRoleKey = String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');
const _runRealSignupTest = bool.fromEnvironment('RUN_REAL_SIGNUP_TEST');

String _randomTestEmail() {
  final suffix = Random().nextInt(1 << 32).toRadixString(36);
  return 'cerebro-mobile-test-$suffix@gmail.com';
}

/// Creates and immediately confirms a throwaway test user via Supabase's
/// admin API. Only called when [_serviceRoleKey] is provided.
Future<void> _adminConfirmUser(String userId) async {
  final response = await http.put(
    Uri.parse('${SupabaseConfig.url}/auth/v1/admin/users/$userId'),
    headers: {
      'apikey': _serviceRoleKey,
      'Authorization': 'Bearer $_serviceRoleKey',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'email_confirm': true}),
  );
  if (response.statusCode != 200) {
    throw StateError('admin confirm failed: ${response.statusCode} ${response.body}');
  }
}

/// Looks up a user by email via the admin API — the "cross-check: a
/// user created via this app's sign-up exists in the same Supabase Auth
/// table the web app uses" functional test.
Future<bool> _adminUserExists(String email) async {
  final response = await http.get(
    Uri.parse('${SupabaseConfig.url}/auth/v1/admin/users?email=$email'),
    headers: {
      'apikey': _serviceRoleKey,
      'Authorization': 'Bearer $_serviceRoleKey',
    },
  );
  if (response.statusCode != 200) {
    throw StateError('admin lookup failed: ${response.statusCode} ${response.body}');
  }
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final users = body['users'] as List<dynamic>;
  return users.any((u) => (u as Map<String, dynamic>)['email'] == email);
}

void main() {
  late AuthRepository repository;
  late supabase.SupabaseClient client;

  setUpAll(() async {
    // Supabase.initialize() persists sessions via shared_preferences,
    // which needs a platform channel — unavailable in plain `flutter
    // test` (Dart VM, no device). Mocking it is shared_preferences'
    // own documented pattern for exactly this.
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await supabase.Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    client = supabase.Supabase.instance.client;
    repository = SupabaseAuthRepository(client.auth);
  });

  group('SupabaseAuthRepository — real backend integration', () {
    test(
      'signing up a real test user returns needsEmailConfirmation (this project requires it)',
      () async {
        if (!_runRealSignupTest) {
          markTestSkipped(
            'needs --dart-define=RUN_REAL_SIGNUP_TEST=true — sends a real '
            'email, rate-limited by Supabase, not run unconditionally in CI',
          );
          return;
        }
        final email = _randomTestEmail();

        final outcome = await repository.signUp(
          email: email,
          password: 'Cerebro-Mobile-Test-2026!',
        );

        expect(outcome, SignUpOutcome.needsEmailConfirmation);
        expect(repository.currentUserId, isNull);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'cross-check: a user created via this app\'s sign-up exists in the same Supabase Auth table web uses',
      () async {
        if (!_runRealSignupTest || _serviceRoleKey.isEmpty) {
          markTestSkipped(
            'needs --dart-define=RUN_REAL_SIGNUP_TEST=true and '
            '--dart-define=SUPABASE_SERVICE_ROLE_KEY=... (not set in CI by default)',
          );
          return;
        }
        final email = _randomTestEmail();
        await repository.signUp(
          email: email,
          password: 'Cerebro-Mobile-Test-2026!',
        );

        final exists = await _adminUserExists(email);

        expect(exists, isTrue);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'signing in with a deliberately wrong password shows the correct inline error, not a crash',
      () async {
        if (!_runRealSignupTest || _serviceRoleKey.isEmpty) {
          markTestSkipped(
            'needs --dart-define=RUN_REAL_SIGNUP_TEST=true and '
            '--dart-define=SUPABASE_SERVICE_ROLE_KEY=... to confirm a real test account first',
          );
          return;
        }
        final email = _randomTestEmail();
        final signUpResponse = await client.auth.signUp(
          email: email,
          password: 'Cerebro-Mobile-Test-2026!',
        );
        await _adminConfirmUser(signUpResponse.user!.id);

        await expectLater(
          repository.signIn(email: email, password: 'definitely-the-wrong-password'),
          throwsA(
            isA<AuthFailureException>().having(
              (e) => e.message,
              'message',
              'Incorrect email or password.',
            ),
          ),
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
