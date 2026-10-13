import 'dart:convert';

import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/core/network/generated/cerebro_api.swagger.dart';
import 'package:cerebro_mobile/core/network/generated_api_client.dart';
import 'package:cerebro_mobile/core/network/session_token_provider.dart';
import 'package:cerebro_mobile/features/documents/data/document_actions_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Token implements SessionTokenProvider {
  @override
  String? get currentAccessToken => 'test-jwt';
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  /// The real generated client, with only the network replaced.
  ApiDocumentActionsApi api(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final generated = CerebroApi.create(
      baseUrl: Uri.parse('https://api.test'),
      httpClient: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer test-jwt');
        return handler(request);
      }),
      interceptors: [GeneratedApiAuthInterceptor(_Token())],
    );
    addTearDown(generated.client.dispose);
    return ApiDocumentActionsApi(generated);
  }

  group('rename', () {
    test('PATCHes /documents/{id} with {title}', () async {
      late http.Request seen;
      final service = api((r) async {
        seen = r;
        return _json({'id': 'doc-1', 'title': 'New name'});
      });

      await service.rename('doc-1', 'New name');

      expect(seen.method, 'PATCH');
      expect(seen.url.path, '/api/v1/documents/doc-1');
      expect(jsonDecode(seen.body), {'title': 'New name'});
    });

    test('a 404 is a typed rejection, not a crash', () async {
      final service = api(
        (_) async => _json({
          'error': {'code': 'not_found', 'message': 'Document not found'},
        }, 404),
      );
      await expectLater(
        service.rename('gone', 'x'),
        throwsA(
          isA<RequestRejectedException>().having(
            (e) => e.code,
            'code',
            'not_found',
          ),
        ),
      );
    });

    test("the server's own 422 message is what the user sees", () async {
      final service = api(
        (_) async => _json({
          'error': {'code': 'empty_title', 'message': 'Title cannot be empty'},
        }, 422),
      );
      await expectLater(
        service.rename('doc-1', ' '),
        throwsA(
          isA<RequestRejectedException>().having(
            (e) => e.message,
            'message',
            'Title cannot be empty',
          ),
        ),
      );
    });

    test('a 500 is a server error', () async {
      final service = api((_) async => _json({'detail': 'oops'}, 500));
      await expectLater(
        service.rename('doc-1', 'x'),
        throwsA(isA<ServerErrorException>()),
      );
    });
  });

  group('createNote', () {
    test(
      'POSTs /documents/capture with {text, title} and returns the id',
      () async {
        late http.Request seen;
        final service = api((r) async {
          seen = r;
          return _json({'id': 'note-9', 'state': 'extracting'}, 201);
        });

        final id = await service.createNote(text: 'milk', title: 'Shopping');

        expect(id, 'note-9');
        expect(seen.method, 'POST');
        expect(seen.url.path, '/api/v1/documents/capture');
        expect(jsonDecode(seen.body), {'text': 'milk', 'title': 'Shopping'});
      },
    );

    test('with no title, none is sent', () async {
      late http.Request seen;
      final service = api((r) async {
        seen = r;
        return _json({'id': 'n', 'state': 'extracting'}, 201);
      });

      await service.createNote(text: 'just text');

      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['text'], 'just text');
      expect(body['title'], isNull);
    });

    test('a 413 from the server surfaces its message', () async {
      final service = api(
        (_) async => _json({
          'error': {
            'code': 'text_too_long',
            'message': 'Capture text exceeds 20000 characters',
          },
        }, 413),
      );
      await expectLater(
        service.createNote(text: 'x'),
        throwsA(
          isA<RequestRejectedException>().having(
            (e) => e.code,
            'code',
            'text_too_long',
          ),
        ),
      );
    });

    test('a success with no id is an error, not an empty id', () async {
      final service = api((_) async => _json({'state': 'extracting'}, 201));
      await expectLater(
        service.createNote(text: 'x'),
        throwsA(isA<AppException>()),
      );
    });
  });
}
