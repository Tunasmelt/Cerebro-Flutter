import 'package:chopper/chopper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/generated/cerebro_api.swagger.dart';
import '../../../core/network/generated_api_client_provider.dart';
import '../../documents/data/documents_error_mapper.dart';
import 'kanban_board.dart';

final kanbanApiProvider = Provider<KanbanApi>(
  (ref) => ApiKanbanApi(ref.watch(generatedApiClientProvider)),
);

abstract interface class KanbanApi {
  Future<KanbanBoard> load();
  Future<KanbanBoard> get(String boardId);
  Future<void> create(
    String boardId,
    String column,
    String title,
    String description,
    String? documentId,
  );
  Future<void> move(String cardId, String column, double position);
  Future<void> delete(String cardId);
}

class ApiKanbanApi implements KanbanApi {
  ApiKanbanApi(this.api);
  final CerebroApi api;

  Future<Map<String, dynamic>> _send(
    Future<Response> Function() request,
  ) async {
    try {
      final response = await request();
      if (!response.isSuccessful) {
        throw DocumentsErrorMapper.ofResponse(response);
      }
      if (response.body is! Map) throw const FormatException();
      return Map<String, dynamic>.from(response.body as Map);
    } catch (error) {
      final mapped = DocumentsErrorMapper.ofException(error);
      if (mapped is UnknownApiException) {
        throw const UnknownApiException(
          'Could not update your board. Try again.',
        );
      }
      throw mapped;
    }
  }

  @override
  Future<KanbanBoard> load() async {
    final body = await _send(api.apiV1BoardsGet);
    final boards = body['boards'];
    if (boards is! List) {
      throw const UnknownApiException('Could not load your board.');
    }
    final Map<String, dynamic> board;
    if (boards.isEmpty) {
      board = await _send(
        () =>
            api.apiV1BoardsPost(body: const CreateBoardBody(title: 'My Board')),
      );
    } else {
      if (boards.first is! Map) {
        throw const UnknownApiException('Could not load your board.');
      }
      board = Map<String, dynamic>.from(boards.first as Map);
    }
    final id = board['id'];
    if (id is! String || id.isEmpty) {
      throw const UnknownApiException('Could not load your board.');
    }
    return get(id);
  }

  @override
  Future<KanbanBoard> get(String boardId) async {
    final body = await _send(() => api.apiV1BoardsBoardIdGet(boardId: boardId));
    try {
      return KanbanBoard.fromJson(body);
    } catch (_) {
      throw const UnknownApiException('Could not load your board.');
    }
  }

  @override
  Future<void> create(
    String boardId,
    String column,
    String title,
    String description,
    String? documentId,
  ) async {
    await _send(
      () => api.apiV1BoardsBoardIdCardsPost(
        boardId: boardId,
        body: CreateCardBody(
          columnName: column,
          title: title,
          description: description,
          documentId: documentId,
        ),
      ),
    );
  }

  @override
  Future<void> move(String cardId, String column, double position) async {
    await _send(
      () => api.apiV1CardsCardIdPatch(
        cardId: cardId,
        body: UpdateCardBody(columnName: column, position: position),
      ),
    );
  }

  @override
  Future<void> delete(String cardId) async {
    await _send(() => api.apiV1CardsCardIdDelete(cardId: cardId));
  }
}
