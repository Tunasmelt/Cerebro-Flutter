// Deleting a document: the controller, and what the list does about it.
import 'dart:async';

import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/delete_document_api.dart';
import 'package:cerebro_mobile/features/documents/data/delete_document_controller.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_list_notifier.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/documents/data/ingest_polling.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../scripted_documents_repository.dart';

const _tick = Duration(milliseconds: 10);

Future<void> _settle([int ticks = 6]) => Future<void>.delayed(_tick * ticks);

class _FakeDeleteApi implements DeleteDocumentApi {
  final List<String> deleted = [];
  Object? error;
  Completer<void>? gate;

  @override
  Future<void> delete(String documentId) async {
    deleted.add(documentId);
    await gate?.future;
    final e = error;
    if (e != null) throw e;
  }
}

final _userProvider = StateProvider<String?>((_) => 'user-1');

({ProviderContainer container, _FakeDeleteApi api}) _setup(
  ScriptedDocumentsRepository repo,
) {
  final api = _FakeDeleteApi();
  final container = ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(_userProvider)),
      documentsRepositoryProvider.overrideWithValue(repo),
      deleteDocumentApiProvider.overrideWithValue(api),
      ingestPollIntervalProvider.overrideWithValue(_tick),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, api: api);
}

ScriptedDocumentsRepository _repoWith(List<DocumentSummary> docs) =>
    ScriptedDocumentsRepository(lists: [docs]);

List<String> _ids(ProviderContainer c) => [
  for (final d in c.read(documentsListProvider).requireValue) d.id,
];

void main() {
  group('DeleteDocumentController', () {
    test(
      'deletes on the server and takes the document out of the list',
      () async {
        final repo = _repoWith([
          summaryWith(DocumentStatus.failed, id: 'bad'),
          summaryWith(DocumentStatus.ready, id: 'good'),
        ]);
        final (:container, :api) = _setup(repo);
        container.listen(documentsListProvider, (_, _) {});
        container.listen(deleteDocumentProvider('bad'), (_, _) {});
        await _settle(2);

        final deleted = await container
            .read(deleteDocumentProvider('bad').notifier)
            .delete();

        expect(deleted, isTrue);
        expect(api.deleted, ['bad']);
        expect(_ids(container), ['good']);
      },
    );

    test('"already gone" counts as deleted, not as an error', () async {
      final repo = _repoWith([summaryWith(DocumentStatus.failed, id: 'bad')]);
      final (:container, :api) = _setup(repo);
      api.error = const RequestRejectedException(
        'Document not found',
        code: 'not_found',
      );
      container.listen(documentsListProvider, (_, _) {});
      container.listen(deleteDocumentProvider('bad'), (_, _) {});
      await _settle(2);

      final deleted = await container
          .read(deleteDocumentProvider('bad').notifier)
          .delete();

      expect(deleted, isTrue);
      expect(container.read(deleteDocumentProvider('bad')).hasError, isFalse);
      expect(_ids(container), isEmpty);
    });

    test('any other refusal is shown and the document stays', () async {
      final repo = _repoWith([summaryWith(DocumentStatus.failed, id: 'bad')]);
      final (:container, :api) = _setup(repo);
      api.error = const RequestRejectedException(
        "You're doing that too often.",
        code: 'rate_limited',
      );
      container.listen(documentsListProvider, (_, _) {});
      container.listen(deleteDocumentProvider('bad'), (_, _) {});
      await _settle(2);

      final deleted = await container
          .read(deleteDocumentProvider('bad').notifier)
          .delete();

      expect(deleted, isFalse);
      expect(
        (container.read(deleteDocumentProvider('bad')).error as AppException)
            .message,
        "You're doing that too often.",
      );
      expect(_ids(container), ['bad']);
    });

    test(
      'a connection failure keeps its own message and the document',
      () async {
        final repo = _repoWith([summaryWith(DocumentStatus.failed, id: 'bad')]);
        final (:container, :api) = _setup(repo);
        api.error = const NetworkUnreachableException();
        container.listen(documentsListProvider, (_, _) {});
        container.listen(deleteDocumentProvider('bad'), (_, _) {});
        await _settle(2);

        final deleted = await container
            .read(deleteDocumentProvider('bad').notifier)
            .delete();

        expect(deleted, isFalse);
        expect(
          container.read(deleteDocumentProvider('bad')).error,
          isA<NetworkUnreachableException>(),
        );
        expect(_ids(container), ['bad']);
      },
    );

    test('a surprise exception never escapes or leaves it spinning', () async {
      final (:container, :api) = _setup(_repoWith([]));
      api.error = StateError('boom');
      container.listen(deleteDocumentProvider('x'), (_, _) {});

      final deleted = await container
          .read(deleteDocumentProvider('x').notifier)
          .delete();

      final state = container.read(deleteDocumentProvider('x'));
      expect(deleted, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.error, isA<UnknownApiException>());
    });

    test('a second tap while one is in flight does nothing', () async {
      final (:container, :api) = _setup(
        _repoWith([summaryWith(DocumentStatus.failed, id: 'bad')]),
      );
      api.gate = Completer<void>();
      container.listen(deleteDocumentProvider('bad'), (_, _) {});
      final notifier = container.read(deleteDocumentProvider('bad').notifier);

      final first = notifier.delete();
      final second = await notifier.delete();
      api.gate!.complete();
      await first;

      expect(second, isFalse);
      expect(api.deleted, ['bad']);
    });

    test('an answer that lands after the user changed is dropped', () async {
      final (:container, :api) = _setup(
        _repoWith([summaryWith(DocumentStatus.failed, id: 'bad')]),
      );
      api.gate = Completer<void>();
      container.listen(documentsListProvider, (_, _) {});
      container.listen(deleteDocumentProvider('bad'), (_, _) {});
      await _settle(2);

      final pending = container
          .read(deleteDocumentProvider('bad').notifier)
          .delete();
      container.read(_userProvider.notifier).state = 'user-2';
      await _settle(3);
      api.gate!.complete();
      final deleted = await pending;
      await _settle(2);

      expect(deleted, isFalse, reason: 'the screen it belonged to is gone');
      expect(_ids(container), [
        'bad',
      ], reason: "user 1's delete must not edit user 2's list");
    });
  });

  group('the list after a delete', () {
    test('forgets a document that was being retried', () async {
      final repo = ScriptedDocumentsRepository(
        lists: [
          [summaryWith(DocumentStatus.failed, id: 'bad')],
        ],
        details: [
          detailAt('embedding', status: DocumentStatus.failed, id: 'bad'),
        ],
      );
      final (:container, api: _) = _setup(repo);
      container.listen(documentsListProvider, (_, _) {});
      await _settle(2);
      final list = container.read(documentsListProvider.notifier);
      list.markRetrying('bad');

      list.removeDocument('bad');
      await _settle(4);

      expect(_ids(container), isEmpty);
    });

    test('stops polling once nothing is left to wait for', () async {
      final repo = ScriptedDocumentsRepository(
        lists: [
          [summaryWith(DocumentStatus.processing, id: 'only')],
        ],
      );
      final (:container, api: _) = _setup(repo);
      container.listen(documentsListProvider, (_, _) {});
      await _settle(2);

      container.read(documentsListProvider.notifier).removeDocument('only');
      await _settle(1); // let any timer already in flight finish
      final calls = repo.listCalls;
      await _settle(10);

      expect(repo.listCalls, calls);
    });
  });
}
