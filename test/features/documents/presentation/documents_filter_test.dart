import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/documents/presentation/document_presentation.dart';
import 'package:cerebro_mobile/features/documents/presentation/documents_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_documents_repository.dart';

DocumentSummary _doc(
  String title,
  DocumentStatus status, {
  int size = 100,
  Duration age = const Duration(days: 2),
}) => DocumentSummary(
  id: title,
  title: title,
  mime: 'text/plain',
  sizeBytes: size,
  originalSizeBytes: size,
  status: status,
  createdAt: DateTime.now().subtract(age),
);

void main() {
  final now = DateTime.now();
  final docs = [
    _doc('Alpha report', DocumentStatus.ready),
    _doc('beta notes', DocumentStatus.processing),
    _doc('Gamma scan', DocumentStatus.failed),
    _doc('Delta vault', DocumentStatus.sealed),
    // An upload killed half-way: "processing" on the server, but really failed.
    _doc(
      'Epsilon draft',
      DocumentStatus.processing,
      size: 0,
      age: const Duration(minutes: 40),
    ),
  ];

  List<String> titles(DocumentFilter f, {String q = ''}) => [
    for (final d in filterDocuments(docs, query: q, filter: f, now: now))
      d.title,
  ];

  group('filterDocuments', () {
    test('All with no query returns everything', () {
      expect(titles(DocumentFilter.all), hasLength(5));
    });

    test('each status chip keeps only its own documents', () {
      expect(titles(DocumentFilter.ready), ['Alpha report']);
      expect(titles(DocumentFilter.processing), ['beta notes']);
      expect(titles(DocumentFilter.sealed), ['Delta vault']);
    });

    test('Failed includes an abandoned upload; Processing does not', () {
      expect(titles(DocumentFilter.failed), ['Gamma scan', 'Epsilon draft']);
      expect(
        titles(DocumentFilter.processing),
        isNot(contains('Epsilon draft')),
      );
    });

    test('search is case-insensitive, trimmed, and combines with a chip', () {
      expect(titles(DocumentFilter.all, q: '  ALPHA '), ['Alpha report']);
      expect(titles(DocumentFilter.all, q: 'NOTES'), ['beta notes']);
      expect(titles(DocumentFilter.ready, q: 'beta'), isEmpty);
    });
  });

  group('Documents screen', () {
    Widget app(List<DocumentSummary> list) => ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        documentsRepositoryProvider.overrideWithValue(
          FakeDocumentsRepository(documents: list),
        ),
      ],
      child: MaterialApp(theme: AppTheme.dark, home: const DocumentsScreen()),
    );

    Future<void> pump(WidgetTester tester, List<DocumentSummary> list) async {
      await tester.pumpWidget(app(list));
      await tester.pumpAndSettle();
    }

    testWidgets('shows a count, a search box and the status chips', (
      tester,
    ) async {
      await pump(tester, docs);
      expect(find.text('5 documents'), findsOneWidget);
      expect(find.byKey(const Key('documents_search')), findsOneWidget);
      for (final f in DocumentFilter.values) {
        expect(find.byKey(Key('documents_filter_${f.name}')), findsOneWidget);
      }
    });

    testWidgets('a single document reads "1 document"', (tester) async {
      await pump(tester, [_doc('only.txt', DocumentStatus.ready)]);
      expect(find.text('1 document'), findsOneWidget);
    });

    testWidgets('typing narrows the list; a chip narrows it further', (
      tester,
    ) async {
      await pump(tester, docs);
      await tester.enterText(find.byKey(const Key('documents_search')), 'ta');
      await tester.pump();
      // "ta" is in beta and Delta only.
      expect(find.byKey(const Key('document_row_beta notes')), findsOneWidget);
      expect(find.byKey(const Key('document_row_Delta vault')), findsOneWidget);
      expect(find.byKey(const Key('document_row_Epsilon draft')), findsNothing);
      expect(find.byKey(const Key('document_row_Alpha report')), findsNothing);

      await tester.tap(find.byKey(const Key('documents_filter_sealed')));
      await tester.pump();
      expect(find.byKey(const Key('document_row_Delta vault')), findsOneWidget);
      expect(find.byKey(const Key('document_row_beta notes')), findsNothing);
    });

    testWidgets('no match shows a message, and Clear filters restores all', (
      tester,
    ) async {
      await pump(tester, docs);
      await tester.enterText(find.byKey(const Key('documents_search')), 'zzz');
      await tester.pump();
      expect(find.byKey(const Key('documents_no_match')), findsOneWidget);
      expect(find.byKey(const Key('documents_list')), findsNothing);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('documents_no_match')), findsNothing);
      expect(find.byKey(const Key('documents_list')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('documents_search')))
            .controller!
            .text,
        isEmpty,
      );
    });

    testWidgets('Clear filters also resets the status chip', (tester) async {
      await pump(tester, docs);
      await tester.tap(find.byKey(const Key('documents_filter_sealed')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('documents_search')),
        'Alpha',
      );
      await tester.pump();
      expect(find.byKey(const Key('documents_no_match')), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('document_row_Alpha report')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('documents_filter_all')))
            .selected,
        isTrue,
      );
    });

    testWidgets('the clear (x) button empties the search', (tester) async {
      await pump(tester, docs);
      await tester.enterText(find.byKey(const Key('documents_search')), 'beta');
      await tester.pump();
      expect(find.byKey(const Key('document_row_Alpha report')), findsNothing);
      await tester.tap(find.byKey(const Key('documents_search_clear')));
      await tester.pump();
      expect(
        find.byKey(const Key('document_row_Alpha report')),
        findsOneWidget,
      );
    });

    testWidgets('an empty account has no search or chips, only the CTA', (
      tester,
    ) async {
      await pump(tester, const []);
      expect(find.byKey(const Key('documents_empty')), findsOneWidget);
      expect(find.byKey(const Key('documents_search')), findsNothing);
      expect(find.byKey(const Key('documents_filters')), findsNothing);
      expect(find.text('Add a document'), findsOneWidget);
    });

    testWidgets('the empty-state button opens the same source sheet', (
      tester,
    ) async {
      await pump(tester, const []);
      await tester.tap(find.text('Add a document'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('upload_source_file')), findsOneWidget);
    });

    testWidgets('while loading it shows skeleton rows, not a spinner', (
      tester,
    ) async {
      await tester.pumpWidget(app(docs));
      expect(find.byKey(const Key('documents_loading')), findsOneWidget);
      expect(find.byKey(const Key('app_skeleton')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('each row is at least a touch target tall', (tester) async {
      await pump(tester, [_doc('x.txt', DocumentStatus.ready)]);
      expect(
        tester.getSize(find.byKey(const Key('document_row_x.txt'))).height,
        greaterThanOrEqualTo(44),
      );
    });
  });
}
