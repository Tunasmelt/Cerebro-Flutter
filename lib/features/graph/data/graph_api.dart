import 'dart:async';

import 'package:chopper/chopper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/generated_api_client_provider.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/generated/cerebro_api.swagger.dart';
import '../../auth/data/current_user_provider.dart';
import '../../documents/data/documents_error_mapper.dart';
import 'graph_models.dart';

/// The read side of the graph endpoints.
abstract interface class GraphApi {
  /// Every ready or sealed document, current as of the call.
  Future<List<GraphNodeData>> nodes();

  /// Nearest-neighbour links as of the last recluster.
  Future<List<GraphEdgeData>> edges();
}

class ApiGraphApi implements GraphApi {
  ApiGraphApi(this._api);

  final CerebroApi _api;

  Future<Response> _run(Future<Response> request) async {
    final Response response;
    try {
      response = await request;
    } catch (error) {
      throw DocumentsErrorMapper.ofException(error);
    }
    if (!response.isSuccessful) throw DocumentsErrorMapper.ofResponse(response);
    return response;
  }

  List<Object?> _rows(Response response, String key) {
    final body = response.body;
    final rows = body is Map ? body[key] : null;
    if (rows is! List) {
      throw const UnknownApiException('Unexpected response from the server.');
    }
    return rows;
  }

  @override
  Future<List<GraphNodeData>> nodes() async {
    final response = await _run(_api.apiV1GraphNodesGet());
    return [
      for (final row in _rows(response, 'nodes')) ?GraphNodeData.fromJson(row),
    ];
  }

  @override
  Future<List<GraphEdgeData>> edges() async {
    final response = await _run(_api.apiV1GraphEdgesGet());
    return [
      for (final row in _rows(response, 'edges')) ?GraphEdgeData.fromJson(row),
    ];
  }
}

final graphApiProvider = Provider<GraphApi>((ref) {
  return ApiGraphApi(ref.watch(generatedApiClientProvider));
});

/// The user's graph. Nodes are required; if only the edges fail the graph
/// still shows, without links. Re-fetched when the signed-in user changes, and
/// a late answer for the previous user is dropped.
final graphProvider =
    AsyncNotifierProvider.autoDispose<GraphNotifier, GraphSnapshot>(
      GraphNotifier.new,
    );

class GraphNotifier extends AutoDisposeAsyncNotifier<GraphSnapshot> {
  int _generation = 0;

  @override
  Future<GraphSnapshot> build() async {
    final userId = ref.watch(currentUserIdProvider);
    _generation++;
    ref.onDispose(() => _generation++);
    if (userId == null) return const GraphSnapshot(nodes: [], edges: []);
    return _load();
  }

  Future<GraphSnapshot> _load() async {
    final api = ref.read(graphApiProvider);
    final edgesRequest = api
        .edges()
        .then<List<GraphEdgeData>?>((e) => e)
        .catchError((Object _) => null);
    final nodes = await api.nodes();
    final edges = await edgesRequest;
    return GraphSnapshot(
      nodes: nodes,
      edges: edges ?? const [],
      edgesUnavailable: edges == null,
    );
  }

  /// Fetches again, keeping the current graph on screen meanwhile.
  Future<void> refresh() async {
    final generation = _generation;
    state = const AsyncLoading<GraphSnapshot>().copyWithPrevious(state);
    final result = await AsyncValue.guard(_load);
    if (generation != _generation) return;
    state = result;
  }
}
