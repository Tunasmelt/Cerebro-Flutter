import 'dart:convert';
import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/core/network/generated/cerebro_api.swagger.dart';
import 'package:cerebro_mobile/core/network/generated_api_client.dart';
import 'package:cerebro_mobile/core/network/session_token_provider.dart';
import 'package:cerebro_mobile/features/todo/data/todo_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class Token implements SessionTokenProvider {
  @override
  String? get currentAccessToken => 'test-jwt';
}

http.Response json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);
void main() {
  ApiTodoApi api(Future<http.Response> Function(http.Request) handler) {
    final generated = CerebroApi.create(
      baseUrl: Uri.parse('https://api.test'),
      httpClient: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer test-jwt');
        return handler(request);
      }),
      interceptors: [GeneratedApiAuthInterceptor(Token())],
    );
    addTearDown(generated.client.dispose);
    return ApiTodoApi(generated);
  }

  test(
    'list parses server completion timestamp, priority and document',
    () async {
      final service = api((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/todos');
        return json({
          'todos': [
            {
              'id': 'task',
              'title': 'Task',
              'completed': true,
              'priority': 'high',
              'completed_at': '2026-10-11T10:00:00Z',
              'document_id': 'doc',
            },
          ],
        });
      });
      final task = (await service.list()).single;
      expect(task.completedAt, DateTime.utc(2026, 10, 11, 10));
      expect(task.documentId, 'doc');
      expect(task.priority, TodoPriority.high);
    },
  );
  test(
    'create explicitly sends valid priority instead of nullable model default',
    () async {
      final service = api((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/todos');
        expect(jsonDecode(request.body), {
          'title': 'Task',
          'priority': 'medium',
          'document_id': null,
        });
        return json({'id': 'task'}, 201);
      });
      await service.create('Task', TodoPriority.medium);
    },
  );
  test(
    'complete sends only completion toggle and null optional fields, never timestamps',
    () async {
      final service = api((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/v1/todos/task');
        expect(jsonDecode(request.body), {
          'completed': true,
          'title': null,
          'priority': null,
        });
        return json({'id': 'task'});
      });
      await service.update('task', completed: true);
    },
  );
  test('title and priority update do not change completion', () async {
    final service = api((request) async {
      expect(jsonDecode(request.body), {
        'completed': null,
        'title': 'Edited',
        'priority': 'low',
      });
      return json({'id': 'task'});
    });
    await service.update('task', title: 'Edited', priority: TodoPriority.low);
  });
  test('delete requires matching id and confirmation', () async {
    final service = api((request) async {
      expect(request.method, 'DELETE');
      return json({'id': 'task', 'deleted': true});
    });
    await service.delete('task');
    await expectLater(
      api((_) async => json({'id': 'task'})).delete('task'),
      throwsA(isA<UnknownApiException>()),
    );
  });
  for (final body in [
    null,
    [],
    {},
    {
      'todos': [null],
    },
    {
      'todos': [
        {'id': 'task', 'completed': 'yes'},
      ],
    },
  ]) {
    test('malformed list safely fails: $body', () async {
      await expectLater(
        api((_) async => json(body)).list(),
        throwsA(isA<UnknownApiException>()),
      );
    });
  }
  for (final status in [401, 404, 422, 429, 500]) {
    test('HTTP $status maps to safe app failure', () async {
      await expectLater(
        api(
          (_) async => json({
            'error': {'code': 'not_found', 'message': 'Task not found'},
          }, status),
        ).update('task', completed: true),
        throwsA(isA<AppException>()),
      );
    });
  }
}
