import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chopper/chopper.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/generated/cerebro_api.swagger.dart';
import '../../../core/network/generated/cerebro_api.enums.swagger.dart'
    as enums;
import '../../../core/network/generated_api_client_provider.dart';
import '../../documents/data/documents_error_mapper.dart';

enum TodoPriority { low, medium, high }

class TodoTask {
  const TodoTask({
    required this.id,
    required this.title,
    required this.completed,
    this.priority = TodoPriority.medium,
    this.documentId,
    this.completedAt,
  });
  factory TodoTask.fromJson(Map<String, dynamic> json) => TodoTask(
    id: json['id'] as String,
    title: json['title'] as String,
    completed: json['completed'] as bool,
    priority: TodoPriority.values.byName(
      json['priority'] as String? ?? 'medium',
    ),
    documentId: json['document_id'] as String?,
    completedAt: json['completed_at'] == null
        ? null
        : DateTime.parse(json['completed_at'] as String),
  );
  final String id, title;
  final bool completed;
  final TodoPriority priority;
  final String? documentId;
  final DateTime? completedAt;
}

({List<TodoTask> active, List<TodoTask> completed}) groupTodos(
  List<TodoTask> tasks, {
  TodoPriority? priority,
}) {
  final active = <TodoTask>[], completed = <TodoTask>[];
  for (final task in tasks) {
    if (priority == null || task.priority == priority) {
      (task.completed ? completed : active).add(task);
    }
  }
  return (active: active, completed: completed);
}

final todoApiProvider = Provider<TodoApi>(
  (ref) => ApiTodoApi(ref.watch(generatedApiClientProvider)),
);

abstract interface class TodoApi {
  Future<List<TodoTask>> list();
  Future<void> create(String title, TodoPriority priority);
  Future<void> update(
    String id, {
    bool? completed,
    String? title,
    TodoPriority? priority,
  });
  Future<void> delete(String id);
}

class ApiTodoApi implements TodoApi {
  ApiTodoApi(this.client);
  final CerebroApi client;
  Future<Map<String, dynamic>> _send(
    Future<Response> Function() request,
  ) async {
    try {
      final response = await request();
      if (!response.isSuccessful) {
        throw DocumentsErrorMapper.ofResponse(response);
      }
      if (response.body is! Map) throw const FormatException();
      return Map<String, dynamic>.from(response.body as Map);
    } catch (error) {
      final mapped = DocumentsErrorMapper.ofException(error);
      throw mapped is UnknownApiException
          ? const UnknownApiException('Could not update your tasks. Try again.')
          : mapped;
    }
  }

  @override
  Future<List<TodoTask>> list() async {
    final body = await _send(client.apiV1TodosGet);
    try {
      return [
        for (final task in body['todos'] as List)
          TodoTask.fromJson(Map<String, dynamic>.from(task as Map)),
      ];
    } catch (_) {
      throw const UnknownApiException('Could not load your tasks. Try again.');
    }
  }

  void _id(Map<String, dynamic> body, [String? expected]) {
    if (body['id'] is! String ||
        (body['id'] as String).isEmpty ||
        (expected != null && body['id'] != expected)) {
      throw const UnknownApiException(
        'Could not update your tasks. Try again.',
      );
    }
  }

  @override
  Future<void> create(String title, TodoPriority priority) async {
    final body = await _send(
      () => client.apiV1TodosPost(
        body: CreateTodoBody(
          title: title,
          priority: enums.CreateTodoBodyPriority.values.byName(priority.name),
        ),
      ),
    );
    _id(body);
  }

  @override
  Future<void> update(
    String id, {
    bool? completed,
    String? title,
    TodoPriority? priority,
  }) async {
    final body = await _send(
      () => client.apiV1TodosTodoIdPatch(
        todoId: id,
        body: UpdateTodoBody(
          completed: completed,
          title: title,
          priority: priority == null
              ? null
              : enums.UpdateTodoBodyPriority.values.byName(priority.name),
        ),
      ),
    );
    _id(body, id);
  }

  @override
  Future<void> delete(String id) async {
    final body = await _send(() => client.apiV1TodosTodoIdDelete(todoId: id));
    _id(body, id);
    if (body['deleted'] != true) {
      throw const UnknownApiException('Could not delete this task.');
    }
  }
}
