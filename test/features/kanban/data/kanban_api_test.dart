import 'dart:convert';
import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/core/network/generated/cerebro_api.swagger.dart';
import 'package:cerebro_mobile/core/network/generated_api_client.dart';
import 'package:cerebro_mobile/core/network/session_token_provider.dart';
import 'package:cerebro_mobile/features/kanban/data/kanban_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class Token implements SessionTokenProvider {
  @override
  String? get currentAccessToken => 'test-jwt';
}

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);
const boardJson = {
  'id': 'board',
  'title': 'My Board',
  'columns': ['Backlog', 'Done'],
  'cards': [
    {
      'id': 'card',
      'title': 'Task',
      'description': '',
      'column_name': 'Done',
      'position': 1500.5,
      'document_id': 'doc',
    },
  ],
};
void main() {
  ApiKanbanApi api(Future<http.Response> Function(http.Request) handler) {
    final generated = CerebroApi.create(
      baseUrl: Uri.parse('https://api.test'),
      httpClient: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer test-jwt');
        return handler(request);
      }),
      interceptors: [GeneratedApiAuthInterceptor(Token())],
    );
    addTearDown(generated.client.dispose);
    return ApiKanbanApi(generated);
  }

  test(
    'loads existing first board, preserving API column and float fields',
    () async {
      final requests = <String>[];
      final service = api((request) async {
        requests.add('${request.method} ${request.url.path}');
        return request.url.path.endsWith('/boards')
            ? json({
                'boards': [
                  {'id': 'board'},
                  {'id': 'older'},
                ],
              })
            : json(boardJson);
      });
      final board = await service.load();
      expect(requests, ['GET /api/v1/boards', 'GET /api/v1/boards/board']);
      expect(board.columns, ['Backlog', 'Done']);
      expect(board.cards.single.position, 1500.5);
      expect(board.cards.single.documentId, 'doc');
    },
  );
  test('empty account creates default board then reads detail', () async {
    final requests = <String>[];
    final service = api((request) async {
      requests.add(request.method);
      if (request.method == 'POST') {
        expect(jsonDecode(request.body), {'title': 'My Board'});
        return json({'id': 'board'}, 201);
      }
      return request.url.path.endsWith('/boards')
          ? json({'boards': []})
          : json(boardJson);
    });
    expect((await service.load()).id, 'board');
    expect(requests, ['GET', 'POST', 'GET']);
  });
  test(
    'create sends optional document and description using generated JSON names',
    () async {
      final service = api((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/boards/board/cards');
        expect(jsonDecode(request.body), {
          'column_name': 'Backlog',
          'title': 'Task',
          'description': 'Notes',
          'document_id': 'doc',
        });
        return json({'id': 'card'}, 201);
      });
      await service.create('board', 'Backlog', 'Task', 'Notes', 'doc');
    },
  );
  test('move PATCH persists fractional position and column', () async {
    final service = api((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/v1/cards/card');
      expect(jsonDecode(request.body), {
        'column_name': 'Done',
        'position': 1500.5,
        'title': null,
        'description': null,
        'document_id': null,
      });
      return json({'id': 'card'});
    });
    await service.move('card', 'Done', 1500.5);
  });
  test('delete uses card endpoint', () async {
    final service = api((request) async {
      expect(request.method, 'DELETE');
      expect(request.url.path, '/api/v1/cards/card');
      return json({'id': 'card', 'deleted': true});
    });
    await service.delete('card');
  });
  for (final status in [401, 404, 422, 500]) {
    test('HTTP $status maps to app exception', () async {
      final service = api(
        (_) async => json({
          'error': {'code': 'not_found', 'message': 'Card not found'},
        }, status),
      );
      await expectLater(
        service.move('card', 'Done', 0),
        throwsA(isA<AppException>()),
      );
    });
  }
  for (final body in [
    null,
    [],
    {'boards': 'invalid'},
    {
      'boards': [null],
    },
    {
      'boards': [
        {'id': 42},
      ],
    },
  ]) {
    test('malformed list is safely rejected: $body', () async {
      final service = api((_) async => json(body ?? 'null'));
      await expectLater(service.load(), throwsA(isA<UnknownApiException>()));
    });
  }
  test('malformed detail is safely rejected', () async {
    final service = api((_) async => json({'id': 'board'}));
    await expectLater(
      service.get('board'),
      throwsA(isA<UnknownApiException>()),
    );
  });
}
