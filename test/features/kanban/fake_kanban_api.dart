import 'dart:async';
import 'package:cerebro_mobile/features/kanban/data/kanban_api.dart';
import 'package:cerebro_mobile/features/kanban/data/kanban_board.dart';

const testBoard = KanbanBoard(
  id: 'board',
  title: 'My Board',
  columns: ['Backlog', 'In Progress', 'Done'],
  cards: [
    KanbanCard(
      id: 'a',
      column: 'Backlog',
      title: 'Alpha',
      description: '',
      position: 0,
    ),
    KanbanCard(
      id: 'b',
      column: 'Backlog',
      title: 'Beta',
      description: '',
      position: 1000,
    ),
    KanbanCard(
      id: 'c',
      column: 'Done',
      title: 'Gamma',
      description: '',
      position: 0,
    ),
  ],
);

class FakeKanbanApi implements KanbanApi {
  FakeKanbanApi({this.board = testBoard});
  KanbanBoard board;
  Object? loadError, writeError;
  Completer<void>? writeGate;
  Completer<KanbanBoard>? loadGate;
  final moves = <(String, String, double)>[];
  final creates = <(String, String, String, String?)>[];
  final deleted = <String>[];
  int loads = 0, gets = 0;
  @override
  Future<KanbanBoard> load() async {
    loads++;
    if (loadError case final Object error) throw error;
    return loadGate != null ? await loadGate!.future : board;
  }

  @override
  Future<KanbanBoard> get(String boardId) async {
    gets++;
    return board;
  }

  void _cards(List<KanbanCard> cards) {
    board = KanbanBoard(
      id: board.id,
      title: board.title,
      columns: board.columns,
      cards: cards,
    );
  }

  Future<void> _write() async {
    await writeGate?.future;
    if (writeError case final Object error) throw error;
  }

  @override
  Future<void> create(
    String boardId,
    String column,
    String title,
    String description,
    String? documentId,
  ) async {
    creates.add((column, title, description, documentId));
    await _write();
    _cards([
      ...board.cards,
      KanbanCard(
        id: 'new',
        column: column,
        title: title,
        description: description,
        documentId: documentId,
        position: 2000,
      ),
    ]);
  }

  @override
  Future<void> move(String cardId, String column, double position) async {
    moves.add((cardId, column, position));
    await _write();
    _cards([
      for (final card in board.cards)
        card.id != cardId
            ? card
            : KanbanCard(
                id: card.id,
                column: column,
                title: card.title,
                description: card.description,
                documentId: card.documentId,
                position: position,
              ),
    ]);
  }

  @override
  Future<void> delete(String cardId) async {
    deleted.add(cardId);
    await _write();
    _cards(board.cards.where((card) => card.id != cardId).toList());
  }
}
