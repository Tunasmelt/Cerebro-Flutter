import 'dart:convert';
import 'dart:typed_data';

import 'package:cerebro_mobile/core/crypto/sealed_crypto.dart';
import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/core/network/generated/cerebro_api.swagger.dart';
import 'package:cerebro_mobile/core/network/generated_api_client.dart';
import 'package:cerebro_mobile/core/network/session_token_provider.dart';
import 'package:cerebro_mobile/features/sealed/data/sealed_document_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Token implements SessionTokenProvider {
  String? token = 'test-jwt';
  @override
  String? get currentAccessToken => token;
}

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

const password = 'known-answer-test-passphrase';
final expectedKey = base64Encode([
  for (final pair in RegExp('..').allMatches(
    '618f4f27fcd47aa29457002646074dfaeecd9a8cc2fa63df9dbba959e2c7ed76',
  ))
    int.parse(pair.group(0)!, radix: 16),
]);

void main() {
  ApiSealedDocumentApi api(
    Future<http.Response> Function(http.Request) handler, {
    _Token? token,
  }) {
    final generated = CerebroApi.create(
      baseUrl: Uri.parse('https://api.test'),
      httpClient: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer test-jwt');
        expect(request.body, isNot(contains(password)));
        return handler(request);
      }),
      interceptors: [GeneratedApiAuthInterceptor(token ?? _Token())],
    );
    addTearDown(generated.client.dispose);
    return ApiSealedDocumentApi(generated);
  }

  Future<http.Response> successful(http.Request request) async {
    if (request.url.path.endsWith('/chunks')) {
      return json({
        'chunks': [
          {'ordinal': 0, 'content': 'content'},
        ],
      });
    }
    if (request.url.path.endsWith('/seal-salt')) {
      return json({'salt': base64Encode(Uint8List(16))});
    }
    if (request.url.path.endsWith('/unlock')) {
      return json({
        'claim_id': 'claim',
        'expires_at': DateTime.now()
            .add(const Duration(minutes: 15))
            .toIso8601String(),
      });
    }
    return json({
      'chunks': [
        {'ordinal': 0, 'content': 'content'},
      ],
    });
  }

  for (final operation in ['seal', 'unlock']) {
    test(
      '$operation rejects empty passphrase without a mutating request',
      () async {
        final requests = <String>[];
        final service = api((request) async {
          requests.add(request.method);
          return successful(request);
        });
        await expectLater(
          operation == 'seal'
              ? service.seal('doc', '')
              : service.unlock('doc', ''),
          throwsArgumentError,
        );
        expect(requests, ['GET']);
      },
    );
  }

  test('empty document stops sealing before sending ciphertext', () async {
    var calls = 0;
    final service = api((request) async {
      calls++;
      return json({'chunks': []});
    });
    await expectLater(service.seal('doc', password), throwsStateError);
    expect(calls, 1);
  });

  for (final salt in [null, 17, 'not base64!', base64Encode(Uint8List(15))]) {
    test('malformed salt $salt stops before unlock', () async {
      var calls = 0;
      final service = api((request) async {
        calls++;
        return json({'salt': salt});
      });
      await expectLater(
        service.unlock('doc', password),
        salt == null || salt is int
            ? throwsA(isA<TypeError>())
            : salt == 'not base64!'
            ? throwsFormatException
            : throwsArgumentError,
      );
      expect(calls, 1);
    });
  }

  for (final stage in ['chunks', 'seal', 'seal-salt', 'unlock', 'unseal']) {
    for (final failure in ['status', 'network']) {
      test(
        '$failure failure at $stage stops the flow',
        () async {
          final paths = <String>[];
          final service = api((request) async {
            paths.add(request.url.path.split('/').last);
            if (paths.last == stage) {
              if (failure == 'network') throw http.ClientException('offline');
              return json({
                'error': {'code': 'unavailable'},
              }, 503);
            }
            return successful(request);
          });
          await expectLater(
            ['chunks', 'seal'].contains(stage)
                ? service.seal('doc', password)
                : service.unlock('doc', password),
            failure == 'status'
                ? throwsStateError
                : throwsA(isA<http.ClientException>()),
          );
          expect(
            paths,
            ['chunks', 'seal'].contains(stage)
                ? ['chunks', if (stage == 'seal') 'seal']
                : [
                    'seal-salt',
                    if (stage != 'seal-salt') 'unlock',
                    if (stage == 'unseal') 'unseal',
                  ],
          );
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    }
  }

  for (final stage in ['chunks', 'unseal']) {
    for (final chunks in [
      null,
      [
        {'ordinal': 0, 'content': 123},
      ],
      [
        {'ordinal': 'invalid', 'content': 'first'},
        {'ordinal': 1, 'content': 'second'},
      ],
    ]) {
      test(
        'malformed chunks at $stage fail without returning content',
        () async {
          final paths = <String>[];
          final service = api((request) async {
            paths.add(request.url.path.split('/').last);
            return paths.last == stage
                ? json({'chunks': chunks})
                : successful(request);
          });
          await expectLater(
            stage == 'chunks'
                ? service.seal('doc', password)
                : service.unlock('doc', password),
            throwsA(isA<TypeError>()),
          );
          expect(paths.last, stage);
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    }
  }

  test(
    'signout after claim issuance aborts unseal',
    () async {
      final token = _Token();
      final paths = <String>[];
      final service = api((request) async {
        paths.add(request.url.path.split('/').last);
        final response = await successful(request);
        if (paths.last == 'unlock') token.token = null;
        return response;
      }, token: token);
      await expectLater(
        service.unlock('doc', password),
        throwsA(isA<UnauthenticatedException>()),
      );
      expect(paths, ['seal-salt', 'unlock']);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  for (final claim in [
    {'claim_id': 'claim', 'expires_at': 'bad date'},
    {'claim_id': null, 'expires_at': '2099-01-01T00:00:00Z'},
    {'claim_id': '', 'expires_at': '2099-01-01T00:00:00Z'},
    {'claim_id': 'claim', 'expires_at': '2000-01-01T00:00:00Z'},
  ]) {
    test(
      'invalid or expired claim $claim stops before unseal',
      () async {
        final paths = <String>[];
        final service = api((request) async {
          paths.add(request.url.path.split('/').last);
          return paths.last == 'unlock' ? json(claim) : successful(request);
        });
        await expectLater(
          service.unlock('doc', password),
          claim['expires_at'] == 'bad date'
              ? throwsFormatException
              : claim['claim_id'] == null
              ? throwsA(isA<TypeError>())
              : throwsStateError,
        );
        expect(paths, ['seal-salt', 'unlock']);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }

  test(
    'claim expiring during unseal never returns active plaintext',
    () async {
      var unsealCalled = false;
      final service = api((request) async {
        if (request.url.path.endsWith('/unlock')) {
          return json({
            'claim_id': 'claim',
            'expires_at': DateTime.now()
                .add(const Duration(seconds: 1))
                .toIso8601String(),
          });
        }
        if (request.url.path.endsWith('/unseal')) {
          unsealCalled = true;
          await Future<void>.delayed(const Duration(milliseconds: 1100));
        }
        return successful(request);
      });
      await expectLater(service.unlock('doc', password), throwsStateError);
      expect(unsealCalled, isTrue);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'signout after receiving salt aborts the authenticated unlock request',
    () async {
      final token = _Token();
      final paths = <String>[];
      final service = api((request) async {
        paths.add(request.url.path.split('/').last);
        final response = await successful(request);
        token.token = null;
        return response;
      }, token: token);
      await expectLater(
        service.unlock('doc', password),
        throwsA(isA<UnauthenticatedException>()),
      );
      expect(paths, ['seal-salt']);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'seal encrypts every ordinal with one salt and distinct nonces',
    () async {
      final requests = <String>[];
      final service = api((request) async {
        requests.add(request.url.path);
        if (request.method == 'GET') {
          return json({
            'chunks': [
              {'ordinal': 4, 'content': 'café 🔒'},
              {'ordinal': 2, 'content': '  spaces\n'},
            ],
          });
        }
        final chunks = (jsonDecode(request.body) as Map)['chunks'] as List;
        expect(chunks.map((c) => c['ordinal']), [4, 2]);
        expect(chunks[0]['salt'], chunks[1]['salt']);
        expect(chunks[0]['nonce'], isNot(chunks[1]['nonce']));
        final key = await deriveSealedKey(
          password,
          base64Decode(chunks[0]['salt'] as String),
        );
        for (var i = 0; i < chunks.length; i++) {
          final chunk = chunks[i] as Map;
          expect(base64Decode(chunk['salt'] as String).length, 16);
          expect(base64Decode(chunk['nonce'] as String).length, 12);
          final clear = await decryptSealedChunk(
            SealedChunk(
              ciphertext: base64Decode(chunk['content_ciphertext'] as String),
              nonce: base64Decode(chunk['nonce'] as String),
            ),
            key,
          );
          expect(utf8.decode(clear), i == 0 ? 'café 🔒' : '  spaces\n');
        }
        return json({'id': 'doc', 'status': 'sealed'});
      });
      await service.seal('doc', password);
      expect(requests, [
        '/api/v1/graph/nodes/doc/chunks',
        '/api/v1/documents/doc/seal',
      ]);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'unlock sends the exact web key, then matching claim/key to unseal',
    () async {
      final expiry = DateTime.now().add(const Duration(minutes: 15));
      final requests = <String>[];
      final service = api((request) async {
        requests.add(request.url.path);
        if (request.method == 'GET') {
          return json({'salt': base64Encode(Uint8List(16))});
        }
        final body = jsonDecode(request.body);
        if (request.url.path.endsWith('/unlock')) {
          expect(body, {'key': expectedKey});
          return json({
            'claim_id': 'claim',
            'expires_at': expiry.toIso8601String(),
          }, 201);
        }
        expect(body, {'claim_id': 'claim', 'key': expectedKey});
        return json({
          'chunks': [
            {'ordinal': 7, 'content': 'last'},
            {'ordinal': 1, 'content': 'first'},
          ],
        });
      });
      final unlock = await service.unlock('doc', password);
      expect(unlock.claimId, 'claim');
      expect(unlock.expiresAt, expiry);
      expect(unlock.content, 'first\n\nlast');
      expect(unlock.key, expectedKey);
      expect(requests, [
        '/api/v1/documents/doc/seal-salt',
        '/api/v1/documents/doc/unlock',
        '/api/v1/documents/doc/unseal',
      ]);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'an invalid key never proceeds to unseal or returns an unlock',
    () async {
      var unsealCalled = false;
      final service = api((request) async {
        if (request.method == 'GET') {
          return json({'salt': base64Encode(Uint8List(16))});
        }
        if (request.url.path.endsWith('/unlock')) {
          return json({
            'error': {'code': 'invalid_key', 'message': 'Incorrect passphrase'},
          }, 401);
        }
        unsealCalled = true;
        return json({'chunks': []});
      });
      await expectLater(service.unlock('doc', password), throwsStateError);
      expect(unsealCalled, isFalse);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'unseal refusal never returns plaintext or an active claim',
    () async {
      final service = api((request) async {
        if (request.method == 'GET') {
          return json({'salt': base64Encode(Uint8List(16))});
        }
        if (request.url.path.endsWith('/unlock')) {
          return json({
            'claim_id': 'claim',
            'expires_at': DateTime.now()
                .add(const Duration(minutes: 15))
                .toIso8601String(),
          }, 201);
        }
        return json({
          'error': {'code': 'rate_limited'},
        }, 429);
      });
      await expectLater(service.unlock('doc', password), throwsStateError);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
