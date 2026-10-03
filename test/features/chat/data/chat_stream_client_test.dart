// The chat stream client against a controllable fake HTTP adapter: bytes
// arrive when the test says, are cut where the test says, stop when the test
// says. No network.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cerebro_mobile/core/network/api_client.dart';
import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/core/network/session_token_provider.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_client.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_event.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Token implements SessionTokenProvider {
  _Token(this.currentAccessToken);
  @override
  final String? currentAccessToken;
}

/// Serves one scripted response per request.
class _Adapter implements HttpClientAdapter {
  _Adapter({this.status = 200, Map<String, List<String>>? headers})
    : headers =
          headers ??
          {
            'content-type': ['text/event-stream'],
          };

  final int status;
  final Map<String, List<String>> headers;

  /// The response body. Test code adds bytes / errors / closes it.
  late final StreamController<Uint8List> body = StreamController<Uint8List>(
    onCancel: () => bodyCancelled = true,
  );
  bool bodyCancelled = false;

  /// Hold the response headers back until this completes (null = reply now).
  Completer<void>? holdHeaders;
  Object? failWith;

  RequestOptions? seen;
  bool requestCancelled = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen = options;
    cancelFuture?.then((_) => requestCancelled = true);
    final hold = holdHeaders;
    if (hold != null) {
      await Future.any([hold.future, ?cancelFuture]);
      if (requestCancelled) {
        throw DioException.requestCancelled(
          requestOptions: options,
          reason: 'cancelled',
        );
      }
    }
    final error = failWith;
    if (error != null) throw error;
    return ResponseBody(body.stream, status, headers: headers);
  }

  @override
  void close({bool force = false}) {}

  void send(String text) => body.add(Uint8List.fromList(utf8.encode(text)));
}

const _wire =
    'event: heartbeat\ndata: {}\n\n'
    'event: retrieval\ndata: {"chunk_ids": ["c1"], "document_ids": ["d1"]}\n\n'
    'event: token\ndata: {"text": "Café "}\n\n'
    'event: token\ndata: {"text": "\u{1F9E0}"}\n\n'
    'event: citation\ndata: {"chunk_id": "c1", "document_id": "d1"}\n\n'
    'event: done\ndata: {}\n\n';

({DioChatStreamClient client, _Adapter adapter}) _setup({
  _Adapter? adapter,
  String? token = 'jwt',
  Duration idleTimeout = const Duration(seconds: 30),
}) {
  final a = adapter ?? _Adapter();
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = a;
  final api = ApiClient(tokenProvider: _Token(token), dio: dio);
  return (
    client: DioChatStreamClient(api.dio, idleTimeout: idleTimeout),
    adapter: a,
  );
}

/// Collects events and the terminal error (if any) of [stream].
class _Run {
  _Run(Stream<ChatStreamEvent> stream) {
    sub = stream.listen(
      events.add,
      onError: (Object e) => error = e,
      onDone: () => done.complete(),
    );
  }
  final List<ChatStreamEvent> events = [];
  Object? error;
  final Completer<void> done = Completer();
  late final StreamSubscription<ChatStreamEvent> sub;
}

Future<void> tick([int ms = 20]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  group('a successful turn', () {
    test(
      'typed events arrive in wire order and the stream then completes',
      () async {
        final (:client, :adapter) = _setup();
        final run = _Run(client.stream(sessionId: 's1', query: 'hi'));

        adapter.send(_wire);
        await adapter.body.close();
        await run.done.future;

        expect(run.error, isNull);
        expect(run.events.map((e) => e.runtimeType), [
          ChatHeartbeat,
          ChatRetrieval,
          ChatToken,
          ChatToken,
          ChatCitation,
          ChatDone,
        ]);
        expect((run.events[2] as ChatToken).text, 'Café ');
        expect((run.events[3] as ChatToken).text, '\u{1F9E0}');
        expect((run.events[1] as ChatRetrieval).documentIds, ['d1']);
        expect((run.events[4] as ChatCitation).chunkId, 'c1');
      },
    );

    test(
      'sends a POST with the query, auth, and a streaming response',
      () async {
        final (:client, :adapter) = _setup();
        final run = _Run(
          client.stream(sessionId: 'sess-9', query: 'what is cerebro?'),
        );
        adapter.send('event: done\ndata: {}\n\n');
        await run.done.future;

        final request = adapter.seen!;
        expect(request.method, 'POST');
        expect(request.path, '/api/v1/chat/sessions/sess-9/stream');
        expect(request.data, {'query': 'what is cerebro?'});
        expect(request.headers['Accept'], 'text/event-stream');
        expect(
          request.headers['authorization'] ?? request.headers['Authorization'],
          'Bearer jwt',
        );
        expect(request.responseType, ResponseType.stream);
      },
    );

    test(
      'events cut at EVERY byte position still arrive identically',
      () async {
        final bytes = utf8.encode(_wire);
        Future<List<String>> run(int cut) async {
          final (:client, :adapter) = _setup();
          final r = _Run(client.stream(sessionId: 's', query: 'q'));
          adapter.body.add(Uint8List.fromList(bytes.sublist(0, cut)));
          await tick(1);
          adapter.body.add(Uint8List.fromList(bytes.sublist(cut)));
          await adapter.body.close();
          await r.done.future;
          expect(r.error, isNull, reason: 'cut $cut');
          return [for (final e in r.events) e.runtimeType.toString()];
        }

        final expected = await run(1);
        expect(expected.last, 'ChatDone');
        for (var cut = 1; cut < bytes.length; cut += 3) {
          expect(await run(cut), expected, reason: 'cut at $cut');
        }
      },
    );

    test(
      'an event name this client does not know is skipped, the turn goes on',
      () async {
        final (:client, :adapter) = _setup();
        final run = _Run(client.stream(sessionId: 's', query: 'q'));
        adapter.send(
          'event: thinking\ndata: {"x": 1}\n\n'
          'event: token\ndata: {"text": "a"}\n\n'
          'event: done\ndata: {}\n\n',
        );
        await run.done.future;

        expect(run.events.map((e) => e.runtimeType), [ChatToken, ChatDone]);
        expect(run.error, isNull);
      },
    );

    test(
      'stops at done: bytes after it are ignored and the connection is released',
      () async {
        final (:client, :adapter) = _setup();
        final run = _Run(client.stream(sessionId: 's', query: 'q'));
        adapter.send('event: done\ndata: {}\n\n');
        await run.done.future;
        await tick();

        expect(adapter.bodyCancelled, isTrue);
      },
    );
  });

  group('a failure the server reports', () {
    test(
      'an error event is a ChatError event, then the stream ends cleanly',
      () async {
        final (:client, :adapter) = _setup();
        final run = _Run(client.stream(sessionId: 's', query: 'q'));
        adapter.send(
          'event: retrieval\ndata: {"chunk_ids": [], "document_ids": []}\n\n'
          'event: error\ndata: {"code": "chat_turn_failed", "message": "ReadTimeout"}\n\n',
        );
        await run.done.future;

        expect(
          run.error,
          isNull,
          reason: 'a reported failure is part of the protocol',
        );
        expect(run.events.last, isA<ChatError>());
        final error = run.events.last as ChatError;
        expect(error.code, 'chat_turn_failed');
        expect(error.userMessage, isNot(contains('ReadTimeout')));
        expect(
          run.events.whereType<ChatDone>(),
          isEmpty,
          reason: 'no done after an error',
        );
      },
    );
  });

  group('a turn that dies without a terminal event is never read as success', () {
    test('the body ends mid-answer', () async {
      final (:client, :adapter) = _setup();
      final run = _Run(client.stream(sessionId: 's', query: 'q'));
      adapter.send(
        'event: retrieval\ndata: {"chunk_ids": ["c1"], "document_ids": ["d1"]}\n\n'
        'event: token\ndata: {"text": "partial"}\n\n',
      );
      await adapter.body.close();
      await run.done.future;

      expect(run.events.whereType<ChatToken>(), hasLength(1));
      expect(run.events.whereType<ChatDone>(), isEmpty);
      expect(run.error, isA<UnknownApiException>());
      expect((run.error as AppException).message, contains('dropped'));
    });

    test('the connection errors mid-stream', () async {
      final (:client, :adapter) = _setup();
      final run = _Run(client.stream(sessionId: 's', query: 'q'));
      adapter.send('event: token\ndata: {"text": "a"}\n\n');
      await tick();
      adapter.body.addError(const FormatException('connection reset'));
      await run.done.future;

      expect(run.events.whereType<ChatToken>(), hasLength(1));
      expect(run.error, isA<AppException>());
    });

    test('a half-sent final event is not delivered', () async {
      final (:client, :adapter) = _setup();
      final run = _Run(client.stream(sessionId: 's', query: 'q'));
      adapter.send(
        'event: token\ndata: {"text": "a"}\n\nevent: token\ndata: {"text": "b',
      );
      await adapter.body.close();
      await run.done.future;

      expect(
        [for (final t in run.events.whereType<ChatToken>()) t.text],
        ['a'],
      );
      expect(run.error, isNotNull);
    });

    test(
      'silence longer than the idle timeout is a dropped connection',
      () async {
        final (:client, :adapter) = _setup(
          idleTimeout: const Duration(milliseconds: 80),
        );
        final run = _Run(client.stream(sessionId: 's', query: 'q'));
        adapter.send('event: token\ndata: {"text": "a"}\n\n');

        await run.done.future.timeout(const Duration(seconds: 2));

        expect(run.error, isA<UnknownApiException>());
        expect(adapter.bodyCancelled, isTrue);
      },
    );

    test(
      'keep-alive comments count as life, so a slow answer is not cut',
      () async {
        final (:client, :adapter) = _setup(
          idleTimeout: const Duration(milliseconds: 100),
        );
        final run = _Run(client.stream(sessionId: 's', query: 'q'));
        for (var i = 0; i < 6; i++) {
          adapter.send(': ping\n\n');
          await tick(40); // 240 ms total, > the 100 ms idle limit
        }
        adapter.send('event: done\ndata: {}\n\n');
        await run.done.future;

        expect(run.error, isNull);
        expect(run.events.last, isA<ChatDone>());
      },
    );

    test(
      'a known event with a broken payload ends the turn with an error',
      () async {
        final (:client, :adapter) = _setup();
        final run = _Run(client.stream(sessionId: 's', query: 'q'));
        adapter.send('event: token\ndata: not-json\n\n');
        await run.done.future;

        expect(run.error, isA<UnknownApiException>());
        expect(adapter.bodyCancelled, isTrue);
      },
    );
  });

  group('cancelling (the Stop button)', () {
    test('mid-answer: the connection is released', () async {
      final (:client, :adapter) = _setup();
      final run = _Run(client.stream(sessionId: 's', query: 'q'));
      adapter.send('event: token\ndata: {"text": "a"}\n\n');
      await tick();

      await run.sub.cancel();
      await tick();

      expect(adapter.bodyCancelled, isTrue);
      expect(adapter.requestCancelled, isTrue);
    });

    test(
      'while the server is silent (cancel must not wait for the next event)',
      () async {
        final (:client, :adapter) = _setup();
        final run = _Run(client.stream(sessionId: 's', query: 'q'));
        adapter.send('event: heartbeat\ndata: {}\n\n');
        await tick();

        // No event is coming. Cancel must still complete promptly.
        await run.sub.cancel().timeout(const Duration(seconds: 1));

        expect(adapter.bodyCancelled, isTrue);
      },
    );

    test('before the response headers have even arrived', () async {
      final adapter = _Adapter()..holdHeaders = Completer<void>();
      final (:client, adapter: _) = _setup(adapter: adapter);
      final run = _Run(client.stream(sessionId: 's', query: 'q'));
      await tick();

      await run.sub.cancel().timeout(const Duration(seconds: 1));
      await tick();

      expect(adapter.requestCancelled, isTrue);
      expect(run.events, isEmpty);
      expect(run.error, isNull, reason: 'a user cancel is not an error');
    });
  });

  group('failing to open the stream', () {
    Future<Object?> failure(_Adapter adapter, {String? token = 'jwt'}) async {
      final (:client, adapter: _) = _setup(adapter: adapter, token: token);
      // An error response's body ends, like a real one.
      unawaited(adapter.body.close());
      final run = _Run(client.stream(sessionId: 's', query: 'q'));
      await run.done.future.timeout(const Duration(seconds: 2));
      expect(run.events, isEmpty);
      return run.error;
    }

    test('no network', () async {
      final adapter = _Adapter()
        ..failWith = DioException.connectionError(
          requestOptions: RequestOptions(),
          reason: 'offline',
        );
      expect(await failure(adapter), isA<NetworkUnreachableException>());
    });

    test('not signed in: fails fast, nothing is sent', () async {
      final adapter = _Adapter();
      expect(
        await failure(adapter, token: null),
        isA<UnauthenticatedException>(),
      );
      expect(adapter.seen, isNull);
    });

    test('401: the session has expired', () async {
      final adapter = _Adapter(status: 401)..send('{}');
      expect(await failure(adapter), isA<UnauthorizedException>());
    });

    test(
      '404: the conversation is gone, with the server\'s own wording',
      () async {
        final adapter = _Adapter(status: 404)
          ..send(
            '{"error": {"code": "not_found", "message": "Chat session not found"}}',
          );
        final error = await failure(adapter);
        expect(error, isA<RequestRejectedException>());
        expect((error as RequestRejectedException).code, 'not_found');
        expect(error.message, 'Chat session not found');
      },
    );

    test('429: rate limited, with the retry time in plain words', () async {
      final adapter =
          _Adapter(
            status: 429,
            headers: {
              'retry-after': ['120'],
            },
          )..send(
            '{"error": {"code": "rate_limited", "message": "Too many requests"}}',
          );
      final error = await failure(adapter) as RequestRejectedException;
      expect(error.code, 'rate_limited');
      expect(error.message, contains('minutes'));
    });

    test('5xx: a server error', () async {
      final adapter = _Adapter(status: 503)..send('upstream down');
      expect(await failure(adapter), isA<ServerErrorException>());
    });

    test(
      'an HTML error page from a proxy is not parsed as the protocol',
      () async {
        final adapter = _Adapter(status: 400)..send('<html>Bad Gateway</html>');
        expect(await failure(adapter), isA<UnknownApiException>());
      },
    );
  });
}
