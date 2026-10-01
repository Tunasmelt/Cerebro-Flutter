// Per-user state must not survive a sign-out. Providers live as long as
// the app's ProviderScope, so anything holding one user's data (their
// document list, their in-flight uploads) has to be reset when the signed-in
// user changes — otherwise the next person to sign in on the same device
// sees the previous user's data until a manual refresh.
import 'dart:async';

import 'package:cerebro_mobile/core/network/connection_status_notifier.dart';
import 'package:cerebro_mobile/features/auth/data/auth_notifier.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/documents/data/upload/upload_controller.dart';
import 'package:cerebro_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/network/fake_connection_status_notifier.dart';
import '../features/auth/fake_auth_repository.dart';
import '../features/documents/upload/fake_upload_services.dart';

/// Returns whichever documents belong to the user signed in AT CALL TIME,
/// like the real backend's RLS-scoped list does.
class _PerUserDocuments implements DocumentsRepository {
  _PerUserDocuments(this._auth);

  final FakeAuthRepository _auth;

  static DocumentSummary doc(String title) => DocumentSummary(
    id: 'id-$title',
    title: title,
    mime: 'text/plain',
    sizeBytes: 1,
    originalSizeBytes: 1,
    status: DocumentStatus.ready,
    createdAt: DateTime.utc(2026),
  );

  @override
  Future<List<DocumentSummary>> listDocuments() async {
    switch (_auth.currentUserId) {
      case 'user-a':
        return [doc('alice-private.txt')];
      case 'user-b':
        return [doc('bob-notes.txt')];
    }
    return const [];
  }

  @override
  Future<DocumentDetail> getDocument(String documentId) =>
      throw UnimplementedError();
}

void main() {
  late FakeAuthRepository auth;
  late CallLog log;
  late FakeUploadApi uploadApi;
  late FakeStorageUploader storage;

  setUp(() {
    auth = FakeAuthRepository(initialUserId: 'user-a');
    log = CallLog();
    uploadApi = FakeUploadApi(log);
    storage = FakeStorageUploader(log);
  });
  tearDown(() => auth.dispose());

  Widget app() => ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      connectionStatusProvider.overrideWith(
        () => FakeConnectionStatusNotifier(() async {}),
      ),
      documentsRepositoryProvider.overrideWithValue(_PerUserDocuments(auth)),
      uploadApiProvider.overrideWithValue(uploadApi),
      storageUploaderProvider.overrideWithValue(storage),
    ],
    child: const CerebroApp(),
  );

  Future<void> switchUser(WidgetTester tester, String to) async {
    await auth.signOut();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sign_in_submit')), findsOneWidget);

    auth.nextResult = to;
    await auth.signIn(email: '$to@example.com', password: 'x');
    await tester.pumpAndSettle();
  }

  testWidgets(
    "the next user to sign in never sees the previous user's documents",
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('alice-private.txt'), findsOneWidget);

      await switchUser(tester, 'user-b');

      expect(
        find.text('alice-private.txt'),
        findsNothing,
        reason: "user A's document list leaked into user B's session",
      );
      expect(find.text('bob-notes.txt'), findsOneWidget);
    },
  );

  testWidgets(
    "a failed upload row from the previous user doesn't appear for the next",
    (tester) async {
      uploadApi.initError = StateError('boom');
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      await container
          .read(uploadsProvider.notifier)
          .upload(fakePickedUpload(name: 'alice-secret-plans.txt'));
      await tester.pumpAndSettle();
      expect(find.text('alice-secret-plans.txt'), findsOneWidget);

      await switchUser(tester, 'user-b');

      expect(
        find.text('alice-secret-plans.txt'),
        findsNothing,
        reason: "user A's upload filenames leaked into user B's session",
      );
    },
  );

  testWidgets(
    "an upload still in flight when the user changes is abandoned: it never "
    "calls upload-confirm under the next user's session",
    (tester) async {
      final putGate = Completer<void>();
      storage.putGate = putGate;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      // Not awaited: user A's upload is mid-PUT when A signs out.
      final running = container
          .read(uploadsProvider.notifier)
          .upload(fakePickedUpload(name: 'alice-big-scan.txt'));
      await tester.pump();
      expect(log.entries, ['init', 'put']);

      // Settle between the two steps, as a real sign-out → sign-in is.
      await auth.signOut();
      await tester.pumpAndSettle();
      auth.nextResult = 'user-b';
      await auth.signIn(email: 'b@example.com', password: 'x');
      await tester.pumpAndSettle();

      putGate.complete();
      await running;
      await tester.pumpAndSettle();

      expect(
        log.entries,
        isNot(contains('confirm')),
        reason: "user A's upload carried on and confirmed under user B",
      );
      expect(find.text('alice-big-scan.txt'), findsNothing);
    },
  );
}
