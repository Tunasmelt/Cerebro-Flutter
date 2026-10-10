import 'package:flutter/material.dart';
import 'package:flutter_force_directed_graph/flutter_force_directed_graph.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import '../../../app/app_routes.dart';
import '../../../core/network/app_exception.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../../../shared/widgets/error_view.dart';
import '../data/graph_api.dart';
import '../data/graph_expansion.dart';
import '../data/graph_layout.dart';
import '../data/graph_models.dart';
import 'models/graph_node.dart';
import 'widgets/graph_ask_bar.dart';
import 'widgets/graph_legend.dart';
import 'widgets/graph_node_dot.dart';
import 'widgets/graph_search_bar.dart';
import 'widgets/node_info_panel.dart';

/// Prefix on the package-graph id of a chunk satellite, so it can never be
/// mistaken for a document's id.
const String _chunkPrefix = 'chunk:';

/// What share of the screen's height the node panel may cover; an expanded
/// node is brought into the part above it.
const double _panelShare = 0.5;

/// The brain graph — Cerebro's 2D, deliberately-not-3D visual index of a
/// user's vault (architecture-and-spec.md §5, CLAUDE.md "2D graph is a
/// deliberate choice").
///
/// Draws the real `/graph/nodes` and `/graph/edges` with
/// `flutter_force_directed_graph`. The layout is the server's (see
/// [buildForceGraph]); this screen only renders it. Tapping a node expands it
/// into its chunks (see [GraphExpansion]); pan and pinch-zoom are the
/// package's own gestures.
class GraphScreen extends ConsumerStatefulWidget {
  const GraphScreen({super.key, this.openDocument});

  /// How "Open in Documents" opens a document. Defaults to the app router;
  /// overridable so the screen can be tested without one.
  final void Function(BuildContext context, String documentId)? openDocument;

  @override
  ConsumerState<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends ConsumerState<GraphScreen> {
  final _searchController = TextEditingController();
  final _askController = TextEditingController();

  String _query = '';
  bool _showLegend = true;

  /// The package's graph for [_builtFrom]; rebuilt only when a new snapshot
  /// arrives, never on every frame.
  ForceDirectedGraphController<String>? _controller;
  GraphSnapshot? _builtFrom;

  /// What is currently drawn as satellites (see [_syncSatellites]), and where
  /// each sits relative to its document.
  String? _satelliteSignature;
  final Map<Node<String>, Vector2> _satelliteOffsets = {};

  @override
  void dispose() {
    _searchController.dispose();
    _askController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  /// The package's origin is the middle of the view, but it only builds the
  /// nodes inside the area it has measured — which it learns during the first
  /// layout and never revisits unless something moves (ours are static).
  /// Centering the graph once after the first frame both puts its middle in
  /// the middle of the view and makes the package re-measure and build every
  /// node.
  ForceDirectedGraphController<String> _controllerFor(GraphSnapshot snapshot) {
    if (!identical(snapshot, _builtFrom)) {
      _controller?.dispose();
      final controller = ForceDirectedGraphController<String>(
        graph: buildForceGraph(snapshot),
        minScale: 0.3,
        maxScale: 3,
      );
      _controller = controller;
      _builtFrom = snapshot;
      _satelliteSignature = null;
      _satelliteOffsets.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !identical(_controller, controller)) return;
        controller.center();
        // A fresh graph has nothing expanded.
        ref.read(graphExpansionProvider.notifier).collapse();
      });
    }
    return _controller!;
  }

  /// The package un-fixes every node whenever one is touched, which starts its
  /// physics: with no centering force the documents repel each other and
  /// scatter off the screen, destroying the server's layout. Re-fixing them in
  /// the drag callbacks (which the package calls right after it un-fixes) keeps
  /// the layout where the server put it; a dragged node simply stays where it
  /// is dropped.
  void _keepLayoutStatic() {
    final controller = _controller;
    if (controller == null) return;
    for (final node in controller.graph.nodes) {
      node.static();
    }
  }

  /// A dragged document leaves its satellites behind; when it is dropped they
  /// are put back around it.
  void _dragEnded(String data) {
    _keepLayoutStatic();
    final controller = _controller;
    final expanded = ref.read(graphExpansionProvider).nodeId;
    if (controller == null || expanded == null || data != expanded) return;
    final parent = _nodeFor(controller, expanded);
    if (parent == null) return;
    _satelliteOffsets.forEach((node, offset) {
      node.position = parent.position + offset;
    });
    controller.needUpdate();
  }

  Node<String>? _nodeFor(ForceDirectedGraphController<String> c, String id) {
    for (final n in c.graph.nodes) {
      if (n.data == id) return n;
    }
    return null;
  }

  /// Makes the package's graph show [exp]'s chunks as satellites around the
  /// expanded document: removes whatever satellites there were, then adds one
  /// static node per drawn chunk, linked to the document.
  void _syncSatellites(GraphExpansion exp) {
    final controller = _controller;
    if (controller == null) return;
    final drawn = exp.load == ChunkLoad.loaded
        ? exp.shown
        : const <ChunkSatellite>[];
    final signature = exp.nodeId == null || drawn.isEmpty
        ? null
        : '${exp.nodeId}|${drawn.length}|${drawn.first.id}|${drawn.last.id}';
    if (signature == _satelliteSignature) return;
    _satelliteSignature = signature;

    final graph = controller.graph;
    graph.edges.removeWhere(
      (e) =>
          e.a.data.startsWith(_chunkPrefix) ||
          e.b.data.startsWith(_chunkPrefix),
    );
    graph.nodes.removeWhere((n) => n.data.startsWith(_chunkPrefix));
    _satelliteOffsets.clear();

    final parent = signature == null ? null : _nodeFor(controller, exp.nodeId!);
    if (parent != null) {
      final offsets = satelliteOffsets(drawn.length);
      for (var i = 0; i < drawn.length; i++) {
        final offset = offsets[i];
        final node = Node<String>(
          '$_chunkPrefix${drawn[i].id}',
          parent.position + offset,
        )..static();
        graph.addNode(node);
        graph.addEdge(Edge(parent, node));
        _satelliteOffsets[node] = offset;
      }
    }
    controller.needUpdate();
  }

  /// Brings [id] into the part of the view the panel will not cover, so a
  /// node tapped low on the screen is not hidden by its own panel.
  void _bringIntoView(String id) {
    final controller = _controller;
    if (controller == null) return;
    final node = _nodeFor(controller, id);
    if (node == null) return;
    final height = MediaQuery.sizeOf(context).height;
    // The graph's origin is the middle of the view; y points up.
    final visibleMiddle = height * (1 - _panelShare) / 2;
    final targetY = height / 2 - visibleMiddle;
    controller.locateToPosition(node.position.x, node.position.y - targetY);
  }

  bool _matches(GraphNodeData node) =>
      _query.isNotEmpty &&
      node.title.toLowerCase().contains(_query.toLowerCase());

  void _openDocument(String id) {
    final open = widget.openDocument;
    if (open != null) {
      open(context, id);
    } else {
      context.push(AppRoutes.documentDetail(id));
    }
  }

  void _handleAsk(String text) {
    _askController.clear();
    // Routing a question to Chat (pre-filled) is a later milestone.
  }

  @override
  Widget build(BuildContext context) {
    final graph = ref.watch(graphProvider);
    // Keep the last graph on screen while a refresh is in flight.
    final snapshot = graph.valueOrNull;
    final expansion = ref.watch(graphExpansionProvider);

    ref.listen<GraphExpansion>(graphExpansionProvider, (previous, next) {
      _syncSatellites(next);
      final id = next.nodeId;
      if (id != null && id != previous?.nodeId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _bringIntoView(id);
        });
      }
    });

    final byId = {
      if (snapshot != null)
        for (final n in snapshot.nodes) n.id: n,
    };
    final expanded = expansion.nodeId == null ? null : byId[expansion.nodeId];

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          Positioned.fill(child: _body(graph, snapshot, byId, expansion)),
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.s2),
                    Row(
                      children: [
                        Expanded(
                          child: GraphSearchBar(
                            controller: _searchController,
                            query: _query,
                            matchCount: snapshot == null
                                ? 0
                                : snapshot.nodes.where(_matches).length,
                            onChanged: (v) => setState(() => _query = v),
                            onClear: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                        ),
                        IconButton(
                          key: const Key('graph_refresh'),
                          tooltip: 'Refresh',
                          onPressed: graph.isLoading
                              ? null
                              : () =>
                                    ref.read(graphProvider.notifier).refresh(),
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    if (snapshot != null) _Notes(snapshot: snapshot),
                    const Spacer(),
                    if (expanded == null)
                      GraphAskBar(
                        controller: _askController,
                        onAsk: _handleAsk,
                      ),
                    const SizedBox(height: AppSpacing.s2),
                  ],
                ),
              ),
            ),
          ),
          if (_showLegend &&
              expanded == null &&
              snapshot != null &&
              snapshot.nodes.isNotEmpty)
            Positioned(
              left: AppSpacing.s4,
              bottom: AppSpacing.s20,
              child: SafeArea(
                child: GraphLegend(
                  onDismiss: () => setState(() => _showLegend = false),
                ),
              ),
            ),
          if (expanded != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: NodeInfoPanel(
                node: expanded,
                expansion: expansion,
                onClose: ref.read(graphExpansionProvider.notifier).collapse,
                onRetry: ref.read(graphExpansionProvider.notifier).retry,
                onSelectChunk: ref
                    .read(graphExpansionProvider.notifier)
                    .selectChunk,
                // Routing a node to Chat is a later milestone.
                onChatAboutThis: ref
                    .read(graphExpansionProvider.notifier)
                    .collapse,
                onOpenInDocuments: () => _openDocument(expanded.id),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(
    AsyncValue<GraphSnapshot> graph,
    GraphSnapshot? snapshot,
    Map<String, GraphNodeData> byId,
    GraphExpansion expansion,
  ) {
    if (snapshot == null) {
      if (graph.hasError) {
        final error = graph.error;
        return ErrorView(
          key: const Key('graph_error'),
          exception: error is AppException
              ? error
              : const UnknownApiException(),
          expanded: true,
          onRetry: () => ref.invalidate(graphProvider),
        );
      }
      return const Center(
        key: Key('graph_loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (snapshot.nodes.isEmpty) {
      return const Center(
        key: Key('graph_empty'),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.s8),
          child: Text(
            'Your graph is empty. Upload documents and they will appear '
            'here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final toggle = ref.read(graphExpansionProvider.notifier).toggle;
    final selectChunk = ref.read(graphExpansionProvider.notifier).selectChunk;
    final satelliteColor =
        (expansion.nodeId == null ? null : byId[expansion.nodeId])
            ?.type
            .color ??
        AppColors.accentPrimary;
    return ForceDirectedGraphWidget<String>(
      key: const Key('graph_canvas'),
      controller: _controllerFor(snapshot),
      onDraggingUpdate: (_) => _keepLayoutStatic(),
      onDraggingEnd: (data) => _dragEnded(data),
      nodesBuilder: (context, id) {
        if (id.startsWith(_chunkPrefix)) {
          final chunkId = id.substring(_chunkPrefix.length);
          return GraphSatelliteDot(
            chunkId: chunkId,
            color: satelliteColor,
            selected: chunkId == expansion.selectedChunkId,
            onTap: () => selectChunk(chunkId),
          );
        }
        final node = byId[id];
        if (node == null) return const SizedBox.shrink();
        final matched = _matches(node);
        final selected = node.id == expansion.nodeId;
        return GraphNodeDot(
          node: node,
          matched: matched,
          selected: selected,
          dimmed: _query.isNotEmpty && !matched && !selected,
          onTap: () => toggle(node.id),
        );
      },
      edgesBuilder: (context, a, b, distance) => GraphEdgeLine(
        length: distance,
        color: a.startsWith(_chunkPrefix) || b.startsWith(_chunkPrefix)
            ? satelliteColor
            : null,
      ),
    );
  }
}

/// Plain statements about what the graph is showing, only when there is
/// something the user should know.
class _Notes extends StatelessWidget {
  const _Notes({required this.snapshot});

  final GraphSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final notes = <String>[
      if (snapshot.nodes.length > 1 && !snapshot.isClustered)
        'Groups are not computed yet, so documents are spread evenly.',
      if (snapshot.edgesUnavailable)
        "Links between documents couldn't be loaded.",
    ];
    if (notes.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const Key('graph_notes'),
      padding: const EdgeInsets.only(top: AppSpacing.s2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          notes.join(' '),
          style: AppTypography.xs.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
