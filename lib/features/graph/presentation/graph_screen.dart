import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_force_directed_graph/flutter_force_directed_graph.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/network/app_exception.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../../../shared/widgets/error_view.dart';
import '../../chat/data/chat_controller.dart';
import '../../chat/data/chat_history_api.dart';
import '../data/graph_api.dart';
import '../data/graph_expansion.dart';
import '../data/graph_layout.dart';
import '../data/graph_models.dart';
import '../data/graph_pulse.dart';
import 'widgets/graph_answer_card.dart';
import 'widgets/graph_ask_bar.dart';
import 'widgets/graph_legend.dart';
import 'widgets/graph_node_dot.dart';
import 'widgets/graph_search_bar.dart';
import 'widgets/node_info_panel.dart';
import 'widgets/replay_sheet.dart';

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
/// and opens its chunks in a panel (see [GraphExpansion]); pan and pinch-zoom
/// are the package's own gestures.
class GraphScreen extends ConsumerStatefulWidget {
  const GraphScreen({super.key, this.openDocument});

  /// How "Open in Documents" opens a document. Defaults to the app router;
  /// overridable so the screen can be tested without one.
  final void Function(BuildContext context, String documentId)? openDocument;

  @override
  ConsumerState<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends ConsumerState<GraphScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _askController = TextEditingController();

  String _query = '';

  /// Node types the legend chips have dimmed.
  final Set<GraphNodeType> _hiddenTypes = {};

  /// The latest answer is shown over the graph once a question has been asked
  /// from it (until dismissed).
  bool _showAnswer = false;

  /// The pulse animation: restarted by every pulse, 0 -> 1 over
  /// [pulseDuration]. The dots listen to it directly, so a pulse repaints only
  /// the pulsing dots.
  late final AnimationController _pulseAnim;

  /// The documents of the pulse in flight.
  Set<String> _pulsingIds = const {};

  /// The package's graph for [_builtFrom]; rebuilt only when a new snapshot
  /// arrives, never on every frame.
  ForceDirectedGraphController<String>? _controller;
  GraphSnapshot? _builtFrom;

  @override
  void initState() {
    super.initState();
    _pulseAnim = AnimationController(
      vsync: this,
      duration: pulseDuration,
      value: 1, // finished: nothing pulsing until the first pulse
    );
    ref.listenManual<GraphPulseState>(graphPulseProvider, (previous, next) {
      final pulse = next.pulse;
      if (pulse == null && previous?.pulse != null) {
        _pulsingIds = const {};
        _pulseAnim.value = 1;
        _controller?.needUpdate();
      } else if (pulse != null && pulse.key != previous?.pulse?.key) {
        _startPulse(pulse);
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _askController.dispose();
    _pulseAnim.dispose();
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
        if (!mounted || !identical(_controller, controller)) return;
        _fitToView();
        // A fresh graph has nothing expanded.
        ref.read(graphExpansionProvider.notifier).collapse();
      });
    }
    return _controller!;
  }

  /// Puts the graph's middle in the middle of the view and zooms so the whole
  /// layout fits, with room for the controls above and below it. The server's
  /// layout has a fixed radius, so without this a small graph floats in a sea
  /// of space and a wide one runs off the edges.
  void _fitToView() {
    final controller = _controller;
    if (controller == null) return;
    controller.center();
    controller.scale = _fitScale(
      [for (final n in controller.graph.nodes) (n.position.x, n.position.y)],
      MediaQuery.sizeOf(context),
      min: controller.minScale,
      max: controller.maxScale,
    );
  }

  void _zoomBy(double factor) {
    final controller = _controller;
    if (controller == null) return;
    controller.scale = controller.scale * factor;
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

  Node<String>? _nodeFor(ForceDirectedGraphController<String> c, String id) {
    for (final n in c.graph.nodes) {
      if (n.data == id) return n;
    }
    return null;
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
      context.push(AppRoutes.documentPreview(id));
    }
  }

  /// A pulse arrived: light up its documents and run the animation from the
  /// start. The package builds its nodes only when told something changed, so
  /// it is told once here; after that the dots animate themselves.
  void _startPulse(GraphPulse pulse) {
    _pulsingIds = pulse.documentIds.toSet();
    HapticFeedback.lightImpact();
    _pulseAnim.forward(from: 0);
    _controller?.needUpdate();
  }

  void _handleAsk(String text) {
    final chat = ref.read(chatControllerProvider);
    if (chat.busy || chat.loading) return; // one question at a time
    FocusScope.of(context).unfocus();
    _askController.clear();
    setState(() => _showAnswer = true);
    ref.read(chatControllerProvider.notifier).send(text);
  }

  void _openReplayPicker() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => ReplaySheet(
        onSelect: (session) {
          Navigator.of(sheetContext).pop();
          _replay(session);
        },
      ),
    );
  }

  /// Reopens [session] (the Chat tab shows it too) and plays its retrievals
  /// back on the graph, one answer's pulse at a time.
  Future<void> _replay(ChatSessionSummary session) async {
    final chat = ref.read(chatControllerProvider.notifier);
    await chat.openSession(session, replay: false);
    if (!mounted) return;
    final state = ref.read(chatControllerProvider);
    if (state.sessionId != session.id || state.loading) return;
    final steps = replaySteps(state.messages);
    final message = state.loadError != null
        ? "Couldn't load that conversation."
        : steps.isEmpty
        ? 'That conversation drew on no documents, so there is nothing to '
              'replay.'
        : null;
    if (message != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            key: const Key('graph_replay_message'),
            content: Text(message),
          ),
        );
      return;
    }
    setState(() => _showAnswer = false);
    await ref.read(graphPulseProvider.notifier).replay(steps);
  }

  @override
  Widget build(BuildContext context) {
    final graph = ref.watch(graphProvider);
    // Keep the last graph on screen while a refresh is in flight.
    final snapshot = graph.valueOrNull;
    final expansion = ref.watch(graphExpansionProvider);
    // Only the flag: the dots are told to redraw explicitly in _startPulse, not
    // by this screen happening to rebuild on every pulse.
    final replaying = ref.watch(
      graphPulseProvider.select((state) => state.replaying),
    );

    ref.listen<GraphExpansion>(graphExpansionProvider, (previous, next) {
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
                    if (snapshot != null &&
                        snapshot.nodes.isNotEmpty &&
                        !_showAnswer &&
                        expanded == null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.s1),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: GraphLegend(
                            hidden: _hiddenTypes,
                            onToggle: (type) => setState(() {
                              if (!_hiddenTypes.remove(type)) {
                                _hiddenTypes.add(type);
                              }
                              _controller?.needUpdate();
                            }),
                          ),
                        ),
                      ),
                    if (snapshot != null) _Notes(snapshot: snapshot),
                    if (replaying) const _ReplayingPill(),
                    const Spacer(),
                    if (expanded == null && _showAnswer)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s2),
                        child: GraphAnswerCard(
                          onClose: () => setState(() => _showAnswer = false),
                          onOpenInChat: () => context.go(AppRoutes.chat),
                          onOpenDocument: _openDocument,
                        ),
                      ),
                    if (expanded == null)
                      GraphAskBar(
                        controller: _askController,
                        onAsk: _handleAsk,
                        onHistory: _openReplayPicker,
                      ),
                    const SizedBox(height: AppSpacing.s2),
                  ],
                ),
              ),
            ),
          ),
          if (!_showAnswer &&
              expanded == null &&
              snapshot != null &&
              snapshot.nodes.isNotEmpty)
            Positioned(
              right: AppSpacing.s4,
              bottom: AppSpacing.s20,
              child: SafeArea(
                child: _ZoomControls(
                  onZoomIn: () => _zoomBy(1.25),
                  onZoomOut: () => _zoomBy(0.8),
                  onFit: _fitToView,
                ),
              ),
            ),
          if (expanded != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
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
    return ForceDirectedGraphWidget<String>(
      key: const Key('graph_canvas'),
      controller: _controllerFor(snapshot),
      onDraggingUpdate: (_) => _keepLayoutStatic(),
      onDraggingEnd: (_) => _keepLayoutStatic(),
      nodesBuilder: (context, id) {
        final node = byId[id];
        if (node == null) return const SizedBox.shrink();
        final matched = _matches(node);
        final selected = node.id == expansion.nodeId;
        return GraphNodeDot(
          node: node,
          matched: matched,
          selected: selected,
          dimmed:
              (_query.isNotEmpty && !matched && !selected) ||
              _hiddenTypes.contains(node.type),
          pulsing: _pulsingIds.contains(node.id),
          pulse: _pulseAnim,
          onTap: () => toggle(node.id),
        );
      },
      edgesBuilder: (context, a, b, distance) =>
          GraphEdgeLine(length: distance),
    );
  }
}

/// The scale at which a layout with these node positions (already centred on
/// the origin) fits a view of [size], leaving room above and below for the
/// search bar and the ask bar. Clamped to [min]..[max], and never zoomed in
/// past 1.5 so a two-node graph is not enormous.
double fitScaleFor(
  List<(double, double)> positions,
  Size size, {
  required double min,
  required double max,
}) => _fitScale(positions, size, min: min, max: max);

double _fitScale(
  List<(double, double)> positions,
  Size size, {
  required double min,
  required double max,
}) {
  if (positions.isEmpty) return 1;
  var reachX = 0.0;
  var reachY = 0.0;
  for (final (x, y) in positions) {
    reachX = math.max(reachX, x.abs());
    reachY = math.max(reachY, y.abs());
  }
  // Half the usable view, minus a node's own size and some breathing room.
  const margin = 48.0;
  final halfW = (size.width - 2 * AppSpacing.s4) / 2 - margin;
  final halfH = size.height * 0.55 / 2 - margin;
  final scaleX = reachX <= 0 ? double.infinity : halfW / reachX;
  final scaleY = reachY <= 0 ? double.infinity : halfH / reachY;
  final fit = math.min(scaleX, scaleY);
  if (fit.isInfinite) return 1;
  return fit.clamp(min, math.min(max, 1.5));
}

/// Zoom in / out / fit, for the people (and the hands) that pinch does not
/// suit.
class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    Widget button(Key key, String tooltip, IconData icon, VoidCallback onTap) =>
        IconButton(
          key: key,
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(icon, size: 20),
          color: AppColors.textPrimary,
          constraints: const BoxConstraints(
            minWidth: AppSpacing.minTouchTarget,
            minHeight: AppSpacing.minTouchTarget,
          ),
        );
    return Container(
      key: const Key('graph_zoom_controls'),
      decoration: BoxDecoration(
        color: AppColors.bgElevated.withValues(alpha: 0.92),
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(const Key('graph_zoom_in'), 'Zoom in', Icons.add, onZoomIn),
          button(
            const Key('graph_zoom_out'),
            'Zoom out',
            Icons.remove,
            onZoomOut,
          ),
          button(
            const Key('graph_fit'),
            'Fit graph to screen',
            Icons.center_focus_strong_outlined,
            onFit,
          ),
        ],
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
        'Documents are spread evenly until Cerebro groups them.',
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

/// Shown while a past conversation's pulses are being played back, with the
/// way to stop it.
class _ReplayingPill extends ConsumerWidget {
  const _ReplayingPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      key: const Key('graph_replaying'),
      padding: const EdgeInsets.only(top: AppSpacing.s2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.only(left: AppSpacing.s3),
          decoration: BoxDecoration(
            color: AppColors.bgElevated.withValues(alpha: 0.92),
            borderRadius: AppRadius.pillRadius,
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Replaying a conversation',
                style: AppTypography.xs.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              TextButton(
                key: const Key('graph_replay_stop'),
                onPressed: ref.read(graphPulseProvider.notifier).stopReplay,
                child: const Text('Stop'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
