import 'package:chopper/chopper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/generated/cerebro_api.swagger.dart';
import '../../../core/network/generated_api_client_provider.dart';
import '../../auth/data/current_user_provider.dart';
import '../../chat/data/chat_controller.dart';
import '../../chat/data/chat_history_api.dart';
import '../../documents/data/documents_error_mapper.dart';

class PromptSection {
  const PromptSection(this.label, this.content, this.tokens, this.citation);
  final String label, content;
  final int tokens;
  final String? citation;
}

class PromptBreakdown {
  const PromptBreakdown({
    required this.model,
    required this.sections,
    required this.response,
    required this.responseTokens,
    required this.totalTokens,
    required this.cost,
  });
  final String model, response;
  final List<PromptSection> sections;
  final int responseTokens, totalTokens;
  final double cost;
  int get inputTokens => totalTokens - responseTokens;
  factory PromptBreakdown.fromJson(Map<String, dynamic> json) {
    int count(Object? value) {
      if (value is! int || value < 0) throw const FormatException();
      return value;
    }

    final response = json['response'] as Map;
    final output = count(response['tokens']),
        total = count(json['total_tokens']);
    final cost = (json['estimated_cost_usd'] as num).toDouble();
    if (total < output || !cost.isFinite || cost < 0) {
      throw const FormatException();
    }
    return PromptBreakdown(
      model: json['model'] as String,
      sections: [
        for (final section in json['sections'] as List)
          PromptSection(
            section['label'] as String,
            section['content'] as String,
            count(section['tokens']),
            section['citation'] as String?,
          ),
      ],
      response: response['content'] as String,
      responseTokens: output,
      totalTokens: total,
      cost: cost,
    );
  }
}

class PromptTurn {
  const PromptTurn(this.id, this.content);
  final String id, content;
}

abstract interface class PlaygroundApi {
  Future<List<PromptTurn>> turns(String sessionId);
  Future<PromptBreakdown> prompt(String sessionId, String messageId);
}

class ApiPlaygroundApi implements PlaygroundApi {
  ApiPlaygroundApi(this.client);
  final CerebroApi client;
  Future<T> _load<T>(
    Future<Response> Function() request,
    T Function(Map<String, dynamic>) parse,
  ) => loadPlayground(() async {
    final response = await request();
    if (!response.isSuccessful) throw DocumentsErrorMapper.ofResponse(response);
    return parse(Map<String, dynamic>.from(response.body as Map));
  });
  @override
  Future<List<PromptTurn>> turns(String sessionId) => _load(
    () => client.apiV1ChatSessionsSessionIdMessagesGet(sessionId: sessionId),
    (body) => [
      for (final row in body['messages'] as List)
        if (row['role'] == 'assistant')
          PromptTurn(row['id'] as String, row['content'] as String),
    ],
  );
  @override
  Future<PromptBreakdown> prompt(String sessionId, String messageId) => _load(
    () => client.apiV1ChatSessionsSessionIdMessagesMessageIdPromptGet(
      sessionId: sessionId,
      messageId: messageId,
    ),
    PromptBreakdown.fromJson,
  );
}

Future<T> loadPlayground<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (error) {
    final mapped = DocumentsErrorMapper.ofException(error);
    throw mapped is UnknownApiException
        ? const UnknownApiException(
            'Could not load the token breakdown. Try again.',
          )
        : mapped;
  }
}

final playgroundApiProvider = Provider<PlaygroundApi>(
  (ref) => ApiPlaygroundApi(ref.watch(generatedApiClientProvider)),
);
void _requireOwner(Ref ref) {
  if (ref.watch(currentUserIdProvider) == null) {
    throw const UnauthenticatedException();
  }
}

final playgroundSessionsProvider =
    FutureProvider.autoDispose<List<ChatSessionSummary>>((ref) {
      _requireOwner(ref);
      return loadPlayground(() => ref.watch(chatHistoryApiProvider).list());
    });
final playgroundTurnsProvider = FutureProvider.autoDispose
    .family<List<PromptTurn>, String>((ref, id) {
      _requireOwner(ref);
      return ref.watch(playgroundApiProvider).turns(id);
    });
typedef PromptSelection = ({String sessionId, String messageId});
final playgroundPromptProvider = FutureProvider.autoDispose
    .family<PromptBreakdown, PromptSelection>((ref, selection) {
      _requireOwner(ref);
      return ref
          .watch(playgroundApiProvider)
          .prompt(selection.sessionId, selection.messageId);
    });
