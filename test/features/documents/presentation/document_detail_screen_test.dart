import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/documents/presentation/document_detail_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_documents_repository.dart';

void main() {
  final doc = DocumentSummary(
    id: 'doc-1',
    title: 'notes.txt',
    mime: 'text/plain',
    sizeBytes: 42,
    originalSizeBytes: 42,
    status: DocumentStatus.failed,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  Widget buildApp(FakeDocumentsRepository repo, {String id = 'doc-1'}) {
    return ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        documentsRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: DocumentDetailScreen(documentId: id),
      ),
    );
  }

  testWidgets('renders the document title, status, and size', (tester) async {
    await tester.pumpWidget(buildApp(FakeDocumentsRepository(documents: [doc])));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('document_detail_body')), findsOneWidget);
    expect(find.text('notes.txt'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
  });

  testWidgets('shows the ErrorView on a load failure, not a raw exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(FakeDocumentsRepository(), id: 'missing'),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('document_detail_error')), findsOneWidget);
  });
}
