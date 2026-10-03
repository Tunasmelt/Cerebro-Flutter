// Retrying a failed document's ingest: the controller, how the list and the
// detail screen follow a retried document, and the backend quirk behind
// both — a retry resets the job but leaves documents.status at `failed`
// until the job finishes.
import 'dart:async';

import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/document_detail_provider.dart';
import 'package:cerebro_mobile/features/documents/data/documents_list_notifier.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/documents/data/ingest_polling.dart';
import 'package:cerebro_mobile/features/documents/data/ingest_retry_controller.dart';
import 'package:cerebro_mobile/features/documents/data/ingest_status.dart';
import 'package:cerebro_mobile/features/documents/data/retry_ingest_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../scripted_documents_repository.dart';

const _tick = Duration(milliseconds: 10);

Future<void> _settle([int ticks = 12]) => Future<void>.delayed(_tick * ticks);

class _FakeRetryApi implements RetryIngestApi {
  final List<String> retried = [];
  Object? error;
  Completer<void>? gate;

  @override
  Future<void> retry(String documentId) async {
    retried.add(documentId);
    await gate?.future;
    final e = error;
    if (e != null) throw e;
  }
}

final _userProvider = StateProvider<String?>((_) => 'user-1');

({ProviderContainer container, _FakeRetryApi api}) _setup(
  ScriptedDocumentsRepository repo,
) {
  final api = _FakeRetryApi();
  final container = ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(_userProvider)),
      documentsRepositoryProvider.overrideWithValue(repo),
      retryIngestApiProvider.overrideWithValue(api),
      ingestPollIntervalProvider.overrideWithValue(_tick),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, api: api);
}

void main() {
  group('RetryIngestController', () {
    test(
      'asks the server once, then re-reads the document and tells the list',
      () async {
        final repo = ScriptedDocumentsRepository(
          details: [
            detailAt(
              'failed',
              status: DocumentStatus.failed,
              lastError: 'embed_call_failed',
            ),
            detailAt('embedding', status: DocumentStatus.failed),
          ],
          lists: [
            [summaryWith(DocumentStatus.failed)],
          ],
        );
        final (:container, :api) = _setup(repo);
        container.listen(documentDetailProvider('doc-1'), (_, _) {});
        container.listen(documentsListProvider, (_, _) {});
        await _settle(3);
        final detailCallsBefore = repo.detailCalls;

        await container.read(retryIngestProvider('doc-1').notifier).retry();
        await _settle(3);

        expect(api.retried, ['doc-1']);
        expect(container.read(retryIngestProvider('doc-1')).hasError, isFalse);
        expect(
          repo.detailCalls,
          greaterThan(detailCallsBefore),
          reason: 'the detail screen starts watching the job from the top',
        );
        expect(
          container.read(documentsListProvider).requireValue.single.status,
          DocumentStatus.processing,
          reason: 'the list no longer shows the retried document as failed',
        );
      },
    );

    test('a second tap while one is in flight does nothing', () async {
      final repo = ScriptedDocumentsRepository(
        lists: [
          [summaryWith(DocumentStatus.failed)],
        ],
      );
      final (:container, :api) = _setup(repo);
      api.gate = Completer<void>();
      container.listen(retryIngestProvider('doc-1'), (_, _) {});
      final notifier = container.read(retryIngestProvider('doc-1').notifier);

      final first = notifier.retry();
      await notifier.retry();
      expect(container.read(retryIngestProvider('doc-1')).isLoading, isTrue);
      api.gate!.complete();
      await first;

      expect(api.retried, ['doc-1']);
    });

    test(
      '409 not_retryable becomes a plain message and the document is re-read',
      () async {
        final repo = ScriptedDocumentsRepository(
          details: [detailAt('embedding')],
        );
        final (:container, :api) = _setup(repo);
        api.error = const RequestRejectedException(
          'Job is not in a failed state (state=embedding)',
          code: 'not_retryable',
        );
        container.listen(documentDetailProvider('doc-1'), (_, _) {});
        container.listen(retryIngestProvider('doc-1'), (_, _) {});
        await _settle(2);
        final before = repo.detailCalls;

        await container.read(retryIngestProvider('doc-1').notifier).retry();
        await _settle(2);

        final error = container.read(retryIngestProvider('doc-1')).error;
        expect(error, isA<RequestRejectedException>());
        expect(
          (error as RequestRejectedException).message,
          "This document isn't in a failed state any more.",
        );
        expect(
          repo.detailCalls,
          greaterThan(before),
          reason: 'a refusal means our picture was stale',
        );
      },
    );

    test('404 not_found is explained, not shown raw', () async {
      final (:container, :api) = _setup(ScriptedDocumentsRepository());
      api.error = const RequestRejectedException(
        'No ingest job found for this document',
        code: 'not_found',
      );
      container.listen(retryIngestProvider('doc-1'), (_, _) {});

      await container.read(retryIngestProvider('doc-1').notifier).retry();

      expect(
        (container.read(retryIngestProvider('doc-1')).error as AppException)
            .message,
        'There is nothing left to retry for this document.',
      );
    });

    test('a connection failure keeps its own message', () async {
      final (:container, :api) = _setup(ScriptedDocumentsRepository());
      api.error = const NetworkUnreachableException();
      container.listen(retryIngestProvider('doc-1'), (_, _) {});

      await container.read(retryIngestProvider('doc-1').notifier).retry();

      expect(
        container.read(retryIngestProvider('doc-1')).error,
        isA<NetworkUnreachableException>(),
      );
    });

    test('a surprise exception never escapes or leaves it spinning', () async {
      final (:container, :api) = _setup(ScriptedDocumentsRepository());
      api.error = StateError('boom');
      container.listen(retryIngestProvider('doc-1'), (_, _) {});

      await container.read(retryIngestProvider('doc-1').notifier).retry();

      final state = container.read(retryIngestProvider('doc-1'));
      expect(state.isLoading, isFalse);
      expect(state.error, isA<UnknownApiException>());
    });

    test('an answer that lands after the user changed is dropped', () async {
      final repo = ScriptedDocumentsRepository(
        lists: [
          [summaryWith(DocumentStatus.failed)],
        ],
      );
      final (:container, :api) = _setup(repo);
      api.gate = Completer<void>();
      container.listen(documentsListProvider, (_, _) {});
      container.listen(retryIngestProvider('doc-1'), (_, _) {});
      await _settle(2);

      final pending = container
          .read(retryIngestProvider('doc-1').notifier)
          .retry();
      container.read(_userProvider.notifier).state = 'user-2';
      await _settle(3);
      api.gate!.complete();
      await pending;
      await _settle(2);

      expect(
        container.read(documentsListProvider).requireValue.single.status,
        DocumentStatus.failed,
        reason: "user 1's retry must not mark a document in user 2's list",
      );
    });
  });

  group('the list while a document is being retried', () {
    test(
      'keeps showing it as processing while the job runs, then ready',
      () async {
        final repo = ScriptedDocumentsRepository(
          lists: [
            [summaryWith(DocumentStatus.failed)], // initial load
            [summaryWith(DocumentStatus.failed)], // poll: job still running
            [summaryWith(DocumentStatus.failed)], // poll: job just finished
            [summaryWith(DocumentStatus.ready)], // poll: status caught up
          ],
          details: [
            detailAt('embedding', status: DocumentStatus.failed),
            detailAt('ready', status: DocumentStatus.failed),
          ],
        );
        final (:container, api: _) = _setup(repo);
        final seen = <DocumentStatus>[];
        container.listen(
          documentsListProvider,
          (_, next) => next.whenData((l) => seen.add(l.single.status)),
          fireImmediately: true,
        );
        await _settle(2);
        seen.clear(); // only what the user sees AFTER pressing Retry
        container.read(documentsListProvider.notifier).markRetrying('doc-1');

        await _settle(15);

        expect(
          seen,
          isNot(contains(DocumentStatus.failed)),
          reason: 'flickered back to Failed while the retry was running: $seen',
        );
        expect(seen.last, DocumentStatus.ready);
      },
    );

    test('goes back to failed when the retry fails again', () async {
      final repo = ScriptedDocumentsRepository(
        lists: [
          [summaryWith(DocumentStatus.failed)],
        ],
        details: [
          detailAt('normalizing', status: DocumentStatus.failed),
          detailAt(
            'failed',
            status: DocumentStatus.failed,
            lastError: 'corrupt_pdf',
          ),
        ],
      );
      final (:container, api: _) = _setup(repo);
      container.listen(documentsListProvider, (_, _) {});
      await _settle(2);
      container.read(documentsListProvider.notifier).markRetrying('doc-1');
      expect(
        container.read(documentsListProvider).requireValue.single.status,
        DocumentStatus.processing,
      );

      await _settle(15);

      expect(
        container.read(documentsListProvider).requireValue.single.status,
        DocumentStatus.failed,
      );
    });

    test('a user change forgets what was being retried', () async {
      final repo = ScriptedDocumentsRepository(
        lists: [
          [summaryWith(DocumentStatus.failed)],
        ],
        details: [detailAt('embedding', status: DocumentStatus.failed)],
      );
      final (:container, api: _) = _setup(repo);
      container.listen(documentsListProvider, (_, _) {});
      await _settle(2);
      container.read(documentsListProvider.notifier).markRetrying('doc-1');

      container.read(_userProvider.notifier).state = 'user-2';
      await _settle(4);

      expect(
        container.read(documentsListProvider).requireValue.single.status,
        DocumentStatus.failed,
      );
    });
  });

  group('the detail provider through a retry', () {
    test(
      'keeps polling while status says failed but the job is running',
      () async {
        final repo = ScriptedDocumentsRepository(
          details: [
            detailAt('embedding', status: DocumentStatus.failed),
            detailAt('embedding', status: DocumentStatus.failed),
            // The job finished; the document row has not caught up yet. The
            // screen reads this as ready and is done — it must neither flash
            // "Failed" nor stop one poll early on the earlier states.
            detailAt('ready', status: DocumentStatus.failed),
          ],
        );
        final (:container, api: _) = _setup(repo);
        container.listen(documentDetailProvider('doc-1'), (_, _) {});

        await _settle(15);

        expect(repo.detailCalls, 3);
        expect(
          effectiveDocumentStatus(
            container.read(documentDetailProvider('doc-1')).requireValue,
          ),
          DocumentStatus.ready,
        );
      },
    );

    test(
      'a failed document whose job also failed is settled at once',
      () async {
        final repo = ScriptedDocumentsRepository(
          details: [
            detailAt(
              'failed',
              status: DocumentStatus.failed,
              lastError: 'embed_call_failed',
            ),
          ],
        );
        final (:container, api: _) = _setup(repo);
        container.listen(documentDetailProvider('doc-1'), (_, _) {});

        await _settle(6);

        expect(repo.detailCalls, 1);
      },
    );
  });
}
