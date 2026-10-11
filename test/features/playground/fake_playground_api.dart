import 'dart:async';
import 'package:cerebro_mobile/features/playground/data/playground_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_history_api.dart';

const samplePrompt = PromptBreakdown(
  model: 'server-model',
  sections: [
    PromptSection('system_instructions', 'Synthetic instructions', 10, null),
    PromptSection('context', 'Synthetic context', 7, 'Example · chunk_1234'),
    PromptSection('user_query', 'Synthetic question', 4, null),
  ],
  response: 'Synthetic response',
  responseTokens: 20,
  totalTokens: 84,
  cost: 0.000069,
);

class FakePlaygroundApi implements PlaygroundApi {
  Object? error;
  Completer<PromptBreakdown>? gate;
  final calls = <(String, String)>[];
  List<PromptTurn> replies = [
    const PromptTurn('m1', 'Synthetic response'),
    const PromptTurn('m2', 'Second response'),
  ];
  @override
  Future<List<PromptTurn>> turns(String id) async => replies;
  @override
  Future<PromptBreakdown> prompt(String session, String message) async {
    calls.add((session, message));
    if (error != null) throw error!;
    return gate != null ? gate!.future : samplePrompt;
  }
}

class FakePlaygroundHistory implements ChatHistoryApi {
  Object? error;
  List<ChatSessionSummary> sessions = [
    ChatSessionSummary(
      id: 's1',
      createdAt: DateTime.utc(2026),
      preview: 'Synthetic conversation',
    ),
    ChatSessionSummary(
      id: 's2',
      createdAt: DateTime.utc(2026),
      preview: 'Other conversation',
    ),
  ];
  @override
  Future<List<ChatSessionSummary>> list() async {
    if (error != null) throw error!;
    return sessions;
  }

  @override
  Future<ChatHistory> messages(String id) => throw UnimplementedError();
  @override
  Future<void> delete(String id) => throw UnimplementedError();
}
