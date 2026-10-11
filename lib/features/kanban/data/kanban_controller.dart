import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/app_exception.dart';
import '../../auth/data/current_user_provider.dart';
import 'kanban_api.dart';
import 'kanban_board.dart';

class KanbanState {
  const KanbanState({
    this.board,
    this.loading = false,
    this.saving = false,
    this.error,
  });
  final KanbanBoard? board;
  final bool loading, saving;
  final AppException? error;
}

final kanbanControllerProvider =
    NotifierProvider<KanbanController, KanbanState>(KanbanController.new);

class KanbanController extends Notifier<KanbanState> {
  int _generation = 0;
  String? _owner;
  bool _loadActive = false;
  @override
  KanbanState build() {
    _owner = ref.watch(currentUserIdProvider);
    _loadActive = false;
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    Future.microtask(() {
      if (generation == _generation) unawaited(reload());
    });
    return const KanbanState(loading: true);
  }

  bool _current(int generation, String? owner) =>
      generation == _generation && ref.read(currentUserIdProvider) == owner;

  Future<void> reload() async {
    if (_loadActive || state.saving) return;
    _loadActive = true;
    final generation = ++_generation;
    final owner = _owner;
    final api = ref.read(kanbanApiProvider);
    state = KanbanState(board: state.board, loading: true);
    try {
      if (owner == null) throw const UnauthenticatedException();
      final board = await api.load();
      if (_current(generation, owner)) state = KanbanState(board: board);
    } catch (error) {
      if (_current(generation, owner)) {
        state = KanbanState(board: state.board, error: _safeError(error));
      }
    } finally {
      if (generation == _generation) _loadActive = false;
    }
  }

  AppException _safeError(Object error) => error is AppException
      ? error
      : const UnknownApiException('Could not update your board. Try again.');

  Future<bool> _write(
    Future<void> Function(KanbanApi api, KanbanBoard board) action,
  ) async {
    final board = state.board;
    if (board == null || state.loading || state.saving) return false;
    final generation = _generation;
    final owner = _owner;
    if (!_current(generation, owner)) return false;
    final api = ref.read(kanbanApiProvider);
    state = KanbanState(board: board, saving: true);
    try {
      if (owner == null) throw const UnauthenticatedException();
      await action(api, board);
      if (!_current(generation, owner)) return false;
      final saved = await api.get(board.id);
      if (!_current(generation, owner)) return false;
      state = KanbanState(board: saved);
      return true;
    } catch (error) {
      if (_current(generation, owner)) {
        // A timeout can follow a committed PATCH. Re-read to avoid presenting
        // stale ordering as authoritative, while preserving the error.
        KanbanBoard? latest;
        try {
          latest = await api.get(board.id);
        } catch (_) {}
        if (_current(generation, owner)) {
          state = KanbanState(board: latest ?? board, error: _safeError(error));
        }
      }
      return false;
    }
  }

  Future<bool> create(
    String column,
    String title,
    String description,
    String? documentId,
  ) => _write((api, board) async {
    if (!board.columns.contains(column) || title.trim().isEmpty) {
      throw const RequestRejectedException(
        'Enter a title and choose a column.',
      );
    }
    await api.create(
      board.id,
      column,
      title.trim(),
      description.trim(),
      documentId,
    );
  });

  Future<bool> move(String cardId, String column, int index) => _write((
    api,
    board,
  ) async {
    if (!board.columns.contains(column) ||
        !board.cards.any((card) => card.id == cardId)) {
      throw const RequestRejectedException(
        'This card is no longer available. Refresh the board.',
      );
    }
    final remaining = board
        .inColumn(column)
        .where((card) => card.id != cardId)
        .toList();
    final position = positionForDrop(remaining, index);
    final before = index > 0 ? remaining[index - 1].position : null;
    final after = index < remaining.length ? remaining[index].position : null;
    if (position.isFinite &&
        (before == null || position > before) &&
        (after == null || position < after)) {
      await api.move(cardId, column, position);
      return;
    }
    // Rare duplicate/exhausted float gaps: renumber only the destination.
    // Stop after an account change even if some PATCHes already succeeded.
    final generation = _generation;
    final owner = _owner;
    final ids = remaining.map((card) => card.id).toList()
      ..insert(index, cardId);
    for (var i = 0; i < ids.length; i++) {
      if (!_current(generation, owner)) return;
      await api.move(ids[i], column, i * 1000.0);
    }
  });

  Future<bool> delete(String cardId) => _write((api, board) async {
    if (!board.cards.any((card) => card.id == cardId)) {
      throw const RequestRejectedException(
        'This card is no longer available. Refresh the board.',
      );
    }
    await api.delete(cardId);
  });
}
