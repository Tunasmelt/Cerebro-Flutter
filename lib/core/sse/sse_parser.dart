import 'dart:async';
import 'dart:convert';

import 'sse_event.dart';

/// Parses a Server-Sent Events byte stream into [SseEvent]s.
///
/// Dart has no `EventSource`, and the failure mode every hand-rolled SSE
/// parser hits is assuming each network chunk holds whole events. A chunk
/// boundary can fall anywhere — mid-event, mid-line, between the `\r` and
/// `\n` of a CRLF, or inside a multi-byte UTF-8 character. This follows the
/// spec's line-by-line state machine, so none of that matters:
///
///  * bytes are decoded with a *chunked* UTF-8 decoder that carries a
///    partial character over to the next chunk;
///  * `\n`, `\r` and `\r\n` all end a line, including a `\r\n` split across
///    two chunks;
///  * an event is dispatched only by a blank line, and an event still
///    incomplete when the stream ends is discarded (the spec says so — a
///    half-received event must never be acted on);
///  * lines starting with `:` are comments (servers use them as keep-alives);
///  * several `data:` lines join with `\n`; one leading space after the
///    colon is dropped; a leading byte-order mark is ignored.
///
/// Built on stream transformers rather than an `async*` generator on
/// purpose: cancelling a subscription to an `async*` stream that is parked
/// waiting for the next network event is not honoured until that event
/// arrives, so a "Stop" tapped while the server is silent would leave the
/// connection open. A transformer forwards the cancel to [bytes] at once.
Stream<SseEvent> parseSse(Stream<List<int>> bytes) {
  final machine = _SseMachine();
  // `cast`, not a direct transform: HTTP bodies are `Stream<Uint8List>`, and
  // a `Stream<Uint8List>` passed where `Stream<List<int>>` is declared fails
  // the runtime generic check on `.transform(Utf8Decoder)` — it only works
  // once the stream's own type argument is widened.
  return bytes
      .cast<List<int>>()
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(
        StreamTransformer<String, SseEvent>.fromHandlers(
          handleData: (chunk, sink) {
            for (final event in machine.add(chunk)) {
              sink.add(event);
            }
          },
          // End of stream: whatever is buffered is an incomplete event —
          // discarded, as the spec requires.
        ),
      );
}

/// The spec's event-stream interpreter, fed decoded text a chunk at a time.
class _SseMachine {
  final StringBuffer _line = StringBuffer();
  bool _previousWasCarriageReturn = false;
  bool _atStreamStart = true;

  String? _eventType;
  final List<String> _data = [];
  String? _lastEventId;
  int? _retry;

  static final RegExp _digits = RegExp(r'^[0-9]+$');

  /// Consumes [chunk] and returns the events it completed.
  List<SseEvent> add(String chunk) {
    final events = <SseEvent>[];
    if (_atStreamStart && chunk.isNotEmpty) {
      _atStreamStart = false;
      if (chunk.startsWith('﻿')) chunk = chunk.substring(1);
    }
    for (var i = 0; i < chunk.length; i++) {
      final char = chunk[i];
      if (_previousWasCarriageReturn) {
        _previousWasCarriageReturn = false;
        if (char == '\n') continue; // the \n of a \r\n already handled
      }
      if (char == '\r' || char == '\n') {
        _previousWasCarriageReturn = char == '\r';
        final event = _processLine(_line.toString());
        _line.clear();
        if (event != null) events.add(event);
      } else {
        _line.write(char);
      }
    }
    return events;
  }

  SseEvent? _processLine(String text) {
    if (text.isEmpty) {
      // Blank line: dispatch — unless there is nothing to dispatch.
      if (_data.isEmpty) {
        _eventType = null;
        _retry = null;
        return null;
      }
      final type = _eventType;
      final event = SseEvent(
        event: (type == null || type.isEmpty) ? 'message' : type,
        data: _data.join('\n'),
        id: _lastEventId,
        retry: _retry,
      );
      _eventType = null;
      _data.clear();
      _retry = null;
      return event;
    }
    if (text.startsWith(':')) return null; // comment

    final colon = text.indexOf(':');
    final String field;
    String value;
    if (colon == -1) {
      field = text;
      value = '';
    } else {
      field = text.substring(0, colon);
      value = text.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
    }

    switch (field) {
      case 'event':
        _eventType = value;
      case 'data':
        _data.add(value);
      case 'id':
        if (!value.contains('\u0000')) _lastEventId = value;
      case 'retry':
        if (_digits.hasMatch(value)) _retry = int.parse(value);
      default:
        break; // unknown fields are ignored
    }
    return null;
  }
}
