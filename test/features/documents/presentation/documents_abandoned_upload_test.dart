// Phase 2 Gate: after the app is killed mid-upload, the half-created document
// must not sit in the list looking like it is processing.
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/documents/presentation/documents_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_documents_repository.dart';

DocumentSummary _doc(
  String title, {
  required DocumentStatus status,
  required int sizeBytes,
  required Duration age,
}) => DocumentSummary(
  id: 'id-$title',
  title: title,
  mime: 'text/plain',
  sizeBytes: sizeBytes,
  originalSizeBytes: sizeBytes,
  status: status,
  createdAt: DateTime.now().subtract(age),
);

Future<void> _pump(WidgetTester tester, List<DocumentSummary> docs) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        documentsRepositoryProvider.overrideWithValue(
          FakeDocumentsRepository(documents: docs),
        ),
      ],
      child: MaterialApp(theme: AppTheme.dark, home: const DocumentsScreen()),
    ),
  );
  // Bounded: a processing row keeps the list polling on a timer.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets(
    'a document whose upload never finished reads Incomplete, not Processing',
    (tester) async {
      await _pump(tester, [
        _doc(
          'killed-mid-upload.txt',
          status: DocumentStatus.processing,
          sizeBytes: 0,
          age: const Duration(minutes: 40),
        ),
      ]);

      expect(find.text('Incomplete'), findsOneWidget);
      expect(find.text('Processing'), findsNothing);
    },
  );

  testWidgets('a genuinely processing document still reads Processing', (
    tester,
  ) async {
    await _pump(tester, [
      _doc(
        'indexing.txt',
        status: DocumentStatus.processing,
        sizeBytes: 2048,
        age: const Duration(minutes: 40),
      ),
      _doc(
        'just-started.txt',
        status: DocumentStatus.processing,
        sizeBytes: 0,
        age: const Duration(seconds: 20),
      ),
    ]);

    expect(find.text('Processing'), findsNWidgets(2));
    expect(find.text('Incomplete'), findsNothing);
  });
}
