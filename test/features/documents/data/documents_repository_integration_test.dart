// Milestone 2.1 functional tests: real calls against the real deployed
// backend and the real Supabase project — no mocking. Requires internet
// access to run.
//
// Same gating as supabase_auth_integration_test.dart, for the same
// reason: creating a real confirmed test user still triggers a real
// confirmation-email SEND even though the admin API immediately
// confirms it without anyone clicking the link — the rate limit is on
// the send, not the click. Gated behind both
// --dart-define=RUN_REAL_SIGNUP_TEST=true and
// --dart-define=SUPABASE_SERVICE_ROLE_KEY=..., skipped cleanly
// (including in CI) otherwise.
//
// Each test creates its own fresh admin-confirmed throwaway user (real
// signUp -> real admin confirm -> real signInWithPassword, the same
// chain the real app uses, not an admin-bypass token) and tears it down
// afterward via the admin API — unlike supabase_auth_integration_test's
// users, these don't linger.
import 'dart:convert';
import 'dart:math';

import 'package:cerebro_mobile/core/config/supabase_config.dart';
import 'package:cerebro_mobile/core/network/generated_api_client.dart';
import 'package:cerebro_mobile/core/network/session_token_provider.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

const _serviceRoleKey = String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');
const _runRealSignupTest = bool.fromEnvironment('RUN_REAL_SIGNUP_TEST');
const _gated = !_runRealSignupTest || _serviceRoleKey == '';

String _randomTestEmail() {
  final suffix = Random().nextInt(1 << 32).toRadixString(36);
  return 'cerebro-mobile-test-$suffix@gmail.com';
}

/// RFC 4122 v4 — no `uuid` package dependency for one test file's fixture
/// ids; the `documents.id` column requires a real UUID.
String _randomUuid() {
  final rand = Random.secure();
  final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int start, int end) =>
      bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

class _FixedTokenProvider implements SessionTokenProvider {
  _FixedTokenProvider(this.currentAccessToken);
  @override
  final String? currentAccessToken;
}

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

Future<void> _adminDeleteUser(String userId) async {
  await http.delete(
    Uri.parse('${SupabaseConfig.url}/auth/v1/admin/users/$userId'),
    headers: {
      'apikey': _serviceRoleKey,
      'Authorization': 'Bearer $_serviceRoleKey',
    },
  );
}

/// Signs up + admin-confirms + signs in a fresh throwaway user, the same
/// chain the real app's sign-up -> tap-the-link -> sign-in flow produces
/// (minus the human tapping a link) — not a shortcut around RLS, just
/// around the manual email step.
Future<({String userId, String accessToken})> _freshConfirmedUser(
  supabase.SupabaseClient client,
) async {
  const password = 'Cerebro-Mobile-Test-2026!';
  final email = _randomTestEmail();
  final signUpResponse = await client.auth.signUp(email: email, password: password);
  final userId = signUpResponse.user!.id;
  await _adminConfirmUser(userId);
  final signInResponse = await client.auth.signInWithPassword(
    email: email,
    password: password,
  );
  await client.auth.signOut();
  return (userId: userId, accessToken: signInResponse.session!.accessToken);
}

/// Inserts a document row directly via Supabase's REST API under the
/// given user's own RLS-scoped session — the same "seed via direct
/// insert, not through the (not-yet-built, Milestone 2.2) upload flow"
/// pattern the backend's own test suite uses for documents_storage
/// fixtures.
Future<String> _seedDocument(
  String userId,
  String accessToken, {
  String status = 'ready',
}) async {
  final id = _randomUuid();
  final response = await http.post(
    Uri.parse('${SupabaseConfig.url}/rest/v1/documents'),
    headers: {
      'apikey': SupabaseConfig.anonKey,
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
      'Prefer': 'return=minimal',
    },
    body: jsonEncode({
      'id': id,
      'user_id': userId,
      'title': 'integration-test-doc.txt',
      'mime': 'text/plain',
      'size_bytes': 11,
      'status': status,
    }),
  );
  if (response.statusCode >= 300) {
    throw StateError('seed document failed: ${response.statusCode} ${response.body}');
  }
  return id;
}

void main() {
  late supabase.SupabaseClient client;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await supabase.Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    client = supabase.Supabase.instance.client;
  });

  group('ApiDocumentsRepository — real backend integration', () {
    test(
      'a user with zero documents sees an empty list, not an error',
      () async {
        if (_gated) {
          markTestSkipped(
            'needs --dart-define=RUN_REAL_SIGNUP_TEST=true and '
            '--dart-define=SUPABASE_SERVICE_ROLE_KEY=...',
          );
          return;
        }
        final user = await _freshConfirmedUser(client);
        addTearDown(() => _adminDeleteUser(user.userId));
        final repository = ApiDocumentsRepository(
          buildGeneratedApiClient(
            tokenProvider: _FixedTokenProvider(user.accessToken),
          ),
        );

        final documents = await repository.listDocuments();

        expect(documents, isEmpty);
      },
      timeout: const Timeout(Duration(seconds: 45)),
    );

    test(
      'a user with a document sees exactly their own, and a second user '
      "does not see the first user's — the same cross-user isolation "
      'the web project already verified at the API/RLS layer',
      () async {
        if (_gated) {
          markTestSkipped(
            'needs --dart-define=RUN_REAL_SIGNUP_TEST=true and '
            '--dart-define=SUPABASE_SERVICE_ROLE_KEY=...',
          );
          return;
        }
        final userA = await _freshConfirmedUser(client);
        addTearDown(() => _adminDeleteUser(userA.userId));
        final userB = await _freshConfirmedUser(client);
        addTearDown(() => _adminDeleteUser(userB.userId));

        final docId = await _seedDocument(userA.userId, userA.accessToken);

        final repoA = ApiDocumentsRepository(
          buildGeneratedApiClient(
            tokenProvider: _FixedTokenProvider(userA.accessToken),
          ),
        );
        final repoB = ApiDocumentsRepository(
          buildGeneratedApiClient(
            tokenProvider: _FixedTokenProvider(userB.accessToken),
          ),
        );

        final docsForA = await repoA.listDocuments();
        final docsForB = await repoB.listDocuments();

        expect(docsForA.map((d) => d.id), contains(docId));
        expect(docsForB.map((d) => d.id), isNot(contains(docId)));
        expect(docsForB, isEmpty);

        final detail = await repoA.getDocument(docId);
        expect(detail.id, docId);
        expect(detail.title, 'integration-test-doc.txt');
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}
