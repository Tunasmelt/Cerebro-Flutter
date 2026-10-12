import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/sealed/data/sealed_document_api.dart';
import 'package:cerebro_mobile/features/sealed/data/unlock_session.dart';
import 'package:cerebro_mobile/features/sealed/presentation/sealed_document_controls.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:cerebro_mobile/shared/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../documents/fake_documents_repository.dart';

class _Api implements SealedDocumentApi {
  Object? failWith;
  @override
  Future<void> seal(String documentId, String passphrase) async {
    if (failWith != null) throw failWith!;
  }

  @override
  Future<ActiveUnlock> unlock(String documentId, String passphrase) async {
    if (failWith != null) throw failWith!;
    return ActiveUnlock(
      documentId: documentId,
      claimId: 'claim',
      key: 'key',
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      content: 'the secret text',
    );
  }
}

void main() {
  late _Api api;

  Future<ProviderContainer> show(
    WidgetTester tester, {
    DocumentStatus status = DocumentStatus.sealed,
  }) async {
    api = _Api();
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('user'),
        sealedDocumentApiProvider.overrideWithValue(api),
        documentsRepositoryProvider.overrideWithValue(
          FakeDocumentsRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SealedDocumentControls(documentId: 'doc', status: status),
            ),
          ),
        ),
      ),
    );
    return container;
  }

  Future<void> openPrompt(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('sealed_open_prompt')));
    await tester.pump();
  }

  TextField passphrase(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(const Key('sealed_passphrase')));

  testWidgets('a sealed document sits in an amber lock card', (tester) async {
    await show(tester);
    expect(find.text('Sealed'), findsOneWidget);
    expect(find.text('Unlock document'), findsOneWidget);

    final card = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.color == AppColors.accentLockedSubtle);
    expect(card, isNotEmpty);
  });

  testWidgets('a ready document is offered sealing, with its own heading', (
    tester,
  ) async {
    await show(tester, status: DocumentStatus.ready);
    expect(find.text('Seal this document'), findsOneWidget);
    expect(find.text('Seal document'), findsOneWidget);
  });

  testWidgets('the passphrase starts hidden and can be revealed, then hidden', (
    tester,
  ) async {
    await show(tester);
    await openPrompt(tester);
    expect(passphrase(tester).obscureText, isTrue);

    await tester.tap(find.byKey(const Key('sealed_reveal')));
    await tester.pump();
    expect(passphrase(tester).obscureText, isFalse);

    await tester.tap(find.byKey(const Key('sealed_reveal')));
    await tester.pump();
    expect(passphrase(tester).obscureText, isTrue);
  });

  testWidgets('Cancel closes the prompt and the next one starts hidden', (
    tester,
  ) async {
    await show(tester);
    await openPrompt(tester);
    await tester.tap(find.byKey(const Key('sealed_reveal')));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.byKey(const Key('sealed_passphrase')), findsNothing);

    await openPrompt(tester);
    expect(passphrase(tester).obscureText, isTrue);
  });

  testWidgets('every button is at least a 44px touch target', (tester) async {
    await show(tester);
    expect(
      tester.getSize(find.byKey(const Key('sealed_open_prompt'))).height,
      greaterThanOrEqualTo(44),
    );
    await openPrompt(tester);
    await tester.enterText(find.byKey(const Key('sealed_passphrase')), 'pw');
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const Key('sealed_confirm'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Cancel')).height,
      greaterThanOrEqualTo(44),
    );

    await tester.tap(find.byKey(const Key('sealed_confirm')));
    await tester.pump();
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const Key('sealed_lock'))).height,
      greaterThanOrEqualTo(44),
    );
    // Locking ends the unlock session and its countdown timer.
    await tester.tap(find.byKey(const Key('sealed_lock')));
    await tester.pump();
  });

  testWidgets('unlocking shows the amber countdown and the content', (
    tester,
  ) async {
    await show(tester);
    await openPrompt(tester);
    await tester.enterText(find.byKey(const Key('sealed_passphrase')), 'pw');
    await tester.pump();
    await tester.tap(find.byKey(const Key('sealed_confirm')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Unlocked'), findsOneWidget);
    expect(find.text('the secret text'), findsOneWidget);
    final countdown = tester.widget<Text>(
      find.byKey(const Key('sealed_countdown')),
    );
    expect(countdown.style?.color, AppColors.accentLocked);
    expect(countdown.data, startsWith('Unlocked · '));
    await tester.tap(find.byKey(const Key('sealed_lock')));
    await tester.pump();
  });

  testWidgets('a failure is shown in a live region, with no detail leaked', (
    tester,
  ) async {
    await show(tester);
    api.failWith = StateError('server said: wrong key abc123');
    await openPrompt(tester);
    await tester.enterText(find.byKey(const Key('sealed_passphrase')), 'pw');
    await tester.pump();
    await tester.tap(find.byKey(const Key('sealed_confirm')));
    await tester.pump();
    await tester.pump();

    expect(
      find.text("Couldn't unlock this document. Try again."),
      findsOneWidget,
    );
    expect(find.textContaining('abc123'), findsNothing);
    final semantics = tester.getSemantics(
      find.byKey(const Key('sealed_error')),
    );
    expect(semantics.flagsCollection.isLiveRegion, isTrue);
  });

  testWidgets('a document that is neither ready nor sealed shows nothing', (
    tester,
  ) async {
    await show(tester, status: DocumentStatus.processing);
    expect(find.byKey(const Key('sealed_open_prompt')), findsNothing);
    expect(find.text('Sealed'), findsNothing);
  });
}
