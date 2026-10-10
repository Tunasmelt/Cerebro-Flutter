import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import '../../../core/network/app_exception.dart';
import '../../auth/data/current_user_provider.dart';
import 'graph_api.dart';
import 'graph_models.dart';

/// How many chunks are drawn around a node. Web caps the same way: a
/// document can have hundreds, and a ring of hundreds of dots is unreadable.
/// The rest are still listed in the node's panel.
const int maxSatellites = 64;

enum ChunkLoad { loading, loaded, failed }

/// Which node is expanded into its chunks, and what has been loaded for it.
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
  final List<ChunkSatellite> chunks;
  final AppException? error;
  final String? selectedChunkId;

  bool get isExpanded => nodeId != null;

  /// The chunks drawn on the graph: the first [maxSatellites].
  List<ChunkSatellite> get shown => chunks.length <= maxSatellites
      ? chunks
      : chunks.sublist(0, maxSatellites);

  bool get isTruncated => chunks.length > maxSatellites;

  ChunkSatellite? get selectedChunk {
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

/// Ring sizes for laying satellites around a node: how many fit on each ring,
/// and how far out the ring sits (logical pixels, before zoom).
const List<({int capacity, double radius})> _rings = [
  (capacity: 16, radius: 70),
  (capacity: 20, radius: 110),
  (capacity: 28, radius: 150),
];

/// Where [count] satellites sit relative to their node: concentric rings,
/// filled from the inside, each odd ring staggered half a step so dots do not
/// line up radially. Deterministic. More than [maxSatellites] are not laid
/// out.
List<Vector2> satelliteOffsets(int count) {
  final n = math.min(count, maxSatellites);
  final out = <Vector2>[];
  var remaining = n;
  for (var ring = 0; ring < _rings.length && remaining > 0; ring++) {
    final (:capacity, :radius) = _rings[ring];
    final onRing = math.min(remaining, capacity);
    // A ring that is not full is spaced as if it had at least six dots, so a
    // lone satellite is not stranded on top of its node's label.
    final step = 2 * math.pi / math.max(onRing, math.min(capacity, 6));
    final start = -math.pi / 2 + (ring.isOdd ? step / 2 : 0);
    for (var i = 0; i < onRing; i++) {
      final angle = start + i * step;
      out.add(Vector2(radius * math.cos(angle), radius * math.sin(angle)));
    }
    remaining -= onRing;
  }
  return out;
}
