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

    test('Ready and Sealed each keep only their own documents', () {
      expect(titles(DocumentFilter.ready), ['Alpha report']);
      expect(titles(DocumentFilter.sealed), ['Delta vault']);
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

    Future<void> openSearch(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('documents_search_toggle')));
      await tester.pump();
    }

    testWidgets('shows a count, a search icon, and only Ready and Sealed', (
      tester,
    ) async {
      await pump(tester, docs);
      expect(find.text('5 documents'), findsOneWidget);
      expect(find.byKey(const Key('documents_search_toggle')), findsOneWidget);
      // The search bar is hidden until the icon is tapped.
      expect(find.byKey(const Key('documents_search')), findsNothing);
      expect(find.byKey(const Key('documents_filter_ready')), findsOneWidget);
      expect(find.byKey(const Key('documents_filter_sealed')), findsOneWidget);
      expect(find.byKey(const Key('documents_filter_all')), findsNothing);
      expect(find.byType(ChoiceChip), findsNWidgets(2));
    });

    testWidgets('a single document reads "1 document"', (tester) async {
      await pump(tester, [_doc('only.txt', DocumentStatus.ready)]);
      expect(find.text('1 document'), findsOneWidget);
    });

    testWidgets('the icon opens the search bar and closing it clears it', (
      tester,
    ) async {
      await pump(tester, docs);
      await openSearch(tester);
      expect(find.byKey(const Key('documents_search')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('documents_search')), 'beta');
      await tester.pump();
      expect(find.byKey(const Key('document_row_Alpha report')), findsNothing);

      await openSearch(tester); // the same button now closes
      expect(find.byKey(const Key('documents_search')), findsNothing);
      expect(
        find.byKey(const Key('document_row_Alpha report')),
        findsOneWidget,
      );
    });

    testWidgets('typing narrows the list; a chip narrows it further', (
      tester,
    ) async {
      await pump(tester, docs);
      await openSearch(tester);
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

    testWidgets('tapping the selected chip again shows everything', (
      tester,
    ) async {
      await pump(tester, docs);
      await tester.tap(find.byKey(const Key('documents_filter_ready')));
      await tester.pump();
      expect(find.byKey(const Key('document_row_Delta vault')), findsNothing);

      await tester.tap(find.byKey(const Key('documents_filter_ready')));
      await tester.pump();
      expect(find.byKey(const Key('document_row_Delta vault')), findsOneWidget);
      expect(find.byKey(const Key('document_row_Gamma scan')), findsOneWidget);
    });

    testWidgets('no match shows a message, and Clear filters restores all', (
      tester,
    ) async {
      await pump(tester, docs);
      await openSearch(tester);
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

    testWidgets('Clear filters also resets the chip', (tester) async {
      await pump(tester, docs);
      await tester.tap(find.byKey(const Key('documents_filter_sealed')));
      await tester.pump();
      await openSearch(tester);
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
      for (final chip in tester.widgetList<ChoiceChip>(
        find.byType(ChoiceChip),
      )) {
        expect(chip.selected, isFalse);
      }
    });

    testWidgets('an empty account has no search or chips, only the CTA', (
      tester,
    ) async {
      await pump(tester, const []);
      expect(find.byKey(const Key('documents_empty')), findsOneWidget);
      expect(find.byKey(const Key('documents_search_toggle')), findsNothing);
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
