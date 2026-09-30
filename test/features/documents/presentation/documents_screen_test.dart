import 'package:cerebro_mobile/core/network/app_exception.dart';
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
      overrides: [documentsRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(theme: AppTheme.dark, home: const DocumentsScreen()),
    );
  }

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
    await tester.pumpWidget(buildApp(FakeDocumentsRepository(documents: [doc])));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('document_row_doc-1')), findsOneWidget);
    expect(find.text('notes.txt'), findsOneWidget);
    expect(find.textContaining('2.0kb'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
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
