// Expanding a node into its chunks, on screen — and the pan and pinch-zoom
// gestures. Real gestures at the painted positions, against a fake API.
import 'dart:async';

import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/graph/data/graph_api.dart';
import 'package:cerebro_mobile/features/graph/data/graph_models.dart';
import 'package:cerebro_mobile/features/graph/presentation/graph_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_force_directed_graph/flutter_force_directed_graph.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

GraphNodeData _n(
  String id, {
  String? title,
  double x = 0,
  double y = 0,
  String status = 'ready',
  String mime = 'text/plain',
}) => GraphNodeData(
  id: id,
  title: title ?? id,
  x: x,
  y: y,
  mime: mime,
  status: status,
  clusterId: 'c',
);

DocumentChunk _c(String id, {String? content, int? page, String? region}) =>
    DocumentChunk(
      id: id,
      ordinal: 0,
      content: content ?? 'text of $id',
      page: page,
      regionType: region,
    );

List<DocumentChunk> _many(String p, int n) => [
  for (var i = 0; i < n; i++) _c('$p$i'),
];

class _Api implements GraphApi {
  List<GraphNodeData> nodeRows = [];
  final chunkRows = <String, List<DocumentChunk>>{};
  final gates = <String, Completer<void>>{};
  Object? chunksError;
  final calls = <String>[];

  @override
  Future<List<GraphNodeData>> nodes() async => List.of(nodeRows);
  @override
  Future<List<GraphEdgeData>> edges() async => const [];
  @override
  Future<List<DocumentChunk>> chunks(String documentId) async {
    calls.add(documentId);
    await gates[documentId]?.future;
    if (chunksError != null) throw chunksError!;
    return chunkRows[documentId] ?? const [];
  }
}

Future<void> _frames(WidgetTester tester, [int n = 4]) async {
  await tester.pump();
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Api api, {
  List<String>? opened,
}) async {
  if (tester.view.physicalSize / tester.view.devicePixelRatio ==
      const Size(800, 600)) {
    tester.view.physicalSize =
        const Size(400, 800) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('u1'),
        graphApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: GraphScreen(openDocument: (_, id) => opened?.add(id)),
      ),
    ),
  );
  await _frames(tester);
}

ForceDirectedGraphController<String> _controller(WidgetTester tester) => tester
    .widget<ForceDirectedGraphWidget<String>>(
      find.byKey(const Key('graph_canvas')),
    )
    .controller;

Node<String> _node(WidgetTester tester, String data) =>
    _controller(tester).graph.nodes.firstWhere((n) => n.data == data);

/// Where a node is painted: the view's middle plus its position, scaled, with
/// y up.
Offset _screenOf(WidgetTester tester, String data) {
  final c = _controller(tester);
  final n = _node(tester, data);
  final middle = tester.getCenter(find.byKey(const Key('graph_canvas')));
  return middle + Offset(n.position.x, -n.position.y) * c.scale;
}

Future<void> _tapNode(WidgetTester tester, String id) async {
  await tester.tapAt(_screenOf(tester, id));
  await _frames(tester);
}

Finder get _panel => find.byKey(const Key('node_panel'));

void main() {
  late _Api api;

  /// Nodes on the canvas beyond the documents — chunks are listed in the
  /// panel, never drawn on the graph, so this is always 0.
  int extra(WidgetTester t) =>
      _controller(t).graph.nodes.length - api.nodeRows.length;

  setUp(() {
    api = _Api()
      ..nodeRows = [
        _n('a', title: 'Alpha', x: -1),
        _n('b', title: 'Beta', x: 0),
        _n('c', title: 'Gamma', x: 1),
      ]
      ..chunkRows['a'] = _many('a', 5)
      ..chunkRows['b'] = _many('b', 3)
      ..chunkRows['c'] = const [];
  });

  group('expanding', () {
    testWidgets('tapping a node expands it: its panel and its chunk list — '
        'nothing is drawn on the graph', (tester) async {
      await _pump(tester, api);
      expect(_panel, findsNothing);

      await _tapNode(tester, 'a');

      expect(_panel, findsOneWidget);
      expect(find.text('Alpha'), findsWidgets);
      expect(find.byKey(const Key('node_chunk_count')), findsOneWidget);
      expect(find.text('5 chunks'), findsOneWidget);
      // The list builds rows lazily, so only the first few exist.
      expect(find.byKey(const Key('node_chunk_a0')), findsOneWidget);
      expect(find.byKey(const Key('node_chunk_a1')), findsOneWidget);
      expect(extra(tester), 0, reason: 'chunks were drawn on the canvas');
      expect(_controller(tester).graph.edges, isEmpty);
      expect(api.calls, ['a']);
    });

    testWidgets('shows loading, then the chunks', (tester) async {
      api.gates['a'] = Completer<void>();
      await _pump(tester, api);
      await _tapNode(tester, 'a');
      expect(find.byKey(const Key('node_loading')), findsOneWidget);
      expect(find.byKey(const Key('node_chunk_a0')), findsNothing);

      api.gates['a']!.complete();
      await _frames(tester);
      expect(find.byKey(const Key('node_loading')), findsNothing);
      expect(find.byKey(const Key('node_chunk_a0')), findsOneWidget);
    });

    testWidgets('tapping the expanded node collapses it', (tester) async {
      await _pump(tester, api);
      await _tapNode(tester, 'a');
      expect(find.byKey(const Key('node_chunk_a0')), findsOneWidget);

      await _tapNode(tester, 'a');
      expect(_panel, findsNothing);
      expect(find.byKey(const Key('node_chunk_a0')), findsNothing);
    });

    testWidgets('tapping a different node collapses the first and expands '
        'the second — while the panel is open', (tester) async {
      await _pump(tester, api);
      await _tapNode(tester, 'a');
      expect(find.byKey(const Key('node_chunk_a0')), findsOneWidget);

      await _tapNode(tester, 'b');
      expect(
        find.byKey(const Key('node_chunk_a0')),
        findsNothing,
        reason: "a's chunks are still listed",
      );
      expect(find.byKey(const Key('node_chunk_b0')), findsOneWidget);
      expect(
        find.descendant(of: _panel, matching: find.text('Beta')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _panel, matching: find.text('Alpha')),
        findsNothing,
      );
    });

    testWidgets("the panel's close button collapses", (tester) async {
      await _pump(tester, api);
      await _tapNode(tester, 'a');
      await tester.tap(find.byKey(const Key('node_close')));
      await _frames(tester);
      expect(_panel, findsNothing);
      expect(extra(tester), 0);
    });

    testWidgets('a sealed document says its chunks are not shown, and draws '
        'none', (tester) async {
      api.nodeRows = [_n('s', title: 'Secret', status: 'sealed')];
      await _pump(tester, api);
      await _tapNode(tester, 's');
      expect(find.byKey(const Key('node_no_chunks')), findsOneWidget);
      expect(find.textContaining('Sealed'), findsOneWidget);
      expect(extra(tester), 0);
    });

    testWidgets('a document with no chunks says so', (tester) async {
      await _pump(tester, api);
      await _tapNode(tester, 'c');
      expect(find.text('This document has no chunks.'), findsOneWidget);
    });

    testWidgets('a document with many chunks lists them all', (tester) async {
      api.chunkRows['a'] = _many('k', 100);
      await _pump(tester, api);
      await _tapNode(tester, 'a');
      expect(find.text('100 chunks'), findsOneWidget);
      expect(find.byKey(const Key('node_chunk_k0')), findsOneWidget);
      expect(extra(tester), 0);
    });

    testWidgets('a refresh that brings a new graph collapses what was '
        'expanded', (tester) async {
      await _pump(tester, api);
      await _tapNode(tester, 'a');
      expect(_panel, findsOneWidget);

      api.nodeRows = [..._rowsPlus(api.nodeRows)];
      await tester.tap(find.byKey(const Key('graph_refresh')));
      await _frames(tester, 6);
      expect(_panel, findsNothing);
      expect(extra(tester), 0);
    });
  });

  group('failure', () {
    testWidgets('a failed load says why and Retry loads the chunks', (
      tester,
    ) async {
      api.chunksError = const NetworkUnreachableException();
      await _pump(tester, api);
      await _tapNode(tester, 'a');
      expect(find.byKey(const Key('node_chunks_error')), findsOneWidget);
      expect(extra(tester), 0);

      api.chunksError = null;
      await tester.tap(find.byKey(const Key('node_retry')));
      await _frames(tester);
      expect(find.byKey(const Key('node_chunks_error')), findsNothing);
      expect(find.byKey(const Key('node_chunk_a0')), findsOneWidget);
    });

    testWidgets('a document that is gone says so, with no pointless retry', (
      tester,
    ) async {
      api.chunksError = const RequestRejectedException('x', code: 'not_found');
      await _pump(tester, api);
      await _tapNode(tester, 'a');
      expect(find.textContaining('no longer exists'), findsOneWidget);
      expect(find.byKey(const Key('node_retry')), findsNothing);
    });
  });

  group('chunks', () {
    testWidgets('tapping a chunk selects it: its text and where it is from in '
        'the panel; tapping it again clears it', (tester) async {
      api.chunkRows['a'] = [
        _c('a0', content: 'The first passage.', page: 2, region: 'paragraph'),
        _c('a1', content: 'The second passage.'),
      ];
      await _pump(tester, api);
      await _tapNode(tester, 'a');
      expect(find.byKey(const Key('node_selected_chunk')), findsNothing);

      await tester.tap(find.byKey(const Key('node_chunk_a0')));
      await _frames(tester);
      expect(find.byKey(const Key('node_selected_chunk')), findsOneWidget);
      expect(find.text('The first passage.'), findsWidgets);
      expect(find.text('Page 2 · paragraph'), findsWidgets);

      await tester.tap(find.byKey(const Key('node_chunk_a0')));
      await _frames(tester);
      expect(find.byKey(const Key('node_selected_chunk')), findsNothing);
    });

    testWidgets('tapping a row in the list selects that chunk too', (
      tester,
    ) async {
      api.chunkRows['a'] = [_c('a0'), _c('a1', content: 'Second one.')];
      await _pump(tester, api);
      await _tapNode(tester, 'a');
      await tester.tap(find.byKey(const Key('node_chunk_a1')));
      await _frames(tester);
      expect(find.byKey(const Key('node_selected_chunk')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('node_selected_chunk')),
          matching: find.text('Second one.'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a huge chunk is cut for display and says how long it is', (
      tester,
    ) async {
      api.chunkRows['a'] = [_c('a0', content: 'x' * 37351)];
      await _pump(tester, api);
      await _tapNode(tester, 'a');
      await tester.tap(find.byKey(const Key('node_chunk_a0')));
      await _frames(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('node_chunk_cut')), findsOneWidget);
      expect(find.textContaining('37351 characters'), findsOneWidget);
    });

    testWidgets('a chunk with no text shows a stand-in, not a blank', (
      tester,
    ) async {
      api.chunkRows['a'] = [_c('a0', content: '')];
      await _pump(tester, api);
      await _tapNode(tester, 'a');
      expect(find.text('(no text)'), findsOneWidget);
    });

    testWidgets('the document stays reachable: Open in Documents', (
      tester,
    ) async {
      final opened = <String>[];
      await _pump(tester, api, opened: opened);
      await _tapNode(tester, 'b');
      await tester.tap(find.byKey(const Key('node_open')));
      await _frames(tester);
      expect(opened, ['b']);
    });
  });

  group('the view', () {
    testWidgets('an expanded node is brought above its panel, even one tapped '
        'low on the screen', (tester) async {
      api.nodeRows = [_n('top', x: 0, y: 1), _n('low', x: 0.5, y: -1)];
      api.chunkRows['low'] = _many('l', 4);
      await _pump(tester, api);
      final height =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(_screenOf(tester, 'low').dy, greaterThan(height * 0.5));

      await _tapNode(tester, 'low');
      expect(_panel, findsOneWidget);
      expect(
        _screenOf(tester, 'low').dy,
        lessThan(height * 0.5),
        reason: 'the node is hidden behind its own panel',
      );
      final panelTop = tester.getTopLeft(_panel).dy;
      expect(_screenOf(tester, 'low').dy, lessThan(panelTop));
    });

    testWidgets('on a small phone (360×640), a selected chunk gives way '
        'instead of overflowing the panel or squeezing the list out', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      api.chunkRows['b'] = [
        for (var i = 0; i < 6; i++) _c('k$i', content: 'long text ' * 80),
      ];
      await _pump(tester, api);
      await _tapNode(tester, 'b');
      await tester.tap(find.byKey(const Key('node_chunk_k0')));
      await _frames(tester);

      expect(tester.takeException(), isNull, reason: 'the panel overflowed');
      expect(find.byKey(const Key('node_selected_chunk')), findsOneWidget);
      expect(tester.getSize(_panel).height, lessThanOrEqualTo(640 * 0.5 + 1));
      // The list is still there to use, not squeezed out by the selection.
      expect(
        tester.getSize(find.byKey(const Key('node_panel'))).height,
        greaterThanOrEqualTo(60),
      );
    });

    testWidgets('a status-bar inset does not leave a gap above the chunk '
        'list', (tester) async {
      // A ListView pads its top by the system inset unless told not to; seen
      // on a real phone as a blank band above the first row.
      tester.view.padding = const FakeViewPadding(top: 120);
      addTearDown(tester.view.resetPadding);
      await _pump(tester, api);
      await _tapNode(tester, 'b');

      final count = tester.getBottomLeft(
        find.byKey(const Key('node_chunk_count')),
      );
      final firstRow = tester.getTopLeft(
        find.byKey(const Key('node_chunk_b0')),
      );
      expect(
        firstRow.dy - count.dy,
        lessThan(24),
        reason: 'a blank band above the first chunk',
      );
    });

    testWidgets('the panel never covers more than half the screen', (
      tester,
    ) async {
      api.chunkRows['a'] = [for (var i = 0; i < 40; i++) _c('k$i')];
      await _pump(tester, api);
      await _tapNode(tester, 'a');
      final height =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(
        tester.getSize(_panel).height,
        lessThanOrEqualTo(height * 0.5 + 1),
      );
    });
  });

  group('pan and zoom', () {
    testWidgets('dragging empty space pans every node together', (
      tester,
    ) async {
      await _pump(tester, api);
      final before = {
        for (final n in _controller(tester).graph.nodes)
          n.data: Offset(n.position.x, n.position.y),
      };
      final middle = tester.getCenter(find.byKey(const Key('graph_canvas')));
      // A drag of N screen pixels moves the layout N / scale units.
      final scale = _controller(tester).scale;

      // Empty space: well below the row of nodes, above the ask bar.
      final gesture = await tester.startGesture(middle + const Offset(0, 140));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await gesture.up();
      await _frames(tester);

      for (final n in _controller(tester).graph.nodes) {
        final was = before[n.data]!;
        expect(
          n.position.x - was.dx,
          closeTo(60 / scale, 1e-3),
          reason: n.data,
        );
        expect(
          n.position.y - was.dy,
          closeTo(-30 / scale, 1e-3),
          reason: n.data,
        );
      }
      expect(_panel, findsNothing, reason: 'a pan is not a tap');
    });

    testWidgets('pinching out zooms in, pinching in zooms out, and both stop '
        'at their limits', (tester) async {
      await _pump(tester, api);
      final c = _controller(tester);
      final middle = tester.getCenter(find.byKey(const Key('graph_canvas')));
      // Opens fitted to the view, not at 1.0.
      expect(c.scale, inInclusiveRange(0.3, 1.5));
      final fittedScale = c.scale;

      // Above the legend (bottom left), which would swallow a touch.
      Future<void> pinch(double from, double to) async {
        final a = await tester.startGesture(middle + Offset(-from, -60));
        final b = await tester.startGesture(middle + Offset(from, -60));
        for (var i = 1; i <= 8; i++) {
          final d = from + (to - from) * i / 8;
          await a.moveTo(middle + Offset(-d, -60));
          await b.moveTo(middle + Offset(d, -60));
          await tester.pump();
        }
        await a.up();
        await b.up();
        await _frames(tester);
      }

      await pinch(40, 80);
      expect(
        c.scale,
        greaterThan(fittedScale),
        reason: 'pinch out did not zoom in',
      );
      final zoomedIn = c.scale;

      await pinch(40, 60);
      expect(c.scale, greaterThanOrEqualTo(zoomedIn));
      await pinch(30, 190);
      expect(c.scale, lessThanOrEqualTo(3.0 + 1e-9), reason: 'no upper limit');

      await pinch(190, 20);
      await pinch(190, 20);
      expect(
        c.scale,
        greaterThanOrEqualTo(0.3 - 1e-9),
        reason: 'no lower limit',
      );
      expect(c.scale, lessThan(1.0));
    });

    testWidgets('a node still taps after panning and zooming', (tester) async {
      await _pump(tester, api);
      final c = _controller(tester);
      c.scale = 1.7;
      await _frames(tester);
      final middle = tester.getCenter(find.byKey(const Key('graph_canvas')));
      final gesture = await tester.startGesture(middle + const Offset(0, 140));
      await gesture.moveBy(const Offset(25, 0));
      await tester.pump();
      await gesture.up();
      await _frames(tester);

      await _tapNode(tester, 'b');
      expect(find.byKey(const Key('node_panel')), findsOneWidget);
      expect(find.text('3 chunks'), findsOneWidget);
    });
  });
}

List<GraphNodeData> _rowsPlus(List<GraphNodeData> rows) => [
  ...rows,
  _n('d', title: 'Delta', x: 0.5),
];
