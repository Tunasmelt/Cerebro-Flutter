import 'dart:async';
import 'package:flutter/material.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_typography.dart';
import '../data/kanban_board.dart';

/// Native dragging and menu alternatives. Indices exclude the moved card.
class KanbanView extends StatefulWidget {
  const KanbanView({
    super.key,
    required this.board,
    required this.onMove,
    required this.onCreate,
    required this.onDelete,
    required this.onOpenDocument,
    this.documentTitles = const {},
    this.saving = false,
  });
  final KanbanBoard board;
  final bool saving;
  final Map<String, String> documentTitles;
  final void Function(String id, String column, int index) onMove;
  final ValueChanged<String> onCreate;
  final ValueChanged<KanbanCard> onDelete;
  final ValueChanged<String> onOpenDocument;
  @override
  State<KanbanView> createState() => _KanbanViewState();
}

class _KanbanViewState extends State<KanbanView> {
  final _scroll = ScrollController();
  final _dropKeys = <(String, int, bool), GlobalKey>{};
  Offset? _dragPosition;
  Timer? _edgeTimer;
  double _edgeStep = 0;
  void _stopScroll() {
    _edgeTimer?.cancel();
    _edgeTimer = null;
  }

  void _dragUpdate(DragUpdateDetails details) {
    _dragPosition = details.globalPosition;
    final box = context.findRenderObject() as RenderBox;
    final x = box.globalToLocal(details.globalPosition).dx;
    _edgeStep = x < 56
        ? -18
        : x > box.size.width - 56
        ? 18
        : 0;
    if (_edgeStep == 0) {
      _stopScroll();
      return;
    }
    _edgeTimer ??= Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(
        (_scroll.offset + _edgeStep).clamp(
          _scroll.position.minScrollExtent,
          _scroll.position.maxScrollExtent,
        ),
      );
    });
  }

  Rect? _dropRect(String column, int index, bool header) {
    final render = _dropKeys[(column, index, header)]?.currentContext
        ?.findRenderObject();
    return render is RenderBox && render.hasSize
        ? render.localToGlobal(Offset.zero) & render.size
        : null;
  }

  void _finishDrag(KanbanCard card) {
    _stopScroll();
    final point = _dragPosition;
    _dragPosition = null;
    if (!mounted || point == null || widget.saving) return;
    final box = context.findRenderObject() as RenderBox;
    final viewport = box.localToGlobal(Offset.zero) & box.size;
    if (!viewport.contains(point)) return;
    // Resolve the final layout, rather than DragTarget's cached hit from the
    // last pointer event: edge scrolling also moves targets under a still finger.
    for (final column in widget.board.columns) {
      final cards = widget.board.inColumn(column);
      final header = _dropRect(column, cards.length, true);
      if (header == null ||
          point.dx < header.left ||
          point.dx >= header.right) {
        continue;
      }
      int? destination;
      if (header.contains(point)) {
        destination = cards.length;
      } else if (point.dy >= header.bottom) {
        for (var index = 0; index <= cards.length; index++) {
          if (_dropRect(column, index, false)?.contains(point) == true) {
            destination = index;
            break;
          }
        }
      }
      if (destination != null) {
        final source = cards.indexWhere((item) => item.id == card.id);
        widget.onMove(
          card.id,
          column,
          destination - (source >= 0 && source < destination ? 1 : 0),
        );
      }
      return;
    }
  }

  @override
  void dispose() {
    _stopScroll();
    _scroll.dispose();
    super.dispose();
  }

  Widget _drop(String column, int index, Widget child, {bool header = false}) =>
      DragTarget<KanbanCard>(
        key: _dropKeys.putIfAbsent((column, index, header), GlobalKey.new),
        onWillAcceptWithDetails: (_) => !widget.saving,
        builder: (_, candidates, _) => DecoratedBox(
          decoration: BoxDecoration(
            color: candidates.isEmpty
                ? Colors.transparent
                : AppColors.accentPrimarySubtle,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        ),
      );

  Widget _card(KanbanCard card, List<KanbanCard> cards) {
    final index = cards.indexWhere((item) => item.id == card.id);
    final body = Card(
      key: ValueKey('kanban_card_${card.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.drag_indicator,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    card.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                PopupMenuButton<(String, String?)>(
                  tooltip: 'Card actions',
                  enabled: !widget.saving,
                  key: ValueKey('kanban_actions_${card.id}'),
                  onSelected: (action) {
                    if (action.$1 == 'delete') {
                      widget.onDelete(card);
                      return;
                    }
                    if (action.$1 == 'up') {
                      widget.onMove(card.id, card.column, index - 1);
                      return;
                    }
                    if (action.$1 == 'down') {
                      widget.onMove(card.id, card.column, index + 1);
                      return;
                    }
                    widget.onMove(
                      card.id,
                      action.$2!,
                      widget.board.inColumn(action.$2!).length,
                    );
                  },
                  itemBuilder: (_) => [
                    if (index > 0)
                      const PopupMenuItem(
                        value: ('up', null),
                        child: Text('Move up'),
                      ),
                    if (index < cards.length - 1)
                      const PopupMenuItem(
                        value: ('down', null),
                        child: Text('Move down'),
                      ),
                    for (final column in widget.board.columns)
                      if (column != card.column)
                        PopupMenuItem(
                          value: ('column', column),
                          child: Text('Move to $column'),
                        ),
                    const PopupMenuItem(
                      value: ('delete', null),
                      child: Text('Delete card'),
                    ),
                  ],
                ),
              ],
            ),
            if (card.description.isNotEmpty)
              Text(
                card.description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            if (card.documentId case final String id)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.description_outlined, size: 18),
                  label: Text(
                    widget.documentTitles[id] ?? 'Linked document',
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => widget.onOpenDocument(id),
                ),
              ),
          ],
        ),
      ),
    );
    return LongPressDraggable<KanbanCard>(
      data: card,
      maxSimultaneousDrags: widget.saving ? 0 : 1,
      onDragUpdate: _dragUpdate,
      onDragStarted: () => _dragPosition = null,
      onDragEnd: (details) {
        if (details.wasAccepted) {
          _finishDrag(card);
        } else {
          _stopScroll();
          _dragPosition = null;
        }
      },
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 256, child: body),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: body),
      child: body,
    );
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const Key('kanban_columns'),
    scrollDirection: Axis.horizontal,
    controller: _scroll,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (column, cards) in widget.board.columns.map(
          (column) => (column, widget.board.inColumn(column)),
        ))
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 272,
              child: Column(
                children: [
                  _drop(
                    column,
                    cards.length,
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            column.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${cards.length}',
                          style: AppTypography.mono(AppTypography.sm),
                        ),
                        IconButton(
                          tooltip: 'Add card to $column',
                          onPressed: widget.saving
                              ? null
                              : () => widget.onCreate(column),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    header: true,
                  ),
                  Expanded(
                    child: ListView(
                      key: ValueKey('kanban_column_$column'),
                      padding: const EdgeInsets.only(bottom: 72),
                      children: [
                        for (final (index, card) in cards.indexed)
                          _drop(column, index, _card(card, cards)),
                        _drop(
                          column,
                          cards.length,
                          SizedBox(
                            key: ValueKey('kanban_drop_$column'),
                            height: 64,
                            child: const Center(
                              child: Text(
                                'Drop cards here',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
