import 'package:flutter/material.dart';

import '../../../shared/tokens/app_spacing.dart';
import 'models/graph_node.dart';
import 'widgets/graph_ask_bar.dart';
import 'widgets/graph_canvas_painter.dart';
import 'widgets/graph_legend.dart';
import 'widgets/graph_search_bar.dart';
import 'widgets/node_detail_sheet.dart';

/// The brain graph screen — Cerebro's 2D, deliberately-not-3D visual
/// index of a user's vault (architecture-and-spec.md §5, CLAUDE.md "2D
/// graph is a deliberate choice").
///
/// This is a wireframe pass: nodes/edges are static mock data (see
/// `MockGraphData`) rather than a `/graph/nodes` + `/graph/edges` fetch,
/// and there's no live force-directed physics tick — see
/// `GraphCanvasPainter` and `GraphNode.position` for how the structure
/// stays ready for both without a rewrite. Design source is Brain.tsx
/// (`Cerebro 2.0/Mockups 2.0/src/components/Brain.tsx`), adapted for a
/// touch/portrait target rather than ported pixel-for-pixel — see
/// `NodeDetailSheet`'s doc comment for the one interaction-model change
/// (bottom sheet instead of a right-side panel).
class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _askController = TextEditingController();

  String _query = '';
  int? _selectedNodeId;
  bool _showLegend = true;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _askController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  int get _matchCount {
    if (_query.isEmpty) return 0;
    final q = _query.toLowerCase();
    return MockGraphData.nodes
        .where((n) => n.label.toLowerCase().contains(q))
        .length;
  }

  void _handleTapUp(TapUpDetails details, Size canvasSize) {
    final tapPos = details.localPosition;
    GraphNode? hit;
    double bestDist = double.infinity;
    for (final node in MockGraphData.nodes) {
      final center = Offset(
        node.position.dx * canvasSize.width,
        node.position.dy * canvasSize.height,
      );
      final dist = (center - tapPos).distance;
      // Touch target is at least AppSpacing.minTouchTarget / 2 in radius,
      // even for visually small (sealed) nodes — see CLAUDE.md's mobile
      // touch-target minimum.
      final hitRadius = node.baseRadius + AppSpacing.minTouchTarget / 2;
      if (dist <= hitRadius && dist < bestDist) {
        hit = node;
        bestDist = dist;
      }
    }
    if (hit != null) {
      _selectNode(hit);
    } else if (_selectedNodeId != null) {
      setState(() => _selectedNodeId = null);
    }
  }

  void _selectNode(GraphNode node) {
    setState(() => _selectedNodeId = node.id);
    _openDetailSheet(node);
  }

  void _openDetailSheet(GraphNode node) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => NodeDetailSheet(
        node: node,
        onChatAboutThis: () => Navigator.of(sheetContext).maybePop(),
        onOpenInDocuments: () => Navigator.of(sheetContext).maybePop(),
        onZoomOut: () {
          Navigator.of(sheetContext).maybePop();
          setState(() => _selectedNodeId = null);
        },
      ),
    ).whenComplete(() {
      // Deselect once the sheet is dismissed (swipe/tap-scrim/close
      // button all funnel through here), mirroring Brain.tsx's
      // handleDeselect on panel close.
      if (mounted) setState(() => _selectedNodeId = null);
    });
  }

  void _handleAsk(String text) {
    _askController.clear();
    // Wireframe stub: this pass intentionally does not wire real
    // navigation to chat (see task constraints) — a later milestone
    // routes this to the chat feature with the query pre-filled.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canvasSize =
                    Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _handleTapUp(details, canvasSize),
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      return CustomPaint(
                        size: canvasSize,
                        painter: GraphCanvasPainter(
                          nodes: MockGraphData.nodes,
                          edges: MockGraphData.edges,
                          query: _query,
                          selectedNodeId: _selectedNodeId,
                          pulse: _pulseController.value,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.s2),
                    GraphSearchBar(
                      controller: _searchController,
                      query: _query,
                      matchCount: _matchCount,
                      onChanged: (v) => setState(() => _query = v),
                      onClear: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
                    const Spacer(),
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
          if (_showLegend)
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
}
