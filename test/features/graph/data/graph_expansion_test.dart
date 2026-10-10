// Expanding a node into its chunks: the interaction model, loading and
// failure, stale answers, and where the satellites are laid out.
import 'dart:async';
import 'dart:math' as math;

import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/graph/data/graph_api.dart';
import 'package:cerebro_mobile/features/graph/data/graph_expansion.dart';
import 'package:cerebro_mobile/features/graph/data/graph_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ChunkSatellite _c(String id, {int ordinal = 0, String content = 'text'}) =>
    ChunkSatellite(id: id, ordinal: ordinal, content: content);

List<ChunkSatellite> _many(String prefix, int n) => [
  for (var i = 0; i < n; i++) _c('$prefix$i', ordinal: i),
];

class _Api implements GraphApi {
  final rows = <String, List<ChunkSatellite>>{};
  final gates = <String, Completer<void>>{};
  final errors = <String, Object>{};
  final calls = <String>[];

  @override
  Future<List<ChunkSatellite>> chunks(String documentId) async {
    calls.add(documentId);
    await gates[documentId]?.future;
    final e = errors[documentId];
    if (e != null) throw e;
    return rows[documentId] ?? const [];
  }

  @override
  Future<List<GraphNodeData>> nodes() async => const [];
  @override
  Future<List<GraphEdgeData>> edges() async => const [];
}

({ProviderContainer c, _Api api}) _setup({String? user = 'u1'}) {
  final api = _Api();
  final c = ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWithValue(user),
      graphApiProvider.overrideWithValue(api),
    ],
  );
  addTearDown(c.dispose);
  c.listen(graphExpansionProvider, (_, _) {});
  return (c: c, api: api);
}

GraphExpansion _s(ProviderContainer c) => c.read(graphExpansionProvider);
GraphExpansionController _ctl(ProviderContainer c) =>
    c.read(graphExpansionProvider.notifier);

void main() {
  group('the interaction model: one node expanded at a time', () {
    test('starts with nothing expanded', () {
      final (:c, api: _) = _setup();
      expect(_s(c).isExpanded, isFalse);
      expect(_s(c).nodeId, isNull);
    });

    test('tapping a node expands it and loads its chunks', () async {
      final (:c, :api) = _setup();
      api.rows['a'] = _many('a', 3);

      final tap = _ctl(c).toggle('a');
      expect(_s(c).nodeId, 'a');
      expect(_s(c).load, ChunkLoad.loading);
      await tap;

      expect(_s(c).load, ChunkLoad.loaded);
      expect(_s(c).chunks.map((x) => x.id), ['a0', 'a1', 'a2']);
      expect(api.calls, ['a']);
    });

    test('tapping the expanded node collapses it', () async {
      final (:c, :api) = _setup();
      api.rows['a'] = _many('a', 2);
      await _ctl(c).toggle('a');

      await _ctl(c).toggle('a');
      expect(_s(c).isExpanded, isFalse);
      expect(_s(c).chunks, isEmpty);
    });

    test('tapping a different node collapses the first and expands the '
        'second — never two at once', () async {
      final (:c, :api) = _setup();
      api.rows['a'] = _many('a', 2);
      api.rows['b'] = _many('b', 5);
      await _ctl(c).toggle('a');

      final tap = _ctl(c).toggle('b');
      expect(_s(c).nodeId, 'b', reason: 'a is still expanded');
      expect(_s(c).chunks, isEmpty, reason: "a's chunks linger under b");
      await tap;

      expect(_s(c).nodeId, 'b');
      expect(_s(c).chunks.map((x) => x.id), [
        for (var i = 0; i < 5; i++) 'b$i',
      ]);
    });

    test('collapse() with nothing expanded is harmless', () {
      final (:c, api: _) = _setup();
      _ctl(c).collapse();
      expect(_s(c).isExpanded, isFalse);
    });
  });

  group('chunks', () {
    test('a document with no chunks (a sealed one) expands to an empty, '
        'loaded state — not an error', () async {
      final (:c, api: _) = _setup();
      await _ctl(c).toggle('sealed');
      expect(_s(c).load, ChunkLoad.loaded);
      expect(_s(c).chunks, isEmpty);
      expect(_s(c).error, isNull);
    });

    test('only the first $maxSatellites are drawn, and the rest are '
        'reported', () async {
      final (:c, :api) = _setup();
      api.rows['big'] = _many('k', 166);
      await _ctl(c).toggle('big');

      expect(_s(c).chunks, hasLength(166), reason: 'the panel lists all');
      expect(_s(c).shown, hasLength(maxSatellites));
      expect(_s(c).shown.first.id, 'k0');
      expect(_s(c).isTruncated, isTrue);
    });

    test('exactly the cap is not truncated', () async {
      final (:c, :api) = _setup();
      api.rows['d'] = _many('k', maxSatellites);
      await _ctl(c).toggle('d');
      expect(_s(c).isTruncated, isFalse);
      expect(_s(c).shown, hasLength(maxSatellites));
    });

    test('selecting a chunk highlights it; again clears it; a stranger is '
        'ignored', () async {
      final (:c, :api) = _setup();
      api.rows['a'] = _many('a', 3);
      await _ctl(c).toggle('a');

      _ctl(c).selectChunk('a1');
      expect(_s(c).selectedChunk?.id, 'a1');
      _ctl(c).selectChunk('a2');
      expect(_s(c).selectedChunk?.id, 'a2');
      _ctl(c).selectChunk('a2');
      expect(_s(c).selectedChunkId, isNull);
      _ctl(c).selectChunk('not-a-chunk');
      expect(_s(c).selectedChunkId, isNull);
    });

    test('collapsing clears the selection', () async {
      final (:c, :api) = _setup();
      api.rows['a'] = _many('a', 3);
      await _ctl(c).toggle('a');
      _ctl(c).selectChunk('a1');

      _ctl(c).collapse();
      await _ctl(c).toggle('a');
      expect(_s(c).selectedChunkId, isNull);
    });

    test('nothing can be selected while loading', () {
      final (:c, :api) = _setup();
      api.gates['a'] = Completer<void>();
      _ctl(c).toggle('a');
      _ctl(c).selectChunk('a0');
      expect(_s(c).selectedChunkId, isNull);
    });
  });

  group('failure and retry', () {
    test(
      'a failed load is reported with its reason, and retry recovers',
      () async {
        final (:c, :api) = _setup();
        api.errors['a'] = const NetworkUnreachableException();
        await _ctl(c).toggle('a');
        expect(_s(c).load, ChunkLoad.failed);
        expect(_s(c).error, isA<NetworkUnreachableException>());
        expect(_s(c).nodeId, 'a', reason: 'the node stays expanded');

        api.errors.remove('a');
        api.rows['a'] = _many('a', 2);
        await _ctl(c).retry();
        expect(_s(c).load, ChunkLoad.loaded);
        expect(_s(c).chunks, hasLength(2));
      },
    );

    test('an unexpected error is still a user-facing one', () async {
      final (:c, :api) = _setup();
      api.errors['a'] = StateError('boom');
      await _ctl(c).toggle('a');
      expect(_s(c).error, isA<UnknownApiException>());
    });

    test('a document that is gone says not_found', () async {
      final (:c, :api) = _setup();
      api.errors['a'] = const RequestRejectedException('x', code: 'not_found');
      await _ctl(c).toggle('a');
      final e = _s(c).error;
      expect(e, isA<RequestRejectedException>());
      expect((e! as RequestRejectedException).code, 'not_found');
    });

    test('retry does nothing unless the load failed', () async {
      final (:c, :api) = _setup();
      api.rows['a'] = _many('a', 2);
      await _ctl(c).toggle('a');
      await _ctl(c).retry();
      expect(api.calls, ['a'], reason: 'retried a successful load');

      _ctl(c).collapse();
      await _ctl(c).retry();
      expect(api.calls, ['a']);
    });
  });

  group('stale answers', () {
    test("a slow answer for a node the user left never lands in the next "
        "node's chunks", () async {
      final (:c, :api) = _setup();
      api.rows['slow'] = _many('slow', 4);
      api.rows['fast'] = _many('fast', 2);
      api.gates['slow'] = Completer<void>();

      final first = _ctl(c).toggle('slow');
      await _ctl(c).toggle('fast');
      expect(_s(c).chunks.map((x) => x.id), ['fast0', 'fast1']);

      api.gates['slow']!.complete();
      await first;
      expect(_s(c).nodeId, 'fast');
      expect(_s(c).chunks.map((x) => x.id), ['fast0', 'fast1']);
    });

    test(
      'a slow answer after the node was collapsed does not re-expand it',
      () async {
        final (:c, :api) = _setup();
        api.rows['a'] = _many('a', 2);
        api.gates['a'] = Completer<void>();

        final tap = _ctl(c).toggle('a');
        _ctl(c).collapse();
        api.gates['a']!.complete();
        await tap;
        expect(_s(c).isExpanded, isFalse);
      },
    );

    test(
      'a slow failure for an abandoned node does not show an error',
      () async {
        final (:c, :api) = _setup();
        api.gates['slow'] = Completer<void>();
        api.errors['slow'] = const NetworkUnreachableException();
        api.rows['fast'] = _many('fast', 1);

        final first = _ctl(c).toggle('slow');
        await _ctl(c).toggle('fast');
        api.gates['slow']!.complete();
        await first;
        expect(_s(c).load, ChunkLoad.loaded);
        expect(_s(c).error, isNull);
      },
    );

    test('a new user starts with nothing expanded', () async {
      final api = _Api()..rows['a'] = _many('a', 2);
      final user = StateProvider<String?>((_) => 'u1');
      final c = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => ref.watch(user)),
          graphApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(c.dispose);
      c.listen(graphExpansionProvider, (_, _) {});
      await _ctl(c).toggle('a');
      expect(_s(c).isExpanded, isTrue);

      c.read(user.notifier).state = 'u2';
      expect(_s(c).isExpanded, isFalse);
    });
  });

  group('satelliteOffsets', () {
    test('as many as asked for, never more than the cap', () {
      expect(satelliteOffsets(0), isEmpty);
      expect(satelliteOffsets(1), hasLength(1));
      expect(satelliteOffsets(16), hasLength(16));
      expect(satelliteOffsets(17), hasLength(17));
      expect(satelliteOffsets(64), hasLength(64));
      expect(satelliteOffsets(500), hasLength(maxSatellites));
    });

    test('deterministic', () {
      final a = satelliteOffsets(40);
      final b = satelliteOffsets(40);
      expect([for (final p in a) (p.x, p.y)], [for (final p in b) (p.x, p.y)]);
    });

    test('no two satellites sit closer than a dot and a half apart, at any '
        'count', () {
      for (final n in [1, 2, 5, 16, 17, 36, 37, 64]) {
        final offs = satelliteOffsets(n);
        var closest = double.infinity;
        for (var i = 0; i < offs.length; i++) {
          for (var j = i + 1; j < offs.length; j++) {
            closest = math.min(closest, offs[i].distanceTo(offs[j]));
          }
        }
        if (offs.length > 1) {
          expect(closest, greaterThan(20), reason: '$n satellites overlap');
        }
      }
    });

    test('all clear of the node itself, and inside the outer ring', () {
      for (final p in satelliteOffsets(64)) {
        expect(p.length, greaterThan(50), reason: 'on top of the node');
        expect(p.length, lessThanOrEqualTo(150 + 1e-3));
      }
    });

    test('fills from the inside out', () {
      final offs = satelliteOffsets(30);
      final inner = offs.take(16).map((p) => p.length);
      final outer = offs.skip(16).map((p) => p.length);
      expect(inner.every((r) => (r - 70).abs() < 1e-3), isTrue);
      expect(outer.every((r) => (r - 110).abs() < 1e-3), isTrue);
    });
  });

  group('ChunkSatellite.fromJson', () {
    test('a PDF chunk', () {
      final c = ChunkSatellite.fromJson({
        'id': 'c1',
        'ordinal': 3,
        'content': 'Hello',
        'meta': {'page': 2, 'region_type': 'paragraph', 'bbox': null},
      })!;
      expect(
        (c.id, c.ordinal, c.content, c.page, c.regionType),
        ('c1', 3, 'Hello', 2, 'paragraph'),
      );
    });

    test('odd or missing fields degrade, unusable rows are skipped', () {
      expect(ChunkSatellite.fromJson('x'), isNull);
      expect(ChunkSatellite.fromJson({'content': 'no id'}), isNull);
      expect(ChunkSatellite.fromJson({'id': ''}), isNull);
      final c = ChunkSatellite.fromJson({
        'id': 'c',
        'content': 5,
        'ordinal': 'x',
        'meta': 'nope',
      })!;
      expect((c.content, c.ordinal, c.page, c.regionType), ('', 0, null, null));
    });

    test('preview: one line, cut, and a stand-in for no text', () {
      expect(_c('a', content: '  a\n\n b\tc  ').preview(), 'a b c');
      expect(_c('a', content: '').preview(), '(no text)');
      expect(_c('a', content: '   \n ').preview(), '(no text)');
      final long = 'word ' * 100;
      final p = _c('a', content: long).preview(20);
      expect(p.length, lessThanOrEqualTo(21));
      expect(p, endsWith('…'));
      expect(_c('a', content: 'short').preview(20), 'short');
    });
  });
}
