import 'dart:convert';
import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/core/network/generated/cerebro_api.swagger.dart';
import 'package:cerebro_mobile/core/network/generated_api_client.dart';
import 'package:cerebro_mobile/core/network/session_token_provider.dart';
import 'package:cerebro_mobile/features/playground/data/playground_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class Token implements SessionTokenProvider {
  @override
  String? get currentAccessToken => 'test-jwt';
}

Map<String, dynamic> body() => {
  'model': 'server-model',
  'sections': [
    {'label': 'context', 'content': 'Text', 'tokens': 2, 'citation': 'Source'},
  ],
  'response': {'content': 'Answer', 'tokens': 5},
  'total_tokens': 20,
  'estimated_cost_usd': 0.000017,
};
void main() {
  ApiPlaygroundApi api(
    Object? payload, {
    int status = 200,
    void Function(http.Request)? check,
  }) {
    final generated = CerebroApi.create(
      baseUrl: Uri.parse('https://api.test'),
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.headers['authorization'], 'Bearer test-jwt');
        check?.call(request);
        return http.Response(
          jsonEncode(payload),
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
      interceptors: [GeneratedApiAuthInterceptor(Token())],
    );
    addTearDown(generated.client.dispose);
    return ApiPlaygroundApi(generated);
  }

  test(
    'uses authenticated prompt GET and preserves server estimates',
    () async {
      final value = await api(
        body(),
        check: (request) => expect(
          request.url.path,
          '/api/v1/chat/sessions/s/messages/m/prompt',
        ),
      ).prompt('s', 'm');
      expect(value.inputTokens, 15);
      expect(value.totalTokens, 20);
      expect(value.cost, 0.000017);
      expect(value.sections.single.citation, 'Source');
    },
  );
  test(
    'assistant selection preserves database IDs and excludes user turns',
    () async {
      final value = await api(
        {
          'messages': [
            {'id': 'u', 'role': 'user', 'content': 'Question'},
            {'id': 'real-id', 'role': 'assistant', 'content': 'Answer'},
          ],
        },
        check: (request) =>
            expect(request.url.path, '/api/v1/chat/sessions/s/messages'),
      ).turns('s');
      expect(value.single.id, 'real-id');
    },
  );
  for (final status in [401, 404, 422, 429, 500]) {
    test('maps HTTP $status', () async {
      await expectLater(
        api({
          'error': {'code': 'not_found', 'message': 'Missing'},
        }, status: status).prompt('s', 'm'),
        throwsA(isA<AppException>()),
      );
    });
  }
  for (final payload in [
    null,
    [],
    {},
    {...body(), 'total_tokens': 1},
    {...body(), 'estimated_cost_usd': -1},
    {
      ...body(),
      'sections': [
        {'content': 'private'},
      ],
    },
  ]) {
    test('rejects malformed breakdown ${jsonEncode(payload)} safely', () async {
      await expectLater(
        api(payload).prompt('s', 'm'),
        throwsA(
          isA<UnknownApiException>().having(
            (e) => e.message,
            'message',
            isNot(contains('private')),
          ),
        ),
      );
    });
  }
  test('rejects malformed message list', () async {
    await expectLater(
      api({
        'messages': [null],
      }).turns('s'),
      throwsA(isA<UnknownApiException>()),
    );
  });
}
