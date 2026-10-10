import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../auth/data/current_user_provider.dart';
import 'graph_api.dart';
import 'graph_models.dart';

enum ChunkLoad { loading, loaded, failed }

/// Which node is expanded, and the chunks loaded for it (listed in the node's
/// panel; they are not drawn on the graph).
///
/// **Interaction model (chosen explicitly): one node is expanded at a time.**
/// Tapping a collapsed node expands it, first collapsing whichever node was
/// expanded; tapping the expanded node collapses it.
class GraphExpansion {
  const GraphExpansion({
    this.nodeId,
    this.load = ChunkLoad.loading,
    this.chunks = const [],
    this.error,
    this.selectedChunkId,
  });

  /// Nothing expanded.
  static const none = GraphExpansion();

  final String? nodeId;
  final ChunkLoad load;

  /// Every chunk the document has, in reading order.
  final List<DocumentChunk> chunks;
  final AppException? error;
  final String? selectedChunkId;

  bool get isExpanded => nodeId != null;

  DocumentChunk? get selectedChunk {
    for (final c in chunks) {
      if (c.id == selectedChunkId) return c;
    }
    return null;
  }
}

final graphExpansionProvider =
    NotifierProvider.autoDispose<GraphExpansionController, GraphExpansion>(
      GraphExpansionController.new,
    );

class GraphExpansionController extends AutoDisposeNotifier<GraphExpansion> {
  /// Bumped on every change of what is expanded, so an answer for a node the
  /// user has already moved on from is dropped instead of landing in the new
  /// one.
  int _generation = 0;

  @override
  GraphExpansion build() {
    ref.watch(currentUserIdProvider);
    _generation++;
    ref.onDispose(() => _generation++);
    return GraphExpansion.none;
  }

  /// A tap on [nodeId]: expand it, or collapse it if it already is.
  Future<void> toggle(String nodeId) {
    if (state.nodeId == nodeId) {
      collapse();
      return Future.value();
    }
    return _expand(nodeId);
  }

  void collapse() {
    _generation++;
    state = GraphExpansion.none;
  }

  /// Tries again after a failed load.
  Future<void> retry() {
    final id = state.nodeId;
    if (id == null || state.load != ChunkLoad.failed) return Future.value();
    return _expand(id);
  }

  /// Highlights a chunk (its satellite and its row); tapping it again clears
  /// the highlight.
  void selectChunk(String chunkId) {
    // Only a chunk that has been loaded can be selected — so nothing is
    // selectable while loading or after a failure.
    if (!state.chunks.any((c) => c.id == chunkId)) return;
    state = GraphExpansion(
      nodeId: state.nodeId,
      load: state.load,
      chunks: state.chunks,
      selectedChunkId: state.selectedChunkId == chunkId ? null : chunkId,
    );
  }

  Future<void> _expand(String nodeId) async {
    final generation = ++_generation;
    state = GraphExpansion(nodeId: nodeId);
    try {
      final chunks = await ref.read(graphApiProvider).chunks(nodeId);
      if (generation != _generation) return;
      state = GraphExpansion(
        nodeId: nodeId,
        load: ChunkLoad.loaded,
        chunks: chunks,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = GraphExpansion(
        nodeId: nodeId,
        load: ChunkLoad.failed,
        error: error is AppException ? error : const UnknownApiException(),
      );
    }
  }
}
