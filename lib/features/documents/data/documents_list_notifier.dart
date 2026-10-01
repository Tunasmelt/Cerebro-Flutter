import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/current_user_provider.dart';
import 'document.dart';
import 'documents_repository_provider.dart';

final documentsListProvider =
    AsyncNotifierProvider<DocumentsListNotifier, List<DocumentSummary>>(
      DocumentsListNotifier.new,
    );

class DocumentsListNotifier extends AsyncNotifier<List<DocumentSummary>> {
  @override
  FutureOr<List<DocumentSummary>> build() {
    // Rebuilds (dropping the previous user's list) whenever the signed-in
    // user changes; nothing to fetch while signed out.
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    return fetch();
  }

  /// Unlike `ConnectionStatusNotifier`, this repository is already
  /// overridable at the provider level with a plain fake (no real
  /// Supabase-backed dependency in the way) — tests override
  /// `documentsRepositoryProvider` directly instead of subclassing this
  /// notifier.
  Future<List<DocumentSummary>> fetch() =>
      ref.read(documentsRepositoryProvider).listDocuments();

  Future<void> refresh() async {
    state = const AsyncLoading<List<DocumentSummary>>().copyWithPrevious(
      state,
    );
    state = await AsyncValue.guard(fetch);
  }
}
