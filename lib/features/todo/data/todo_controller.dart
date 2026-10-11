import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/app_exception.dart';
import '../../auth/data/current_user_provider.dart';
import 'todo_api.dart';

class TodoState {
  const TodoState({
    this.tasks,
    this.loading = false,
    this.saving = false,
    this.error,
  });
  final List<TodoTask>? tasks;
  final bool loading, saving;
  final AppException? error;
}

final todoControllerProvider = NotifierProvider<TodoController, TodoState>(
  TodoController.new,
);

class TodoController extends Notifier<TodoState> {
  int _generation = 0;
  String? _owner;
  bool _loading = false;
  @override
  TodoState build() {
    _owner = ref.watch(currentUserIdProvider);
    _loading = false;
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    Future.microtask(() {
      if (generation == _generation) unawaited(reload());
    });
    return const TodoState(loading: true);
  }

  bool _current(int generation, String? owner) =>
      generation == _generation && ref.read(currentUserIdProvider) == owner;
  AppException _error(Object error) => error is AppException
      ? error
      : const UnknownApiException('Could not update your tasks. Try again.');
  Future<void> reload() async {
    if (_loading || state.saving || !_current(_generation, _owner)) return;
    _loading = true;
    final generation = ++_generation, owner = _owner;
    final api = ref.read(todoApiProvider);
    state = TodoState(tasks: state.tasks, loading: true);
    try {
      if (owner == null) throw const UnauthenticatedException();
      final tasks = await api.list();
      if (_current(generation, owner)) state = TodoState(tasks: tasks);
    } catch (error) {
      if (_current(generation, owner)) {
        state = TodoState(tasks: state.tasks, error: _error(error));
      }
    } finally {
      if (generation == _generation) _loading = false;
    }
  }

  // ponytail: serialize writes; use per-task locks if bulk actions are added.
  Future<bool> _write(Future<void> Function(TodoApi) action) async {
    if (state.tasks == null || state.loading || state.saving) return false;
    final generation = _generation, owner = _owner;
    if (!_current(generation, owner) || owner == null) return false;
    final tasks = state.tasks!;
    final api = ref.read(todoApiProvider);
    state = TodoState(tasks: tasks, saving: true);
    try {
      await action(api);
      if (!_current(generation, owner)) return false;
      final saved = await api.list();
      if (!_current(generation, owner)) return false;
      state = TodoState(tasks: saved);
      return true;
    } catch (error) {
      if (_current(generation, owner)) {
        List<TodoTask>? latest;
        try {
          latest = await api.list();
        } catch (_) {}
        if (_current(generation, owner)) {
          state = TodoState(tasks: latest ?? tasks, error: _error(error));
        }
      }
      return false;
    }
  }

  void _requireTask(String id) {
    if (!state.tasks!.any((task) => task.id == id)) {
      throw const RequestRejectedException(
        'This task is no longer available. Refresh the list.',
      );
    }
  }

  Future<bool> save(String title, TodoPriority priority, {String? id}) =>
      _write((api) async {
        if (title.trim().isEmpty) {
          throw const RequestRejectedException('Enter a task title.');
        }
        if (id == null) {
          await api.create(title.trim(), priority);
        } else {
          _requireTask(id);
          await api.update(id, title: title.trim(), priority: priority);
        }
      });
  Future<bool> setCompleted(String id, bool completed) => _write((api) async {
    _requireTask(id);
    await api.update(id, completed: completed);
  });
  Future<bool> delete(String id) => _write((api) async {
    _requireTask(id);
    await api.delete(id);
  });
}
