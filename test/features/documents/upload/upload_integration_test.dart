// Milestone 2.2 functional tests: the REAL upload flow against the real
// deployed backend and real Supabase Storage — no mocking.
//
// Gating (skipped cleanly otherwise, including in CI):
//  - CEREBRO_TEST_EMAIL / CEREBRO_TEST_PASSWORD (--dart-define): an
//    existing, already-confirmed test account. Signing in sends no email,
//    so unlike the Milestone 1.1/2.1 real-signup tests this needs no
//    rate-limit-protecting opt-in. Never hardcoded or committed.
//  - RUN_LARGE_UPLOAD_TEST=true additionally enables the ~100 MB
//    boundary test (it moves real bytes to real Storage).
//
// RATE-LIMIT BUDGET: the backend allows only 10 `upload-init` calls per
// user per hour (`services/api/app/core/rate_limit.py`, a sliding window;
// rejected calls aren't counted). This file spends 5 of them per run
// (e2e 1, abandoned 1, confirm-without-PUT 1, rejections 2) and the
// opt-in large test 2 more — so don't run it more than once an hour
// against the same account, or the app (and the next run) will get a
// 429 "Too many requests". Found the hard way during Milestone 2.2's live
// camera test, which hit the limit this suite had just consumed.
//
// Every document a test creates is deleted afterwards through the
// backend's own DELETE endpoint (which also removes the Storage object),
// so nothing lingers on the shared project.
import 'dart:async';
import 'dart:convert';

import 'package:cerebro_mobile/core/config/supabase_config.dart';
import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/core/network/generated/cerebro_api.swagger.dart';
import 'package:cerebro_mobile/core/network/generated_api_client.dart';
import 'package:cerebro_mobile/core/network/session_token_provider.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository.dart';
import 'package:cerebro_mobile/features/documents/data/upload/picked_upload.dart';
import 'package:cerebro_mobile/features/documents/data/upload/storage_uploader.dart';
import 'package:cerebro_mobile/features/documents/data/upload/upload_api.dart';
import 'package:cerebro_mobile/features/documents/data/upload/upload_constraints.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const _email = String.fromEnvironment('CEREBRO_TEST_EMAIL');
const _password = String.fromEnvironment('CEREBRO_TEST_PASSWORD');
const _runLarge = bool.fromEnvironment('RUN_LARGE_UPLOAD_TEST');
const _gated = _email == '' || _password == '';

class _FixedTokenProvider implements SessionTokenProvider {
  _FixedTokenProvider(this.currentAccessToken);
  @override
  final String? currentAccessToken;
}

class _Session {
  _Session(this.userId, this.accessToken);
  final String userId;
  final String accessToken;
}

/// A real sign-in via Supabase Auth's REST endpoint — the same call
/// supabase_flutter makes — without needing the SDK's platform-channel
/// storage in a plain Dart-VM test.
Future<_Session> _signIn() async {
  final response = await http.post(
    Uri.parse('${SupabaseConfig.url}/auth/v1/token?grant_type=password'),
    headers: {
      'apikey': SupabaseConfig.anonKey,
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'email': _email, 'password': _password}),
  );
  if (response.statusCode != 200) {
    throw StateError('test sign-in failed: ${response.statusCode}');
  }
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  return _Session(
    (body['user'] as Map<String, dynamic>)['id'] as String,
    body['access_token'] as String,
  );
}

PickedUpload _textFile(String name, String content) {
  final bytes = utf8.encode(content);
  return PickedUpload(
    name: name,
    mime: 'text/plain',
    sizeBytes: bytes.length,
    openRead: () => Stream<List<int>>.value(bytes),
  );
}

/// A file of exactly [size] bytes, streamed in 1 MiB chunks — never held
/// in memory, since the boundary test is ~50 MiB.
PickedUpload _zeroFile(String name, int size) {
  return PickedUpload(
    name: name,
    mime: 'text/plain',
    sizeBytes: size,
    openRead: () async* {
      const chunk = 1024 * 1024;
      var remaining = size;
      final block = List<int>.filled(chunk, 0x61);
      while (remaining > 0) {
        final n = remaining < chunk ? remaining : chunk;
        yield n == chunk ? block : block.sublist(0, n);
        remaining -= n;
      }
    },
  );
}

/// Lists the objects Storage holds under `<user>/<document>/` — the
/// ground truth for "the object exists after the upload".
Future<List<String>> _storageObjects(_Session s, String documentId) async {
  final response = await http.post(
    Uri.parse('${SupabaseConfig.url}/storage/v1/object/list/originals'),
    headers: {
      'apikey': SupabaseConfig.anonKey,
      'Authorization': 'Bearer ${s.accessToken}',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'prefix': '${s.userId}/$documentId'}),
  );
  expect(response.statusCode, 200, reason: 'storage list: ${response.body}');
  return (jsonDecode(response.body) as List<dynamic>)
      .map((o) => (o as Map<String, dynamic>)['name'] as String)
      .toList();
}

void main() {
  late _Session session;
  late CerebroApi api;
  late UploadApi uploadApi;
  late DocumentsRepository documents;
  late StorageUploader storage;

  setUpAll(() async {
    if (_gated) return;
    session = await _signIn();
    api = buildGeneratedApiClient(
      tokenProvider: _FixedTokenProvider(session.accessToken),
    );
    uploadApi = ApiUploadApi(api);
    documents = ApiDocumentsRepository(api);
    storage = DioStorageUploader(
      tokenProvider: _FixedTokenProvider(session.accessToken),
      apiKey: SupabaseConfig.anonKey,
    );
  });

  /// Deletes through the backend, which removes Storage objects too.
  void deleteAfter(String documentId) {
    addTearDown(() async {
      await api.apiV1DocumentsDocumentIdDelete(documentId: documentId);
    });
  }

  void skipUnlessConfigured() {
    if (_gated) {
      markTestSkipped(
        'needs --dart-define=CEREBRO_TEST_EMAIL=... and '
        '--dart-define=CEREBRO_TEST_PASSWORD=... (a confirmed test account)',
      );
    }
  }

  group('upload flow — real backend, real Storage', () {
    test(
      'a small file goes init → PUT → confirm end to end; the object exists '
      'in Storage and confirm advanced the job past `uploading`',
      () async {
        if (_gated) return skipUnlessConfigured();
        const content = 'Cerebro Milestone 2.2 integration test.\n';
        final file = _textFile('m22-e2e.txt', content);

        final init = await uploadApi.init(
          filename: file.name,
          mime: 'text/plain',
          sizeBytes: file.sizeBytes,
        );
        deleteAfter(init.documentId);

        await storage.put(
          uploadUrl: init.uploadUrl,
          file: file,
          mime: 'text/plain',
        );

        // The object really is in Storage now.
        expect(
          await _storageObjects(session, init.documentId),
          contains('original.txt'),
        );

        final confirmation = await uploadApi.confirm(init.documentId);
        expect(confirmation.documentId, init.documentId);
        expect(confirmation.state, 'normalizing');
        expect(confirmation.sizeBytes, file.sizeBytes);

        final detail = await documents.getDocument(init.documentId);
        expect(detail.title, 'm22-e2e.txt');
        expect(detail.mime, 'text/plain');
        expect(detail.sizeBytes, file.sizeBytes, reason: 'confirm recorded size');
        expect(
          detail.ingestState,
          isNot('uploading'),
          reason: 'confirm advanced the job past uploading',
        );

        // Let the in-process ingest pipeline finish before teardown deletes
        // the document, so deletion doesn't race it.
        for (var i = 0; i < 45; i++) {
          final d = await documents.getDocument(init.documentId);
          if (d.ingestState == 'ready' || d.ingestState == 'failed') break;
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'an upload that never calls confirm is left in `uploading` — not '
      'orphaned, not falsely ready',
      () async {
        if (_gated) return skipUnlessConfigured();
        final init = await uploadApi.init(
          filename: 'm22-abandoned.txt',
          mime: 'text/plain',
          sizeBytes: 10,
        );
        deleteAfter(init.documentId);
        // The flow is "killed" here: no PUT, no confirm.

        final detail = await documents.getDocument(init.documentId);
        expect(detail.ingestState, 'uploading');
        expect(detail.status, DocumentStatus.processing);
        expect(detail.status, isNot(DocumentStatus.ready));
        expect(detail.lastError, isNull);

        final listed = (await documents.listDocuments())
            .firstWhere((d) => d.id == init.documentId);
        expect(listed.status, DocumentStatus.processing);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      "confirm without a PUT is refused by the server: the object must "
      'actually exist — and the job stays `uploading`',
      () async {
        if (_gated) return skipUnlessConfigured();
        final init = await uploadApi.init(
          filename: 'm22-no-put.txt',
          mime: 'text/plain',
          sizeBytes: 10,
        );
        deleteAfter(init.documentId);

        await expectLater(
          uploadApi.confirm(init.documentId),
          throwsA(
            isA<RequestRejectedException>()
                .having((e) => e.code, 'code', 'upload_not_found')
                .having(
                  (e) => e.message,
                  'message',
                  'No uploaded object found for this document yet',
                ),
          ),
        );

        final detail = await documents.getDocument(init.documentId);
        expect(detail.ingestState, 'uploading');
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'the server rejects an unsupported type and an oversized claim before '
      'issuing any upload URL',
      () async {
        if (_gated) return skipUnlessConfigured();

        await expectLater(
          uploadApi.init(
            filename: 'archive.zip',
            mime: 'application/zip',
            sizeBytes: 10,
          ),
          throwsA(
            isA<RequestRejectedException>().having(
              (e) => e.code,
              'code',
              'unsupported_mime_type',
            ),
          ),
        );

        await expectLater(
          uploadApi.init(
            filename: 'huge.pdf',
            mime: 'application/pdf',
            sizeBytes: kMaxUploadBytes + 1,
          ),
          throwsA(
            isA<RequestRejectedException>()
                .having((e) => e.code, 'code', 'file_too_large')
                .having(
                  (e) => e.message,
                  'message',
                  'File exceeds the 50MB upload limit',
                ),
          ),
        );
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'an expired/unauthorized session surfaces as a typed error, not a crash',
      () async {
        if (_gated) return skipUnlessConfigured();
        final stale = ApiUploadApi(
          buildGeneratedApiClient(
            tokenProvider: _FixedTokenProvider('not-a-real-token'),
          ),
        );

        // `confirm`, not `init`: auth fails before any work happens, and
        // only `upload-init` counts against the hourly rate limit.
        await expectLater(
          stale.confirm('00000000-0000-0000-0000-000000000000'),
          throwsA(isA<UnauthorizedException>()),
        );
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });

  group('the 50 MiB ceiling — against real Storage', () {
    test(
      'exactly 52,428,800 bytes is accepted; one byte more is rejected, '
      'cleanly, as a typed error',
      () async {
        if (_gated) return skipUnlessConfigured();
        if (!_runLarge) {
          return markTestSkipped(
            'needs --dart-define=RUN_LARGE_UPLOAD_TEST=true (moves ~100 MB)',
          );
        }

        // At the limit: accepted. Deliberately NOT confirmed — confirming
        // would start ingest on a 50 MiB text file, hammering the
        // backend's pipeline for no benefit; the boundary under test is
        // Storage's, and the PUT is where it is enforced.
        final atLimit = _zeroFile('m22-at-limit.txt', kMaxUploadBytes);
        final okInit = await uploadApi.init(
          filename: atLimit.name,
          mime: 'text/plain',
          sizeBytes: atLimit.sizeBytes,
        );
        deleteAfter(okInit.documentId);
        await storage.put(
          uploadUrl: okInit.uploadUrl,
          file: atLimit,
          mime: 'text/plain',
        );
        expect(
          await _storageObjects(session, okInit.documentId),
          contains('original.txt'),
        );

        // One byte over: init is told the legal size (a client that lies
        // about size_bytes), so only Storage — the real boundary — can
        // refuse it.
        final overLimit = _zeroFile('m22-over-limit.txt', kMaxUploadBytes + 1);
        final badInit = await uploadApi.init(
          filename: overLimit.name,
          mime: 'text/plain',
          sizeBytes: kMaxUploadBytes,
        );
        deleteAfter(badInit.documentId);
        await expectLater(
          storage.put(
            uploadUrl: badInit.uploadUrl,
            file: overLimit,
            mime: 'text/plain',
          ),
          throwsA(isA<RequestRejectedException>()),
        );
      },
      timeout: const Timeout(Duration(minutes: 12)),
    );
  });
}
