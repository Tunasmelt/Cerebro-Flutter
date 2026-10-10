import 'package:flutter/material.dart';
import 'package:flutter_force_directed_graph/flutter_force_directed_graph.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/network/app_exception.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../../../shared/widgets/error_view.dart';
import '../data/graph_api.dart';
import '../data/graph_layout.dart';
import '../data/graph_models.dart';
import 'widgets/graph_ask_bar.dart';
import 'widgets/graph_legend.dart';
import 'widgets/graph_node_dot.dart';
import 'widgets/graph_search_bar.dart';
import 'widgets/node_detail_sheet.dart';

/// The brain graph — Cerebro's 2D, deliberately-not-3D visual index of a
/// user's vault (architecture-and-spec.md §5, CLAUDE.md "2D graph is a
/// deliberate choice").
///
/// Draws the real `/graph/nodes` and `/graph/edges` with
/// `flutter_force_directed_graph`. The layout is the server's (see
/// [buildForceGraph]); this screen only renders it.
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
  String? _selectedId;
  bool _showLegend = true;

  /// The package's graph for [_builtFrom]; rebuilt only when a new snapshot
  /// arrives, never on every frame.
  ForceDirectedGraphController<String>? _controller;
  GraphSnapshot? _builtFrom;

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_controller, controller)) controller.center();
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

  bool _matches(GraphNodeData node) =>
      _query.isNotEmpty &&
      node.title.toLowerCase().contains(_query.toLowerCase());

  void _select(GraphNodeData node) {
    setState(() => _selectedId = node.id);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => NodeDetailSheet(
        node: node,
        onChatAboutThis: () => Navigator.of(sheetContext).maybePop(),
        onOpenInDocuments: () {
          Navigator.of(sheetContext).maybePop();
          _openDocument(node.id);
        },
        onZoomOut: () {
          Navigator.of(sheetContext).maybePop();
          setState(() => _selectedId = null);
        },
      ),
    ).whenComplete(() {
      // Deselect once the sheet is dismissed (swipe, scrim tap or button).
      if (mounted) setState(() => _selectedId = null);
    });
  }

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

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          Positioned.fill(child: _body(graph, snapshot)),
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
                    GraphAskBar(controller: _askController, onAsk: _handleAsk),
                    const SizedBox(height: AppSpacing.s2),
                  ],
                ),
              ),
            ),
          ),
          if (_showLegend && snapshot != null && snapshot.nodes.isNotEmpty)
            Positioned(
              left: AppSpacing.s4,
              bottom: AppSpacing.s20,
              child: SafeArea(
                child: GraphLegend(
                  onDismiss: () => setState(() => _showLegend = false),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(AsyncValue<GraphSnapshot> graph, GraphSnapshot? snapshot) {
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

    final byId = {for (final n in snapshot.nodes) n.id: n};
    return ForceDirectedGraphWidget<String>(
      key: const Key('graph_canvas'),
      controller: _controllerFor(snapshot),
      onDraggingUpdate: (_) => _keepLayoutStatic(),
      onDraggingEnd: (_) => _keepLayoutStatic(),
      nodesBuilder: (context, id) {
        final node = byId[id];
        if (node == null) return const SizedBox.shrink();
        final matched = _matches(node);
        final selected = node.id == _selectedId;
        return GraphNodeDot(
          node: node,
          matched: matched,
          selected: selected,
          dimmed: _query.isNotEmpty && !matched && !selected,
          onTap: () => _select(node),
        );
      },
      edgesBuilder: (context, a, b, distance) =>
          GraphEdgeLine(length: distance),
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
