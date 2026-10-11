class KanbanCard {
  const KanbanCard({
    required this.id,
    required this.column,
    required this.title,
    required this.description,
    required this.position,
    this.documentId,
  });
  factory KanbanCard.fromJson(Map<String, dynamic> json) => KanbanCard(
    id: json['id'] as String,
    column: json['column_name'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    position: (json['position'] as num).toDouble(),
    documentId: json['document_id'] as String?,
  );
  final String id, column, title, description;
  final double position;
  final String? documentId;
}

class KanbanBoard {
  const KanbanBoard({
    required this.id,
    required this.title,
    required this.columns,
    required this.cards,
  });
  factory KanbanBoard.fromJson(Map<String, dynamic> json) => KanbanBoard(
    id: json['id'] as String,
    title: json['title'] as String,
    columns: List<String>.from(json['columns'] as List),
    cards: [
      for (final card in json['cards'] as List)
        KanbanCard.fromJson(Map<String, dynamic>.from(card as Map)),
    ],
  );
  final String id, title;
  final List<String> columns;
  final List<KanbanCard> cards;
  List<KanbanCard> inColumn(String column) =>
      cards.where((card) => card.column == column).toList()..sort((a, b) {
        final order = a.position.compareTo(b.position);
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
}

// Drop index is measured AFTER removing the dragged card, like the web UI.
// Use the backend's float positions; ordinary moves patch one card only.
double positionForDrop(List<KanbanCard> remaining, int index) {
  if (index < 0 || index > remaining.length) {
    throw RangeError.index(index, remaining);
  }
  final before = index > 0 ? remaining[index - 1].position : null;
  final after = index < remaining.length ? remaining[index].position : null;
  return before != null && after != null
      ? before / 2 + after / 2
      : before != null
      ? before + 1000
      : after != null
      ? after - 1000
      : 0;
}
