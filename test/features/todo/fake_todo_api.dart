import 'dart:async';
import 'package:cerebro_mobile/features/todo/data/todo_api.dart';

const sampleTasks = [
  TodoTask(id: 'a', title: 'Active task', completed: false),
  TodoTask(
    id: 'b',
    title: 'Finished task',
    completed: true,
    priority: TodoPriority.high,
  ),
];

class FakeTodoApi implements TodoApi {
  List<TodoTask> tasks = [...sampleTasks];
  Object? listError, writeError;
  Completer<void>? writeGate;
  Completer<List<TodoTask>>? listGate;
  int lists = 0;
  final creates = <(String, TodoPriority)>[];
  final updates = <(String, bool?, String?, TodoPriority?)>[];
  final deletes = <String>[];
  @override
  Future<List<TodoTask>> list() async {
    lists++;
    if (listError case final Object error) throw error;
    return listGate == null ? [...tasks] : await listGate!.future;
  }

  Future<void> _write() async {
    await writeGate?.future;
    if (writeError case final Object error) throw error;
  }

  @override
  Future<void> create(String title, TodoPriority priority) async {
    creates.add((title, priority));
    await _write();
    tasks = [
      TodoTask(id: 'new', title: title, completed: false, priority: priority),
      ...tasks,
    ];
  }

  @override
  Future<void> update(
    String id, {
    bool? completed,
    String? title,
    TodoPriority? priority,
  }) async {
    updates.add((id, completed, title, priority));
    await _write();
    tasks = [
      for (final task in tasks)
        task.id != id
            ? task
            : TodoTask(
                id: id,
                title: title ?? task.title,
                priority: priority ?? task.priority,
                completed: completed ?? task.completed,
                documentId: task.documentId,
                completedAt: completed == null
                    ? task.completedAt
                    : completed
                    ? DateTime.utc(2026, 10, 11)
                    : null,
              ),
    ];
  }

  @override
  Future<void> delete(String id) async {
    deletes.add(id);
    await _write();
    tasks = tasks.where((task) => task.id != id).toList();
  }
}
