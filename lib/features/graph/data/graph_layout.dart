import 'dart:math' as math;

import 'package:flutter_force_directed_graph/flutter_force_directed_graph.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import 'graph_models.dart';

/// How far, in logical pixels, the outermost server-placed node sits from the
/// origin. The server's PCA coordinates are in arbitrary units, so they are
/// fitted into this radius.
const double graphLayoutRadius = 220;

/// Where nodes with no server position start, as a fraction of
/// [graphLayoutRadius].
const double _unplacedInner = 0.25;

/// Turns the API's nodes and edges into the package's graph.
///
/// The layout is the server's, not a local simulation: a node with a
/// position keeps it (scaled to fit), and every node is marked static so the
/// view neither jitters nor spends battery ticking physics. Nodes the server
/// has not placed (new since the last recluster, or an account never
/// reclustered) are spread on a deterministic spiral, by id — the same
/// documents always give the same picture, whatever order the server lists
/// them in, and never a random one.
///
/// Links to a document that is not in [GraphSnapshot.nodes] (the edges are as
/// of the last recluster, so a deleted document's links linger), links from a
/// node to itself, and duplicate links are dropped rather than drawn or
/// crashed on.
ForceDirectedGraph<String> buildForceGraph(GraphSnapshot snapshot) {
  final graph = ForceDirectedGraph<String>();
  final byId = <String, Node<String>>{};

  var farthest = 0.0;
  for (final n in snapshot.nodes) {
    if (n.hasPosition) {
      farthest = math.max(farthest, math.max(n.x!.abs(), n.y!.abs()));
    }
  }
  final scale = farthest > 0 ? graphLayoutRadius / farthest : 1.0;

  // Spiral spots go to unplaced nodes in id order, not in the order the server
  // happened to list them: the list order is not stable between requests, and
  // a document must not hop to another spot every time the screen reloads.
  final unplacedRank = <String, int>{};
  final unplacedIds =
      snapshot.nodes
          .where((n) => !n.hasPosition)
          .map((n) => n.id)
          .toSet()
          .toList()
        ..sort();
  for (final id in unplacedIds) {
    unplacedRank[id] = unplacedRank.length;
  }

  for (final n in snapshot.nodes) {
    if (byId.containsKey(n.id)) continue; // a repeated id is one node
    final position = n.hasPosition
        ? Vector2(n.x! * scale, n.y! * scale)
        : _spiral(unplacedRank[n.id]!);
    final node = Node<String>(n.id, position)..static();
    byId[n.id] = node;
    graph.addNode(node);
  }

  final seen = <String>{};
  for (final e in snapshot.edges) {
    final a = byId[e.from];
    final b = byId[e.to];
    if (a == null || b == null || identical(a, b)) continue;
    final key = e.from.compareTo(e.to) < 0
        ? '${e.from}|${e.to}'
        : '${e.to}|${e.from}';
    if (!seen.add(key)) continue;
    graph.addEdge(Edge(a, b));
  }
  return graph;
}

/// The [index]th point of a golden-angle spiral: evenly spread, no overlaps,
/// and stable.
Vector2 _spiral(int index) {
  const goldenAngle = 2.399963229728653;
  final radius =
      graphLayoutRadius * _unplacedInner + 28 * math.sqrt(index.toDouble());
  final angle = index * goldenAngle;
  return Vector2(radius * math.cos(angle), radius * math.sin(angle));
}
