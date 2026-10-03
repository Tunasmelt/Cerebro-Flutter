import 'package:cerebro_mobile/core/sse/sse_event.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_event.dart';
import 'package:flutter_test/flutter_test.dart';

SseEvent sse(String event, String data) => SseEvent(event: event, data: data);

void main() {
  group('each event type is dispatched to its own typed event', () {
    test('heartbeat', () {
      expect(chatEventFromSse(sse('heartbeat', '{}')), isA<ChatHeartbeat>());
    });

    test('retrieval carries the chunk and document ids', () {
      final event = chatEventFromSse(
        sse('retrieval', '{"chunk_ids": ["c1", "c2"], "document_ids": ["d1"]}'),
      );
      expect(event, isA<ChatRetrieval>());
      event as ChatRetrieval;
      expect(event.chunkIds, ['c1', 'c2']);
      expect(event.documentIds, ['d1']);
      expect(event.isEmpty, isFalse);
    });

    test('an empty retrieval is recognised as "found nothing"', () {
      final event =
          chatEventFromSse(
                sse('retrieval', '{"chunk_ids": [], "document_ids": []}'),
              )
              as ChatRetrieval;
      expect(event.isEmpty, isTrue);
    });

    test('token carries its text, exactly (no trimming)', () {
      final event =
          chatEventFromSse(sse('token', '{"text": " hello "}')) as ChatToken;
      expect(event.text, ' hello ');
    });

    test('citation carries chunk and document ids', () {
      final event =
          chatEventFromSse(
                sse('citation', '{"chunk_id": "c1", "document_id": "d1"}'),
              )
              as ChatCitation;
      expect(event.chunkId, 'c1');
      expect(event.documentId, 'd1');
    });

    test('done', () {
      expect(chatEventFromSse(sse('done', '{}')), isA<ChatDone>());
    });

    test('done and heartbeat tolerate an empty payload', () {
      expect(chatEventFromSse(sse('done', '')), isA<ChatDone>());
      expect(chatEventFromSse(sse('heartbeat', '')), isA<ChatHeartbeat>());
    });

    test('error keeps the server code and message', () {
      final event =
          chatEventFromSse(
                sse(
                  'error',
                  '{"code": "chat_turn_failed", "message": "ReadTimeout"}',
                ),
              )
              as ChatError;
      expect(event.code, 'chat_turn_failed');
      expect(event.rawMessage, 'ReadTimeout');
    });
  });

  group('the user never sees the server\'s raw error text', () {
    // The backend sends `str(exc) or type(exc).__name__`: technical, and
    // sometimes empty. It must not be shown.
    for (final raw in [
      'ReadTimeout',
      '',
      'httpx.ConnectError: [Errno 111]',
      'KeyError: GEMINI_API_KEY',
    ]) {
      test('"$raw"', () {
        final error = ChatError(code: 'chat_turn_failed', rawMessage: raw);
        expect(error.userMessage, isNotEmpty);
        if (raw.isNotEmpty) expect(error.userMessage, isNot(contains(raw)));
      });
    }

    test('an error event with no usable fields still reads as an error', () {
      final event = chatEventFromSse(sse('error', '{}')) as ChatError;
      expect(event.code, 'unknown');
      expect(event.rawMessage, '');
      expect(event.userMessage, isNotEmpty);
    });
  });

  group('forward compatibility', () {
    test('an event this client does not know is ignored, not an error', () {
      expect(chatEventFromSse(sse('thinking', '{"x": 1}')), isNull);
      expect(chatEventFromSse(sse('message', 'hello')), isNull);
    });
  });

  group(
    'a known event with a payload that breaks the contract is rejected',
    () {
      final bad = <String, SseEvent>{
        'token: not JSON': sse('token', 'hello'),
        'token: no text': sse('token', '{}'),
        'token: text is a number': sse('token', '{"text": 5}'),
        'token: payload is a list': sse('token', '["a"]'),
        'citation: no chunk_id': sse('citation', '{"document_id": "d"}'),
        'citation: no document_id': sse('citation', '{"chunk_id": "c"}'),
        'retrieval: ids not a list': sse('retrieval', '{"chunk_ids": "c1"}'),
        'retrieval: ids contain a number': sse(
          'retrieval',
          '{"chunk_ids": [1], "document_ids": []}',
        ),
        'retrieval: not JSON': sse('retrieval', '<html>'),
      };
      for (final entry in bad.entries) {
        test(entry.key, () {
          expect(() => chatEventFromSse(entry.value), throwsFormatException);
        });
      }

      test('retrieval with the id lists missing is read as empty', () {
        final event = chatEventFromSse(sse('retrieval', '{}')) as ChatRetrieval;
        expect(event.chunkIds, isEmpty);
        expect(event.documentIds, isEmpty);
      });
    },
  );
}
