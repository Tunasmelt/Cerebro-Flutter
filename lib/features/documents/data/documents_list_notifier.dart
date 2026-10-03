import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/current_user_provider.dart';
import 'document.dart';
import 'documents_repository_provider.dart';
import 'ingest_polling.dart';

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

  @override
  Future<List<DocumentSummary>> build() async {
    // Rebuilds (dropping the previous user's list) whenever the signed-in
    // user changes; nothing to fetch while signed out.
    final userId = ref.watch(currentUserIdProvider);
    final generation = ++_generation;
    _polls = 0;
    ref.onDispose(() {
      _generation++;
      _pollTimer?.cancel();
    });
    if (userId == null) return const [];
    final documents = await fetch();
    if (generation == _generation) _pollIfProcessing(documents);
    return documents;
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
    final result = await AsyncValue.guard(fetch);
    if (generation != _generation) return;
    state = result;
    _pollIfProcessing(result.valueOrNull);
  }

  /// While anything is still `processing`, quietly re-fetch so rows flip
  /// to Ready/Failed on their own. Each poll replaces the list only on
  /// success: a network blip mid-ingest must not swap the list for an
  /// error. Stops when nothing is processing, or after the poll budget.
  void _pollIfProcessing(List<DocumentSummary>? documents) {
    _pollTimer?.cancel();
    if (documents == null) return;
    if (!documents.any((d) => d.status == DocumentStatus.processing)) return;

    final interval = ref.read(ingestPollIntervalProvider);
    final budget = maxPolls(interval, ref.read(ingestPollLimitProvider));
    if (_polls >= budget) return;

    final generation = _generation;
    _pollTimer = Timer(interval, () async {
      _polls++;
      try {
        final latest = await fetch();
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
