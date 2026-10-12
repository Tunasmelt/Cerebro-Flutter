import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/app_exception.dart';
import '../../auth/data/current_user_provider.dart';
import 'chat_sessions_list.dart';

class PendingSessionDeletesState {
  const PendingSessionDeletesState({this.ids = const {}, this.error});
  final Set<String> ids;
  final AppException? error;
}

final pendingSessionDeletesProvider =
    NotifierProvider<PendingSessionDeletes, PendingSessionDeletesState>(
      PendingSessionDeletes.new,
    );

class PendingSessionDeletes extends Notifier<PendingSessionDeletesState> {
  final _timers = <String, Timer>{};
  int _generation = 0;
  @override
  PendingSessionDeletesState build() {
    ref.watch(currentUserIdProvider);
    _generation++;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    ref.onDispose(() {
      _generation++;
      for (final timer in _timers.values) {
        timer.cancel();
      }
      _timers.clear();
    });
    return const PendingSessionDeletesState();
  }

  void queue(String id) {
    if (state.ids.contains(id) || ref.read(currentUserIdProvider) == null) {
      return;
    }
    final generation = _generation;
    final owner = ref.read(currentUserIdProvider);
    state = PendingSessionDeletesState(ids: {...state.ids, id});
    _timers[id] = Timer(const Duration(seconds: 5), () async {
      if (generation != _generation ||
          ref.read(currentUserIdProvider) != owner) {
        return;
      }
      // Keep the auto-disposed list controller alive through its deletion.
      final keeper = ref.listen(chatSessionsListProvider, (_, _) {});
      try {
        final error = await ref
            .read(chatSessionsListProvider.notifier)
            .delete(id);
        if (generation != _generation) return;
        _timers.remove(id);
        state = PendingSessionDeletesState(
          ids: {...state.ids}..remove(id),
          error: error,
        );
      } finally {
        keeper.close();
      }
    });
  }

  void undo(String id) {
    final timer = _timers[id];
    if (timer == null || !timer.isActive) return;
    timer.cancel();
    _timers.remove(id);
    state = PendingSessionDeletesState(ids: {...state.ids}..remove(id));
  }
}
