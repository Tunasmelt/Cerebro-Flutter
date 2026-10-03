import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/current_user_provider.dart';
import 'document.dart';
import 'documents_repository_provider.dart';
import 'ingest_polling.dart';
import 'ingest_status.dart';

final documentsListProvider =
    AsyncNotifierProvider<DocumentsListNotifier, List<DocumentSummary>>(
      DocumentsListNotifier.new,
    );

class DocumentsListNotifier extends AsyncNotifier<List<DocumentSummary>> {
  Timer? _pollTimer;

  /// Bumped on every rebuild (user change) and on dispose. Anything that
  /// awaits — a poll, a refresh — remembers the generation it started in
  /// and drops its result if it no longer matches, so a slow response for
  /// one user can never land in the next user's list.
  int _generation = 0;

  int _polls = 0;

  /// Documents whose ingest the user retried. The backend leaves such a
  /// document's `status` at `failed` until the job finishes (a retry only
  /// resets the job), so the list can't tell "failed" from "retrying" on its
  /// own; these ids are shown as processing — and their job looked at —
  /// until the server says otherwise.
  final Set<String> _retrying = {};

  @override
  Future<List<DocumentSummary>> build() async {
    // Rebuilds (dropping the previous user's list) whenever the signed-in
    // user changes; nothing to fetch while signed out.
    final userId = ref.watch(currentUserIdProvider);
    final generation = ++_generation;
    _polls = 0;
    _retrying.clear();
    ref.onDispose(() {
      _generation++;
      _pollTimer?.cancel();
    });
    if (userId == null) return const [];
    final documents = await fetch();
    if (generation != _generation) return documents;
    final shown = await _reconcile(documents, generation);
    if (generation == _generation) _pollIfProcessing(shown);
    return shown;
  }

  /// Unlike `ConnectionStatusNotifier`, this repository is already
  /// overridable at the provider level with a plain fake (no real
  /// Supabase-backed dependency in the way) — tests override
  /// `documentsRepositoryProvider` directly instead of subclassing this
  /// notifier.
  Future<List<DocumentSummary>> fetch() =>
      ref.read(documentsRepositoryProvider).listDocuments();

  Future<void> refresh() async {
    final generation = _generation;
    _polls = 0;
    state = const AsyncLoading<List<DocumentSummary>>().copyWithPrevious(state);
    final fetched = await AsyncValue.guard(fetch);
    if (generation != _generation) return;
    final result = fetched.hasValue
        ? await AsyncValue.guard(
            () => _reconcile(fetched.requireValue, generation),
          )
        : fetched;
    if (generation != _generation) return;
    state = result;
    _pollIfProcessing(result.valueOrNull);
  }

  /// The user just retried [documentId]'s ingest: show it as processing
  /// straight away and keep polling until the job settles.
  void markRetrying(String documentId) {
    _retrying.add(documentId);
    _polls = 0;
    final current = state.valueOrNull;
    if (current == null) return;
    final shown = _present(current);
    state = AsyncData(shown);
    _pollIfProcessing(shown);
  }

  /// Applies [_retrying] to a freshly fetched list. For each retried
  /// document the server still calls `failed`, looks at the job itself:
  /// really failed again → stop treating it as retrying; still running (or
  /// just finished) → keep showing it as processing. A document the server
  /// now calls ready, or no longer lists, is simply done.
  Future<List<DocumentSummary>> _reconcile(
    List<DocumentSummary> fetched,
    int generation,
  ) async {
    if (_retrying.isEmpty) return fetched;
    final repository = ref.read(documentsRepositoryProvider);
    final byId = {for (final d in fetched) d.id: d};

    for (final id in _retrying.toList()) {
      final summary = byId[id];
      if (summary == null || summary.status != DocumentStatus.failed) {
        _retrying.remove(id);
        continue;
      }
      try {
        final detail = await repository.getDocument(id);
        if (generation != _generation) return fetched;
        if (effectiveDocumentStatus(detail) == DocumentStatus.failed) {
          _retrying.remove(id);
        }
      } catch (_) {
        // Couldn't look: keep it retrying and ask again next poll.
      }
    }
    return _present(fetched);
  }

  List<DocumentSummary> _present(List<DocumentSummary> documents) => [
    for (final d in documents)
      if (_retrying.contains(d.id) && d.status == DocumentStatus.failed)
        d.copyWith(status: DocumentStatus.processing)
      else
        d,
  ];

  /// While anything is still `processing`, quietly re-fetch so rows flip
  /// to Ready/Failed on their own. Each poll replaces the list only on
  /// success: a network blip mid-ingest must not swap the list for an
  /// error. Stops when nothing is processing, or after the poll budget.
  void _pollIfProcessing(List<DocumentSummary>? documents) {
    _pollTimer?.cancel();
    if (documents == null) return;
    final now = DateTime.now();
    final waiting = documents.any(
      (d) =>
          d.status == DocumentStatus.processing &&
          !summaryIsAbandonedUpload(d, now),
    );
    if (!waiting) return;

    final interval = ref.read(ingestPollIntervalProvider);
    final budget = maxPolls(interval, ref.read(ingestPollLimitProvider));
    if (_polls >= budget) return;

    final generation = _generation;
    _pollTimer = Timer(interval, () async {
      _polls++;
      try {
        final fetched = await fetch();
        if (generation != _generation) return;
        final latest = await _reconcile(fetched, generation);
        if (generation != _generation) return;
        state = AsyncData(latest);
        _pollIfProcessing(latest);
      } catch (_) {
        if (generation != _generation) return;
        _pollIfProcessing(state.valueOrNull);
      }
    });
  }
}
