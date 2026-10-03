// The SSE parser's real failure mode is chunk boundaries, not syntax: a
// network chunk can end anywhere. Every "same events however it is cut"
// test below runs the SAME wire text through different chunkings and
// requires identical output.
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cerebro_mobile/core/sse/sse_event.dart';
import 'package:cerebro_mobile/core/sse/sse_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<SseEvent>> parse(Iterable<List<int>> chunks) =>
    parseSse(Stream.fromIterable(chunks)).toList();

Future<List<SseEvent>> parseText(String wire) => parse([utf8.encode(wire)]);

/// [bytes] cut at each of [cuts] (sorted byte offsets).
List<List<int>> cutAt(List<int> bytes, List<int> cuts) {
  final out = <List<int>>[];
  var start = 0;
  for (final cut in cuts) {
    out.add(bytes.sublist(start, cut));
    start = cut;
  }
  out.add(bytes.sublist(start));
  return out;
}

SseEvent ev(String event, String data, {String? id, int? retry}) =>
    SseEvent(event: event, data: data, id: id, retry: retry);

void main() {
  // A realistic chat stream: heartbeat, retrieval, tokens (one with an
  // emoji and accents — multi-byte), a citation, done. Includes a CRLF
  // event and a comment line so cuts also land inside those.
  const chatWire =
      ': keep-alive\n\n'
      'event: heartbeat\ndata: {}\n\n'
      'event: retrieval\ndata: {"chunk_ids": ["c1","c2"], "document_ids": ["d1"]}\n\n'
      'event: token\ndata: {"text": "Café "}\n\n'
      'event: token\r\ndata: {"text": "\u{1F9E0} mémoire 漢字"}\r\n\r\n'
      'event: citation\ndata: {"chunk_id": "c1", "document_id": "d1"}\n\n'
      'event: done\ndata: {}\n\n';
  final chatBytes = utf8.encode(chatWire);
  final chatExpected = [
    ev('heartbeat', '{}'),
    ev('retrieval', '{"chunk_ids": ["c1","c2"], "document_ids": ["d1"]}'),
    ev('token', '{"text": "Café "}'),
    ev('token', '{"text": "\u{1F9E0} mémoire 漢字"}'),
    ev('citation', '{"chunk_id": "c1", "document_id": "d1"}'),
    ev('done', '{}'),
  ];

  group('however the bytes are cut, the events are the same', () {
    test('uncut', () async {
      expect(await parse([chatBytes]), chatExpected);
    });

    test('every possible single cut (incl. mid-event, mid-line, mid-CRLF, '
        'mid-emoji)', () async {
      for (var cut = 1; cut < chatBytes.length; cut++) {
        expect(
          await parse(cutAt(chatBytes, [cut])),
          chatExpected,
          reason: 'cut at byte $cut of ${chatBytes.length}',
        );
      }
    });

    test('one byte per chunk', () async {
      expect(
        await parse([
          for (final b in chatBytes) [b],
        ]),
        chatExpected,
      );
    });

    test('hundreds of random three-way and many-way cuts (seeded)', () async {
      final random = Random(2026);
      for (var run = 0; run < 400; run++) {
        final count = 2 + random.nextInt(6);
        final cuts = <int>{
          for (var i = 0; i < count; i++)
            1 + random.nextInt(chatBytes.length - 1),
        }.toList()..sort();
        expect(
          await parse(cutAt(chatBytes, cuts)),
          chatExpected,
          reason: 'cuts $cuts',
        );
      }
    });

    test('empty chunks in between change nothing', () async {
      expect(
        await parse([
          [],
          chatBytes.sublist(0, 10),
          [],
          [],
          chatBytes.sublist(10),
          [],
        ]),
        chatExpected,
      );
    });

    test('a very large event across many chunks', () async {
      final big = 'x' * (1024 * 1024);
      final wire = utf8.encode('event: token\ndata: $big\n\n');
      final chunks = <List<int>>[];
      for (var i = 0; i < wire.length; i += 4096) {
        chunks.add(wire.sublist(i, min(i + 4096, wire.length)));
      }
      final events = await parse(chunks);
      expect(events, hasLength(1));
      expect(events.single.data.length, big.length);
    });
  });

  group('the byte stream a real HTTP client produces', () {
    test('a Stream<Uint8List> (what Dio hands over) is accepted', () async {
      // Regression: parseSse is declared over Stream<List<int>>, but a
      // Stream<Uint8List> failed the runtime generic check on transform and
      // crashed the first real stream. Unit tests that only ever fed it
      // Stream<List<int>> never saw it.
      final typed = Stream<Uint8List>.fromIterable([
        Uint8List.fromList(chatBytes.sublist(0, 40)),
        Uint8List.fromList(chatBytes.sublist(40)),
      ]);

      expect(await parseSse(typed).toList(), chatExpected);
    });
  });

  group('line endings', () {
    test('LF, CRLF and bare CR all end lines', () async {
      for (final eol in ['\n', '\r\n', '\r']) {
        expect(
          await parseText(
            'event: a${eol}data: 1$eol$eol'
            'event: b${eol}data: 2$eol$eol',
          ),
          [ev('a', '1'), ev('b', '2')],
          reason: 'eol ${eol.codeUnits}',
        );
      }
    });

    test('a CRLF split between the CR and the LF is one line ending, '
        'not a line and an empty line (which would dispatch early)', () async {
      // If "\r" + "\n" were two line ends, the blank line between "event"
      // and "data" would dispatch an empty event and lose the data.
      final events = await parse([
        utf8.encode('event: a\r'),
        utf8.encode('\ndata: 1\r'),
        utf8.encode('\n\r'),
        utf8.encode('\n'),
      ]);
      expect(events, [ev('a', '1')]);
    });
  });

  group('SSE syntax', () {
    test('comments are ignored', () async {
      expect(await parseText(': hi\nevent: a\n: another\ndata: 1\n\n'), [
        ev('a', '1'),
      ]);
    });

    test('a stream of only comments yields nothing', () async {
      expect(await parseText(': ping\n\n: ping\n\n'), isEmpty);
    });

    test('no event name means "message"', () async {
      expect(await parseText('data: hello\n\n'), [ev('message', 'hello')]);
    });

    test('multiple data lines join with a newline', () async {
      expect(
        await parseText('data: line one\ndata: line two\ndata: line three\n\n'),
        [ev('message', 'line one\nline two\nline three')],
      );
    });

    test('only ONE leading space after the colon is dropped', () async {
      expect(await parseText('data:  two spaces\n\n'), [
        ev('message', ' two spaces'),
      ]);
      expect(await parseText('data:none\n\n'), [ev('message', 'none')]);
    });

    test('a colon inside the value is kept', () async {
      expect(await parseText('data: {"a": "b:c"}\n\n'), [
        ev('message', '{"a": "b:c"}'),
      ]);
    });

    test('a field with no colon is that field with an empty value', () async {
      // "data" alone is an empty data line: dispatches an event with "".
      expect(await parseText('data\n\n'), [ev('message', '')]);
    });

    test('an empty data value still dispatches', () async {
      expect(await parseText('event: done\ndata:\n\n'), [ev('done', '')]);
    });

    test('a blank line with no data dispatches nothing (and resets the '
        'event name)', () async {
      expect(
        await parseText('event: orphan\n\ndata: x\n\n'),
        [ev('message', 'x')],
        reason: 'the orphan event name must not leak onto the next event',
      );
    });

    test('unknown fields are ignored', () async {
      expect(await parseText('foo: bar\nevent: a\ndata: 1\n\n'), [
        ev('a', '1'),
      ]);
    });

    test('id persists across events; retry parses only digits', () async {
      expect(await parseText('id: 7\nretry: 3000\ndata: a\n\ndata: b\n\n'), [
        ev('message', 'a', id: '7', retry: 3000),
        ev('message', 'b', id: '7'),
      ]);
      expect(await parseText('retry: soon\ndata: a\n\n'), [ev('message', 'a')]);
    });

    test('an id containing NUL is ignored', () async {
      expect(await parseText('id: a\u0000b\ndata: x\n\n'), [
        ev('message', 'x'),
      ]);
    });

    test('a leading byte-order mark is ignored', () async {
      expect(
        await parse([
          [0xEF, 0xBB, 0xBF],
          utf8.encode('data: x\n\n'),
        ]),
        [ev('message', 'x')],
      );
    });
  });

  group('truncated streams', () {
    test('an event without its terminating blank line is discarded, not '
        'delivered half-formed', () async {
      expect(
        await parseText(
          'event: token\ndata: {"text": "a"}\n\n'
          'event: token\ndata: {"text": "b',
        ),
        [ev('token', '{"text": "a"}')],
      );
    });

    test(
      'data fully received but the blank line never came: discarded',
      () async {
        expect(await parseText('event: done\ndata: {}\n'), isEmpty);
      },
    );

    test('an empty stream yields nothing', () async {
      expect(await parse([]), isEmpty);
    });
  });

  group('malformed bytes and errors', () {
    test('invalid UTF-8 becomes U+FFFD instead of throwing', () async {
      final events = await parse([
        [...utf8.encode('data: a'), 0xFF, ...utf8.encode('b\n\n')],
      ]);
      expect(events.single.data, 'a�b');
    });

    test(
      'an error in the byte stream surfaces after the events before it',
      () async {
        final controller = StreamController<List<int>>();
        final seen = <SseEvent>[];
        final done = Completer<Object>();
        parseSse(controller.stream).listen(
          seen.add,
          onError: done.complete,
          onDone: () => done.complete('done'),
        );
        controller.add(utf8.encode('data: 1\n\n'));
        await Future<void>.delayed(Duration.zero);
        controller.addError(StateError('connection reset'));

        expect(await done.future, isA<StateError>());
        expect(seen, [ev('message', '1')]);
      },
    );

    test('cancelling the subscription cancels the byte stream', () async {
      var cancelled = false;
      final controller = StreamController<List<int>>(
        onCancel: () => cancelled = true,
      );
      final sub = parseSse(controller.stream).listen((_) {});
      controller.add(utf8.encode('data: 1\n\n'));
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();

      expect(cancelled, isTrue, reason: 'the HTTP connection must be released');
    });
  });
}
