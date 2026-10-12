import 'package:cerebro_mobile/shared/widgets/status_pill.dart';
import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/documents/presentation/documents_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_documents_repository.dart';

void main() {
  Widget buildApp(FakeDocumentsRepository repo) {
    return ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        documentsRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(theme: AppTheme.dark, home: const DocumentsScreen()),
    );
  }

  testWidgets('resuming fetches completed ingest after backgrounding', (
    tester,
  ) async {
    final documents = <DocumentSummary>[
      DocumentSummary(
        id: 'background-doc',
        title: 'background.txt',
        mime: 'text/plain',
        sizeBytes: 10,
        originalSizeBytes: 10,
        status: DocumentStatus.processing,
        createdAt: DateTime.now(),
      ),
    ];
    final repo = FakeDocumentsRepository(documents: documents);
    await tester.pumpWidget(buildApp(repo));
    await tester.pump();
    expect(repo.listCalls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    documents[0] = documents[0].copyWith(status: DocumentStatus.ready);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.listCalls, 2);
    expect(
      find.descendant(
        of: find.byType(StatusPill),
        matching: find.text('Ready'),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disposed Documents does not fetch when app resumes', (
    tester,
  ) async {
    final repo = FakeDocumentsRepository();
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpWidget(const SizedBox());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.listCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the empty state when the user has no documents', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(FakeDocumentsRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('documents_empty')), findsOneWidget);
    expect(find.text('No documents yet.'), findsOneWidget);
  });

  testWidgets('renders a document with its title, size, date, and status', (
    tester,
  ) async {
    final doc = DocumentSummary(
      id: 'doc-1',
      title: 'notes.txt',
      mime: 'text/plain',
      sizeBytes: 2048,
      originalSizeBytes: 2048,
      status: DocumentStatus.ready,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    await tester.pumpWidget(
      buildApp(FakeDocumentsRepository(documents: [doc])),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('document_row_doc-1')), findsOneWidget);
    expect(find.text('notes.txt'), findsOneWidget);
    expect(find.textContaining('2.0kb'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(StatusPill),
        matching: find.text('Ready'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows the shared ErrorView, not a raw exception, on failure', (
    tester,
  ) async {
    final repo = FakeDocumentsRepository()
      ..nextListError = const NetworkUnreachableException();
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('documents_error')), findsOneWidget);
    expect(
      find.text("Can't reach Cerebro. Check your connection."),
      findsOneWidget,
    );
  });

  testWidgets('Retry on the error state re-calls the repository', (
    tester,
  ) async {
    final repo = FakeDocumentsRepository()
      ..nextListError = const NetworkUnreachableException();
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();
    expect(repo.listCalls, 1);

    repo.nextListError = null;
    await tester.tap(find.byKey(const Key('error_view_retry')));
    await tester.pumpAndSettle();

    expect(repo.listCalls, 2);
    expect(find.byKey(const Key('documents_empty')), findsOneWidget);
  });
}
