// What the user sees as a document's ingest advances: the stage label
// moves through the real states, a progress bar shows only while work is
// in flight, and a failure is stated plainly with the backend's reason —
// not a stuck spinner.
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/documents/data/ingest_polling.dart';
import 'package:cerebro_mobile/features/documents/presentation/document_detail_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../scripted_documents_repository.dart';

const _interval = Duration(milliseconds: 100);

Future<void> _pumpScreen(
  WidgetTester tester,
  ScriptedDocumentsRepository repo, {
  Duration limit = const Duration(minutes: 10),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        documentsRepositoryProvider.overrideWithValue(repo),
        ingestPollIntervalProvider.overrideWithValue(_interval),
        ingestPollLimitProvider.overrideWithValue(limit),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const DocumentDetailScreen(documentId: 'doc-1'),
      ),
    ),
  );
  // Bounded: an in-flight progress bar animates forever.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

String _stage(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('document_detail_stage'))).data!;

void main() {
  testWidgets('the stage label advances through the real states to Ready', (
    tester,
  ) async {
    final repo = ScriptedDocumentsRepository(
      details: [
        detailAt('normalizing'),
        detailAt('extracting'),
        detailAt('embedding'),
        detailAt('ready', status: DocumentStatus.ready),
      ],
    );
    await _pumpScreen(tester, repo);

    final seen = <String>[_stage(tester)];
    expect(find.byKey(const Key('document_detail_progress')), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.pump(_interval);
      await tester.pump(const Duration(milliseconds: 20));
      seen.add(_stage(tester));
    }

    expect(seen, ['Preparing file', 'Reading text', 'Indexing', 'Ready']);
    expect(
      find.byKey(const Key('document_detail_progress')),
      findsNothing,
      reason: 'no bar once there is nothing left to wait for',
    );
    expect(find.byKey(const Key('document_detail_last_error')), findsNothing);
  });

  testWidgets('a corrupt PDF shows the failure and the reason, no spinner', (
    tester,
  ) async {
    final repo = ScriptedDocumentsRepository(
      details: [
        detailAt('extracting'),
        detailAt(
          'failed',
          status: DocumentStatus.failed,
          lastError: 'corrupt_pdf',
        ),
      ],
    );
    await _pumpScreen(tester, repo);
    await tester.pump(_interval);
    await tester.pumpAndSettle();

    expect(_stage(tester), 'Failed');
    expect(
      find.text("This PDF looks damaged and couldn't be read."),
      findsOneWidget,
    );
    expect(find.byKey(const Key('document_detail_progress')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('an unfamiliar failure code is still shown, with the code', (
    tester,
  ) async {
    final repo = ScriptedDocumentsRepository(
      details: [
        detailAt(
          'failed',
          status: DocumentStatus.failed,
          lastError: 'quota_exceeded',
        ),
      ],
    );
    await _pumpScreen(tester, repo);
    await tester.pumpAndSettle();

    expect(
      find.text("This document couldn't be processed (quota_exceeded)."),
      findsOneWidget,
    );
  });

  testWidgets('an unknown stage reads as Processing with an indeterminate bar', (
    tester,
  ) async {
    final repo = ScriptedDocumentsRepository(details: [detailAt('archiving')]);
    await _pumpScreen(tester, repo);

    expect(_stage(tester), 'Processing');
    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('document_detail_progress')),
    );
    expect(bar.value, isNull);
  });

  testWidgets('the bar fills further as the stage advances', (tester) async {
    final repo = ScriptedDocumentsRepository(
      details: [detailAt('normalizing'), detailAt('embedding')],
    );
    await _pumpScreen(tester, repo);
    double barValue() => tester
        .widget<LinearProgressIndicator>(
          find.byKey(const Key('document_detail_progress')),
        )
        .value!;

    final before = barValue();
    await tester.pump(_interval);
    await tester.pump(const Duration(milliseconds: 20));

    expect(barValue(), greaterThan(before));
  });

  testWidgets(
    'after the poll window it says it is taking long, drops the bar, and '
    '"Check again" polls afresh',
    (tester) async {
      final repo = ScriptedDocumentsRepository(details: [detailAt('embedding')]);
      // 300ms window at 100ms = 3 polls.
      await _pumpScreen(tester, repo, limit: const Duration(milliseconds: 300));
      expect(find.byKey(const Key('document_detail_stalled')), findsNothing);

      for (var i = 0; i < 4; i++) {
        await tester.pump(_interval);
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(find.byKey(const Key('document_detail_stalled')), findsOneWidget);
      expect(find.textContaining('taking longer than usual'), findsOneWidget);
      expect(
        find.byKey(const Key('document_detail_progress')),
        findsNothing,
        reason: 'nothing is polling, so no bar implying live progress',
      );
      final callsBefore = repo.detailCalls;

      await tester.tap(find.byKey(const Key('document_detail_check_again')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(repo.detailCalls, greaterThan(callsBefore));
      expect(find.byKey(const Key('document_detail_stalled')), findsNothing);
      expect(find.byKey(const Key('document_detail_progress')), findsOneWidget);
    },
  );
}
