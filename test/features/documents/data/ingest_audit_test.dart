// Milestone 2.3 audit regressions, each reproduced before being fixed.
import 'dart:async';

import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/document_detail_provider.dart';
import 'package:cerebro_mobile/features/documents/data/documents_list_notifier.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/documents/data/ingest_polling.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../scripted_documents_repository.dart';

const _tick = Duration(milliseconds: 10);

Future<void> _settle([int ticks = 12]) => Future<void>.delayed(_tick * ticks);

final _userProvider = StateProvider<String?>((_) => 'user-a');

/// Lists the documents of whoever is signed in AT CALL TIME. The Nth call
/// can be held back, to model a slow response that lands after a sign-out.
class _PerUserRepository implements DocumentsRepository {
  _PerUserRepository(this._container, {this.aIsProcessing = true});

  /// False keeps polling out of the picture for the refresh test.
  final bool aIsProcessing;

  final ProviderContainer Function() _container;
  Completer<void>? hold;

  @override
  Future<List<DocumentSummary>> listDocuments() async {
    final user = _container().read(_userProvider);
    final gate = hold;
    if (gate != null) {
      hold = null;
      await gate.future;
    }
    return [
      summaryWith(
        user == 'user-a' && aIsProcessing
            ? DocumentStatus.processing
            : DocumentStatus.ready,
        id: 'doc-of-$user',
      ),
    ];
  }

  @override
  Future<DocumentDetail> getDocument(String documentId) =>
      throw UnimplementedError();
}

void main() {
  test(
    'detail keeps polling while the job says ready but the document has not '
    "caught up — the backend writes the job's state and the document's "
    'status in two separate requests',
    () async {
      final repo = ScriptedDocumentsRepository(
        details: [
          detailAt('embedding'),
          // The window between the two writes:
          detailAt('ready'),
          detailAt('ready', status: DocumentStatus.ready),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('user-1'),
          documentsRepositoryProvider.overrideWithValue(repo),
          ingestPollIntervalProvider.overrideWithValue(_tick),
        ],
      );
      addTearDown(container.dispose);
      container.listen(documentDetailProvider('doc-1'), (_, _) {});

      await _settle();

      expect(
        container.read(documentDetailProvider('doc-1')).requireValue.status,
        DocumentStatus.ready,
        reason: 'stopped polling with the badge stuck on "Processing"',
      );
    },
  );

  group('a list response that lands after the user changed', () {
    late ProviderContainer container;
    late _PerUserRepository repo;

    setUp(() {
      repo = _PerUserRepository(() => container);
      container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith(
            (ref) => ref.watch(_userProvider),
          ),
          documentsRepositoryProvider.overrideWithValue(repo),
          ingestPollIntervalProvider.overrideWithValue(_tick),
        ],
      );
      addTearDown(container.dispose);
    });

    test("never replaces the next user's list (poll)", () async {
      container.listen(documentsListProvider, (_, _) {});
      await _settle(2);
      expect(
        container.read(documentsListProvider).requireValue.single.id,
        'doc-of-user-a',
      );

      // user A's next poll is in flight when they sign out and B signs in.
      final gate = Completer<void>();
      repo.hold = gate;
      await _settle(3);
      container.read(_userProvider.notifier).state = 'user-b';
      await _settle(3);
      expect(
        container.read(documentsListProvider).requireValue.single.id,
        'doc-of-user-b',
      );

      gate.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(documentsListProvider).requireValue.single.id,
        'doc-of-user-b',
        reason: "user A's late poll response overwrote user B's list",
      );
    });

    test("never replaces the next user's list (refresh)", () async {
      repo = _PerUserRepository(() => container, aIsProcessing: false);
      container.dispose();
      container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith(
            (ref) => ref.watch(_userProvider),
          ),
          documentsRepositoryProvider.overrideWithValue(repo),
          ingestPollIntervalProvider.overrideWithValue(_tick),
        ],
      );
      addTearDown(container.dispose);
      container.read(_userProvider.notifier).state = 'user-a';
      container.listen(documentsListProvider, (_, _) {});
      await _settle(2);

      final gate = Completer<void>();
      repo.hold = gate;
      final refreshing = container.read(documentsListProvider.notifier).refresh();
      await _settle(2);
      container.read(_userProvider.notifier).state = 'user-b';
      await _settle(3);

      gate.complete();
      await refreshing;

      expect(
        container.read(documentsListProvider).requireValue.single.id,
        'doc-of-user-b',
        reason: "user A's late refresh response overwrote user B's list",
      );
    });
  });
}
