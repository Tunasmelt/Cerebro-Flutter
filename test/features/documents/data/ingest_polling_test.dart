// Polling behavior: the detail provider and the list notifier keep
// re-reading while ingest is in progress, stop when it settles, survive a
// blip, and never poll forever. Intervals are shrunk to milliseconds.

import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/document_detail_provider.dart';
import 'package:cerebro_mobile/features/documents/data/documents_list_notifier.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/documents/data/ingest_polling.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../scripted_documents_repository.dart';

const _tick = Duration(milliseconds: 10);

Future<void> _settle([int ticks = 12]) => Future<void>.delayed(_tick * ticks);

ProviderContainer _container(
  ScriptedDocumentsRepository repo, {
  Duration limit = const Duration(minutes: 10),
}) {
  final container = ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWithValue('user-1'),
      documentsRepositoryProvider.overrideWithValue(repo),
      ingestPollIntervalProvider.overrideWithValue(_tick),
      ingestPollLimitProvider.overrideWithValue(limit),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('detail provider', () {
    test('walks through every real stage and stops at ready', () async {
      final repo = ScriptedDocumentsRepository(
        details: [
          detailAt('normalizing'),
          detailAt('extracting'),
          detailAt('embedding'),
          detailAt('ready', status: DocumentStatus.ready),
        ],
      );
      final container = _container(repo);
      final seen = <String?>[];
      container.listen(
        documentDetailProvider('doc-1'),
        (_, next) => next.whenData((d) => seen.add(d.ingestState)),
        fireImmediately: true,
      );

      await _settle();

      expect(seen, ['normalizing', 'extracting', 'embedding', 'ready']);
      expect(repo.detailCalls, 4, reason: 'no polling after ready');
    });

    test('stops at failed and keeps last_error', () async {
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
      final container = _container(repo);
      container.listen(documentDetailProvider('doc-1'), (_, _) {});

      await _settle();

      final last = container.read(documentDetailProvider('doc-1')).requireValue;
      expect(last.ingestState, 'failed');
      expect(last.lastError, 'corrupt_pdf');
      expect(repo.detailCalls, 2);
    });

    test('a settled document is fetched once, never polled', () async {
      final repo = ScriptedDocumentsRepository(
        details: [detailAt(null, status: DocumentStatus.ready)],
      );
      final container = _container(repo);
      container.listen(documentDetailProvider('doc-1'), (_, _) {});

      await _settle();

      expect(repo.detailCalls, 1);
    });

    test(
      'an unrecognised state keeps polling until the doc status settles',
      () async {
        final repo = ScriptedDocumentsRepository(
          details: [
            detailAt('archiving'),
            detailAt('archiving'),
            detailAt('archiving', status: DocumentStatus.ready),
          ],
        );
        final container = _container(repo);
        container.listen(documentDetailProvider('doc-1'), (_, _) {});

        await _settle();

        expect(repo.detailCalls, 3);
      },
    );

    test('a failure on the first fetch is the error, with no polling', () async {
      final repo = ScriptedDocumentsRepository(
        details: [const NetworkUnreachableException()],
      );
      final container = _container(repo);
      container.listen(documentDetailProvider('doc-1'), (_, _) {});

      await _settle();

      expect(
        container.read(documentDetailProvider('doc-1')).error,
        isA<NetworkUnreachableException>(),
      );
      expect(repo.detailCalls, 1);
    });

    test('a blip mid-ingest keeps the last known state and carries on', () async {
      final repo = ScriptedDocumentsRepository(
        details: [
          detailAt('extracting'),
          const NetworkUnreachableException(),
          detailAt('ready', status: DocumentStatus.ready),
        ],
      );
      final container = _container(repo);
      final errors = <Object>[];
      container.listen(documentDetailProvider('doc-1'), (_, next) {
        if (next.hasError) errors.add(next.error!);
      });

      await _settle();

      expect(errors, isEmpty, reason: 'the blip never reached the screen');
      expect(
        container
            .read(documentDetailProvider('doc-1'))
            .requireValue
            .ingestState,
        'ready',
      );
    });

    test('gives up after the poll window instead of polling forever', () async {
      final repo = ScriptedDocumentsRepository(details: [detailAt('embedding')]);
      // 50ms window at 10ms interval = 5 polls.
      final container = _container(
        repo,
        limit: const Duration(milliseconds: 50),
      );
      container.listen(documentDetailProvider('doc-1'), (_, _) {});

      await _settle(30);

      expect(repo.detailCalls, 5);
    });

    test('says so when it gives up on a still-processing document', () async {
      final repo = ScriptedDocumentsRepository(details: [detailAt('embedding')]);
      final container = _container(
        repo,
        limit: const Duration(milliseconds: 50),
      );
      container.listen(documentDetailProvider('doc-1'), (_, _) {});
      container.listen(ingestPollGaveUpProvider('doc-1'), (_, _) {});
      await _settle(4);
      expect(container.read(ingestPollGaveUpProvider('doc-1')), isFalse);

      await _settle(30);

      expect(container.read(ingestPollGaveUpProvider('doc-1')), isTrue);
    });

    test('a settled document never reads as given up', () async {
      final repo = ScriptedDocumentsRepository(
        details: [detailAt('ready', status: DocumentStatus.ready)],
      );
      final container = _container(repo);
      container.listen(documentDetailProvider('doc-1'), (_, _) {});
      container.listen(ingestPollGaveUpProvider('doc-1'), (_, _) {});

      await _settle();

      expect(container.read(ingestPollGaveUpProvider('doc-1')), isFalse);
    });

    test('restarting polling clears the given-up flag', () async {
      final repo = ScriptedDocumentsRepository(details: [detailAt('embedding')]);
      final container = _container(
        repo,
        limit: const Duration(milliseconds: 50),
      );
      container.listen(documentDetailProvider('doc-1'), (_, _) {});
      container.listen(ingestPollGaveUpProvider('doc-1'), (_, _) {});
      await _settle(30);
      expect(container.read(ingestPollGaveUpProvider('doc-1')), isTrue);

      container.invalidate(documentDetailProvider('doc-1'));
      await _settle(2);

      expect(container.read(ingestPollGaveUpProvider('doc-1')), isFalse);
      await _settle(30);
      expect(container.read(ingestPollGaveUpProvider('doc-1')), isTrue);
    });

    test('stops polling as soon as nobody is watching', () async {
      final repo = ScriptedDocumentsRepository(details: [detailAt('embedding')]);
      final container = _container(repo);
      final sub = container.listen(documentDetailProvider('doc-1'), (_, _) {});
      await _settle(4);
      sub.close();
      await _settle(2); // let autoDispose land
      final callsWhenClosed = repo.detailCalls;

      await _settle(10);

      expect(repo.detailCalls, callsWhenClosed);
    });
  });

  group('list notifier', () {
    test('a processing row flips to ready on its own', () async {
      final repo = ScriptedDocumentsRepository(
        lists: [
          [summaryWith(DocumentStatus.processing)],
          [summaryWith(DocumentStatus.processing)],
          [summaryWith(DocumentStatus.ready)],
        ],
      );
      final container = _container(repo);
      container.listen(documentsListProvider, (_, _) {});

      await _settle();

      expect(
        container.read(documentsListProvider).requireValue.single.status,
        DocumentStatus.ready,
      );
      expect(
        repo.listCalls,
        3,
        reason: 'polling stops once nothing is processing',
      );
    });

    test('an all-ready list is fetched once, never polled', () async {
      final repo = ScriptedDocumentsRepository(
        lists: [
          [summaryWith(DocumentStatus.ready)],
        ],
      );
      final container = _container(repo);
      container.listen(documentsListProvider, (_, _) {});

      await _settle();

      expect(repo.listCalls, 1);
    });

    test('a failed poll keeps the list on screen and tries again', () async {
      final repo = ScriptedDocumentsRepository(
        lists: [
          [summaryWith(DocumentStatus.processing)],
          const NetworkUnreachableException(),
          [summaryWith(DocumentStatus.failed)],
        ],
      );
      final container = _container(repo);
      final seen = <AsyncValue<List<DocumentSummary>>>[];
      container.listen(documentsListProvider, (_, next) => seen.add(next));

      await _settle();

      expect(seen.any((v) => v.hasError), isFalse);
      expect(
        container.read(documentsListProvider).requireValue.single.status,
        DocumentStatus.failed,
      );
    });

    test('gives up after the poll window', () async {
      final repo = ScriptedDocumentsRepository(
        lists: [
          [summaryWith(DocumentStatus.processing)],
        ],
      );
      final container = _container(
        repo,
        limit: const Duration(milliseconds: 50),
      );
      container.listen(documentsListProvider, (_, _) {});

      await _settle(30);

      expect(repo.listCalls, 6, reason: '1 initial fetch + 5 polls');
    });

    test('a manual refresh starts a fresh poll window', () async {
      final repo = ScriptedDocumentsRepository(
        lists: [
          [summaryWith(DocumentStatus.processing)],
        ],
      );
      final container = _container(
        repo,
        limit: const Duration(milliseconds: 50),
      );
      container.listen(documentsListProvider, (_, _) {});
      await _settle(30);
      final before = repo.listCalls;

      await container.read(documentsListProvider.notifier).refresh();
      await _settle(30);

      expect(repo.listCalls - before, 6, reason: '1 refresh + 5 polls');
    });

    test('a disposed notifier stops its timer', () async {
      final repo = ScriptedDocumentsRepository(
        lists: [
          [summaryWith(DocumentStatus.processing)],
        ],
      );
      final container = _container(repo);
      container.listen(documentsListProvider, (_, _) {});
      await _settle(3);

      container.dispose();
      final calls = repo.listCalls;
      await _settle(10);

      expect(repo.listCalls, calls);
    });
  });
}
