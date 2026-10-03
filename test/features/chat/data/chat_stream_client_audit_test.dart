// Milestone 3.1 audit regressions, each reproduced before being fixed.
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
  @override
  String? get currentAccessToken => 'jwt';
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.headers);

  final int status;
  final Map<String, List<String>> headers;
  bool bodyCancelled = false;
  late final StreamController<Uint8List> body = StreamController<Uint8List>(
    onCancel: () => bodyCancelled = true,
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody(body.stream, status, headers: headers);

  @override
  void close({bool force = false}) {}

  void send(String text) => body.add(Uint8List.fromList(utf8.encode(text)));
}

DioChatStreamClient _client(_Adapter adapter, {Duration? idle}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = adapter;
  return DioChatStreamClient(
    ApiClient(tokenProvider: _Token(), dio: dio).dio,
    idleTimeout: idle ?? const Duration(seconds: 30),
  );
}

Future<({List<ChatStreamEvent> events, Object? error})> _collect(
  Stream<ChatStreamEvent> stream, {
  Duration within = const Duration(seconds: 8),
}) async {
  final events = <ChatStreamEvent>[];
  Object? error;
  final done = Completer<void>();
  stream.listen(
    events.add,
    onError: (Object e) => error = e,
    onDone: done.complete,
  );
  await done.future.timeout(within);
  return (events: events, error: error);
}

void main() {
  group('an error response whose body never finishes', () {
    test(
      'still reports the real status promptly, not after the idle timeout',
      () async {
        // A proxy that sends "502" headers and then stalls the body. The
        // status is already known; waiting on the body for ~90 s (the idle
        // timeout in production) and then calling it a dropped connection
        // throws away the right answer.
        final adapter = _Adapter(502, {})..send('Bad Gat'); // never closed
        final result = await _collect(
          _client(adapter).stream(sessionId: 's', query: 'q'),
        );

        expect(result.error, isA<ServerErrorException>());
      },
    );

    test('a 404 whose body stalls is still a clean "not found"', () async {
      final adapter = _Adapter(404, {})..send('{"error": {"code": "not_f');
      final result = await _collect(
        _client(adapter).stream(sessionId: 's', query: 'q'),
      );

      expect(result.error, isA<RequestRejectedException>());
    });
  });

  group('a 200 that is not an event stream', () {
    test('an HTML page (captive portal, proxy) is called out, not read as '
        '"connection dropped"', () async {
      final adapter = _Adapter(200, {
        'content-type': ['text/html; charset=utf-8'],
      })..send('<html><body>Sign in to the network</body></html>');
      // (Not awaited: close() completes only once something has read it.)
      unawaited(adapter.body.close());
      final result = await _collect(
        _client(adapter).stream(sessionId: 's', query: 'q'),
      );

      expect(result.events, isEmpty);
      expect(result.error, isA<UnknownApiException>());
      expect(
        (result.error as AppException).message,
        isNot(contains('dropped')),
        reason: 'the connection did not drop; something else answered',
      );
      expect(adapter.bodyCancelled, isTrue);
    });

    test('text/event-stream with a charset parameter is accepted', () async {
      final adapter = _Adapter(200, {
        'content-type': ['text/event-stream; charset=utf-8'],
      })..send('event: done\ndata: {}\n\n');
      final result = await _collect(
        _client(adapter).stream(sessionId: 's', query: 'q'),
      );

      expect(result.error, isNull);
      expect(result.events.single, isA<ChatDone>());
    });

    test('a response with no content-type at all is still read', () async {
      final adapter = _Adapter(200, {})..send('event: done\ndata: {}\n\n');
      final result = await _collect(
        _client(adapter).stream(sessionId: 's', query: 'q'),
      );

      expect(result.error, isNull);
      expect(result.events.single, isA<ChatDone>());
    });
  });
}
