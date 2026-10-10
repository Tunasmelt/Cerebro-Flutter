import 'dart:async';

import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/documents/data/documents_list_notifier.dart';
import 'package:cerebro_mobile/features/sealed/data/sealed_document_api.dart';
import 'package:cerebro_mobile/features/sealed/data/unlock_session.dart';
import 'package:cerebro_mobile/features/sealed/presentation/sealed_document_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../documents/fake_documents_repository.dart';

class _Api implements SealedDocumentApi {
  var pending = Completer<ActiveUnlock>();
  String? password;
  String? documentId;
  int unlockCalls = 0;
  int sealCalls = 0;
  Completer<void>? sealPending;
  @override
  Future<void> seal(String documentId, String passphrase) async {
    sealCalls++;
    password = passphrase;
    this.documentId = documentId;
    await sealPending?.future;
  }

  @override
  Future<ActiveUnlock> unlock(String documentId, String passphrase) {
    unlockCalls++;
    this.documentId = documentId;
    password = passphrase;
    return pending.future;
  }
}

void main() {
  final user = StateProvider<String?>((ref) => 'user');
  Future<ProviderContainer> show(
    WidgetTester tester,
    _Api api, {
    DocumentStatus status = DocumentStatus.sealed,
    String documentId = 'doc',
    ProviderContainer? container,
  }) async {
    final ownsContainer = container == null;
    container ??= ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => ref.watch(user)),
        sealedDocumentApiProvider.overrideWithValue(api),
        documentsRepositoryProvider.overrideWithValue(
          FakeDocumentsRepository(),
        ),
      ],
    );
    if (ownsContainer) addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SealedDocumentControls(
              documentId: documentId,
              status: status,
            ),
          ),
        ),
      ),
    );
    return container;
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('sealed_open_prompt')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('sealed_passphrase')),
      '  password  ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('sealed_confirm')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('sealed_passphrase')))
          .controller!
          .text,
      isEmpty,
    );
  }

  testWidgets('unlock renders content/countdown; manual lock removes session', (
    tester,
  ) async {
    final api = _Api();
    final container = await show(tester, api);
    await submit(tester);
    expect(api.password, '  password  ');
    api.pending.complete(
      ActiveUnlock(
        documentId: 'doc',
        claimId: 'claim',
        key: 'key',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        content: 'secret',
      ),
    );
    await tester.pump();
    expect(find.text('secret'), findsOneWidget);
    expect(find.byKey(const Key('sealed_countdown')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sealed_lock')));
    await tester.pump();
    expect(find.text('secret'), findsNothing);
    expect(container.read(unlockSessionProvider), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unlock failures are generic with no content or claim', (
    tester,
  ) async {
    final api = _Api();
    final container = await show(tester, api);
    await submit(tester);
    api.pending.completeError(
      StateError('Incorrect passphrase: sensitive reason'),
    );
    await tester.pump();
    expect(
      find.text("Couldn't unlock this document. Try again."),
      findsOneWidget,
    );
    expect(find.textContaining('sensitive'), findsNothing);
    expect(container.read(unlockSessionProvider), isEmpty);
  });

  testWidgets('automatic expiry removes visible content and allows re-unlock', (
    tester,
  ) async {
    final api = _Api();
    final container = await show(tester, api);
    await submit(tester);
    final expiry = DateTime.now().add(const Duration(minutes: 15));
    api.pending.complete(
      ActiveUnlock(
        documentId: 'doc',
        claimId: 'claim',
        key: 'key',
        expiresAt: expiry,
        content: 'secret',
      ),
    );
    await tester.pump();
    container.read(unlockSessionProvider.notifier).expire(expiry);
    await tester.pump();
    expect(find.text('secret'), findsNothing);
    expect(find.text('Unlock document'), findsOneWidget);
    expect(
      container.read(unlockSessionProvider.notifier).activeForChat(),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('closing the screen drops a late unlock response', (
    tester,
  ) async {
    final api = _Api();
    final container = await show(tester, api);
    await submit(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    api.pending.complete(
      ActiveUnlock(
        documentId: 'doc',
        claimId: 'claim',
        key: 'key',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        content: 'secret',
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(container.read(unlockSessionProvider), isEmpty);
  });

  testWidgets('sign-out and re-entry cannot accept an earlier unlock', (
    tester,
  ) async {
    final api = _Api();
    final container = await show(tester, api);
    await submit(tester);
    container.read(user.notifier).state = null;
    await tester.pump();
    container.read(user.notifier).state = 'user';
    await tester.pump();
    api.pending.complete(
      ActiveUnlock(
        documentId: 'doc',
        claimId: 'claim',
        key: 'key',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        content: 'secret',
      ),
    );
    await tester.pump();
    expect(container.read(unlockSessionProvider), isEmpty);
    expect(find.text('secret'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a seal finishing after navigation refreshes the owner list', (
    tester,
  ) async {
    final api = _Api()..sealPending = Completer<void>();
    final repo = FakeDocumentsRepository();
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('user'),
        sealedDocumentApiProvider.overrideWithValue(api),
        documentsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    await container.read(documentsListProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SealedDocumentControls(
              documentId: 'doc',
              status: DocumentStatus.ready,
            ),
          ),
        ),
      ),
    );
    await submit(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    api.sealPending!.complete();
    await tester.pump();
    await container.read(documentsListProvider.future);
    expect(repo.listCalls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual lock wins over an older pending unlock', (tester) async {
    final api = _Api();
    final container = await show(tester, api);
    await submit(tester);
    final session = container.read(unlockSessionProvider.notifier);
    final unlock = ActiveUnlock(
      documentId: 'doc',
      claimId: 'newer-claim',
      key: 'key',
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      content: 'secret',
    );
    // Another open detail screen completed a newer unlock while this request
    // was pending. The owner then explicitly locked the document.
    session.remember(unlock);
    await tester.pump();
    await tester.tap(find.byKey(const Key('sealed_lock')));
    await tester.pump();
    api.pending.complete(unlock);
    await tester.pump();
    expect(container.read(unlockSessionProvider), isEmpty);
    expect(find.text('secret'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final status in [
    DocumentStatus.processing,
    DocumentStatus.failed,
    DocumentStatus.unknown,
  ]) {
    testWidgets('$status cannot offer sealing or unlocking', (tester) async {
      final api = _Api();
      await show(tester, api, status: status);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(api.unlockCalls + api.sealCalls, 0);
    });
  }

  testWidgets('empty input and keyboard submit cannot start a request', (
    tester,
  ) async {
    final api = _Api();
    await show(tester, api);
    await tester.tap(find.byKey(const Key('sealed_open_prompt')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('sealed_confirm')))
          .onPressed,
      isNull,
    );
    tester.widget<TextField>(find.byType(TextField)).onSubmitted!('');
    await tester.pump();
    expect(api.unlockCalls, 0);
  });

  testWidgets('keyboard submit suppresses duplicates and clears password', (
    tester,
  ) async {
    final api = _Api();
    await show(tester, api);
    await tester.tap(find.byKey(const Key('sealed_open_prompt')));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'password');
    final field = tester.widget<TextField>(find.byType(TextField));
    field.onSubmitted!('password');
    field.onSubmitted!('password');
    await tester.pump();
    expect(api.unlockCalls, 1);
    expect(field.controller!.text, isEmpty);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .onPressed,
      isNull,
    );
    api.pending.completeError(StateError('test failure'));
    await tester.pump();
  });

  testWidgets('cancel clears password and error; retry needs fresh input', (
    tester,
  ) async {
    final api = _Api();
    await show(tester, api);
    await submit(tester);
    api.pending.completeError(StateError('sensitive error'));
    await tester.pump();
    expect(find.byKey(const Key('sealed_error')), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'do not retain');
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sealed_open_prompt')));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.byKey(const Key('sealed_error')), findsNothing);
    api.pending = Completer<ActiveUnlock>();
    await tester.enterText(find.byType(TextField), 'new password');
    await tester.pump();
    await tester.tap(find.byKey(const Key('sealed_confirm')));
    await tester.pump();
    expect(api.unlockCalls, 2);
    expect(api.password, 'new password');
    api.pending.complete(
      ActiveUnlock(
        documentId: 'doc',
        claimId: 'claim',
        key: 'key',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        content: 'retried',
      ),
    );
    await tester.pump();
    expect(find.text('retried'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sealed_lock')));
    await tester.pump();
  });

  testWidgets('changing document drops late unlock and clears prompt', (
    tester,
  ) async {
    final api = _Api();
    final container = await show(tester, api);
    await submit(tester);
    await show(tester, api, documentId: 'other', container: container);
    expect(find.byType(TextField), findsNothing);
    api.pending.complete(
      ActiveUnlock(
        documentId: 'doc',
        claimId: 'claim',
        key: 'key',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        content: 'old secret',
      ),
    );
    await tester.pump();
    expect(container.read(unlockSessionProvider), isEmpty);
    expect(find.text('old secret'), findsNothing);
    api.pending = Completer<ActiveUnlock>();
    await submit(tester);
    expect(api.documentId, 'other');
    api.pending.completeError(StateError('test failure'));
    await tester.pump();
  });

  testWidgets('seal success refreshes owner list and never creates unlock', (
    tester,
  ) async {
    final api = _Api()..sealPending = Completer<void>();
    final container = await show(tester, api, status: DocumentStatus.ready);
    await container.read(documentsListProvider.future);
    final repo =
        container.read(documentsRepositoryProvider) as FakeDocumentsRepository;
    expect(find.text('Seal document'), findsOneWidget);
    await submit(tester);
    expect(api.sealCalls, 1);
    expect(api.password, '  password  ');
    api.sealPending!.complete();
    await tester.pump();
    await container.read(documentsListProvider.future);
    expect(repo.listCalls, 2);
    expect(find.byType(TextField), findsNothing);
    expect(container.read(unlockSessionProvider), isEmpty);
  });

  testWidgets(
    'seal failure is generic, keeps retry and leaves list unchanged',
    (tester) async {
      final api = _Api()..sealPending = Completer<void>();
      final container = await show(tester, api, status: DocumentStatus.ready);
      await container.read(documentsListProvider.future);
      final repo =
          container.read(documentsRepositoryProvider)
              as FakeDocumentsRepository;
      await submit(tester);
      api.sealPending!.completeError(StateError('sensitive ciphertext'));
      await tester.pump();
      expect(
        find.text("Couldn't seal this document. Try again."),
        findsOneWidget,
      );
      expect(find.textContaining('ciphertext'), findsNothing);
      expect(repo.listCalls, 1);
      expect(container.read(unlockSessionProvider), isEmpty);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets('seal finishing under another account cannot refresh its list', (
    tester,
  ) async {
    final api = _Api()..sealPending = Completer<void>();
    final container = await show(tester, api, status: DocumentStatus.ready);
    await container.read(documentsListProvider.future);
    await submit(tester);
    container.read(user.notifier).state = 'other-user';
    await tester.pump();
    await container.read(documentsListProvider.future);
    final repo =
        container.read(documentsRepositoryProvider) as FakeDocumentsRepository;
    final callsBeforeCompletion = repo.listCalls;
    api.sealPending!.complete();
    await tester.pump();
    await container.read(documentsListProvider.future);
    expect(repo.listCalls, callsBeforeCompletion);
    expect(find.byKey(const Key('sealed_error')), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('expired unlock result never exposes content', (tester) async {
    final api = _Api();
    final container = await show(tester, api);
    await submit(tester);
    api.pending.complete(
      ActiveUnlock(
        documentId: 'doc',
        claimId: 'claim',
        key: 'key',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
        content: 'expired secret',
      ),
    );
    await tester.pump();
    expect(container.read(unlockSessionProvider), isEmpty);
    expect(find.text('expired secret'), findsNothing);
    expect(
      find.text("Couldn't unlock this document. Try again."),
      findsOneWidget,
    );
  });

  testWidgets('after expiry fresh unlock displays only fresh claim content', (
    tester,
  ) async {
    final api = _Api();
    final container = await show(tester, api);
    final expiry = DateTime.now().add(const Duration(minutes: 15));
    container
        .read(unlockSessionProvider.notifier)
        .remember(
          ActiveUnlock(
            documentId: 'doc',
            claimId: 'old',
            key: 'old',
            expiresAt: expiry,
            content: 'old secret',
          ),
        );
    await tester.pump();
    container.read(unlockSessionProvider.notifier).expire(expiry);
    await tester.pump();
    await submit(tester);
    api.pending.complete(
      ActiveUnlock(
        documentId: 'doc',
        claimId: 'fresh',
        key: 'fresh',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        content: 'fresh secret',
      ),
    );
    await tester.pump();
    expect(find.text('old secret'), findsNothing);
    expect(find.text('fresh secret'), findsOneWidget);
    expect(container.read(unlockSessionProvider)['doc']!.claimId, 'fresh');
    await tester.tap(find.byKey(const Key('sealed_lock')));
    await tester.pump();
  });

  testWidgets(
    'unlocked content survives route navigation in the same session',
    (tester) async {
      final api = _Api();
      final container = await show(tester, api);
      container
          .read(unlockSessionProvider.notifier)
          .remember(
            ActiveUnlock(
              documentId: 'doc',
              claimId: 'claim',
              key: 'key',
              expiresAt: DateTime.now().add(const Duration(minutes: 15)),
              content: 'memory only',
            ),
          );
      await tester.pump();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SizedBox()),
        ),
      );
      expect(
        container.read(unlockSessionProvider)['doc']!.content,
        'memory only',
      );
      await show(tester, api, container: container);
      expect(find.text('memory only'), findsOneWidget);
      expect(api.unlockCalls, 0);
      await tester.tap(find.byKey(const Key('sealed_lock')));
      await tester.pump();
    },
  );

  testWidgets('password entry disables keyboard learning and suggestions', (
    tester,
  ) async {
    await show(tester, _Api());
    await tester.tap(find.byKey(const Key('sealed_open_prompt')));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
  });

  testWidgets('signed-out keyboard submission cannot call API', (tester) async {
    final api = _Api();
    final container = await show(tester, api);
    container.read(user.notifier).state = null;
    await tester.pump();
    await tester.tap(find.byKey(const Key('sealed_open_prompt')));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'password');
    tester.widget<TextField>(find.byType(TextField)).onSubmitted!('password');
    await tester.pump();
    expect(api.unlockCalls + api.sealCalls, 0);
    expect(container.read(unlockSessionProvider), isEmpty);
  });
}
