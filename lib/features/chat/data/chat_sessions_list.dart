import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../auth/data/current_user_provider.dart';
import 'chat_controller.dart';
import 'chat_history_api.dart';

/// The user's past conversations, most recent first. Fetched fresh each time
/// the history screen opens (autoDispose), so it never shows a stale list.
final chatSessionsListProvider =
    AsyncNotifierProvider.autoDispose<
      ChatSessionsListNotifier,
      List<ChatSessionSummary>
    >(ChatSessionsListNotifier.new);

class ChatSessionsListNotifier
    extends AutoDisposeAsyncNotifier<List<ChatSessionSummary>> {
  /// Bumped on rebuild (user change) and dispose, so a slow response for one
  /// user can never land in the next user's list.
  int _generation = 0;

  @override
  Future<List<ChatSessionSummary>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    if (userId == null) return const [];
    final sessions = await ref.read(chatHistoryApiProvider).list();
    if (generation != _generation) return const [];
    return sessions;
  }

  Future<void> refresh() async {
    final generation = _generation;
    state = const AsyncLoading<List<ChatSessionSummary>>().copyWithPrevious(
      state,
    );
    final result = await AsyncValue.guard(
      () => ref.read(chatHistoryApiProvider).list(),
    );
    if (generation != _generation) return;
    state = result;
  }

  /// Deletes a conversation. Returns null once it is gone — deleted now, or
  /// already gone, which is the state the user asked for — or the reason it
  /// could not be deleted (the conversation then stays in the list).
  ///
  /// If it is the conversation currently open in the Chat tab, that chat is
  /// cleared too: leaving it on screen would invite a follow-up into a
  /// conversation that no longer exists.
  Future<AppException?> delete(String sessionId) async {
    final generation = _generation;
    try {
      await ref.read(chatHistoryApiProvider).delete(sessionId);
    } on AppException catch (error) {
      final alreadyGone =
          error is RequestRejectedException && error.code == 'not_found';
      if (!alreadyGone) return error;
    } catch (_) {
      return const UnknownApiException();
    }

    if (generation == _generation) {
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncData([
          for (final s in current)
            if (s.id != sessionId) s,
        ]);
      }
    }
    if (ref.read(chatControllerProvider).sessionId == sessionId) {
      ref.read(chatControllerProvider.notifier).newChat();
    }
    return null;
  }
}
