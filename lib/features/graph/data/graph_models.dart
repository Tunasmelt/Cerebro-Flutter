/// How a node is drawn: sealed wins over everything, then images, then the
/// default document. The same rule web's `nodeBaseColor` applies.
enum GraphNodeType { document, image, sealed }

/// One document in the graph, as `GET /graph/nodes` reports it.
///
/// `clusterId`, `x` and `y` are null for a document uploaded since the last
/// recluster (the backend still lists it — "no missing nodes"), and for every
/// document of an account that has never been reclustered.
class GraphNodeData {
  const GraphNodeData({
    required this.id,
    required this.title,
    this.clusterId,
    this.x,
    this.y,
    this.mime,
    this.status,
  });

  final String id;
  final String title;
  final String? clusterId;

  /// The first two components of the server's PCA of the cluster centroids.
  /// Cosmetic within a cluster; the cluster membership is the real signal.
  final double? x;
  final double? y;
  final String? mime;

  /// `ready` or `sealed`.
  final String? status;

  bool get hasPosition => x != null && y != null;

  GraphNodeType get type {
    if (status == 'sealed') return GraphNodeType.sealed;
    if (mime != null && mime!.startsWith('image/')) return GraphNodeType.image;
    return GraphNodeType.document;
  }

  /// Null when the row has no usable id — it cannot be drawn or referenced.
  static GraphNodeData? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final title = json['title'];
    final cluster = json['cluster_id'];
    final mime = json['mime'];
    final status = json['status'];
    return GraphNodeData(
      id: id,
      title: title is String && title.trim().isNotEmpty
          ? title.trim()
          : 'Untitled',
      clusterId: cluster is String && cluster.isNotEmpty ? cluster : null,
      x: _finite(json['x']),
      y: _finite(json['y']),
      mime: mime is String ? mime : null,
      status: status is String ? status : null,
    );
  }
}

double? _finite(Object? value) {
  if (value is! num) return null;
  final d = value.toDouble();
  return d.isFinite ? d : null;
}

/// A nearest-neighbour link between two documents, from `GET /graph/edges`.
/// These are as of the last recluster, so either end may no longer exist.
class GraphEdgeData {
  const GraphEdgeData({
    required this.from,
    required this.to,
    this.distance,
    this.rank,
  });

  final String from;
  final String to;
  final double? distance;
  final int? rank;

  static GraphEdgeData? fromJson(Object? json) {
    if (json is! Map) return null;
    final from = json['document_id'];
    final to = json['neighbor_document_id'];
    if (from is! String || to is! String || from.isEmpty || to.isEmpty) {
      return null;
    }
    final rank = json['rank'];
    return GraphEdgeData(
      from: from,
      to: to,
      distance: _finite(json['distance']),
      rank: rank is int ? rank : null,
    );
  }
}

/// Everything the graph screen draws.
class GraphSnapshot {
  const GraphSnapshot({
    required this.nodes,
    required this.edges,
    this.edgesUnavailable = false,
  });

  final List<GraphNodeData> nodes;
  final List<GraphEdgeData> edges;

  /// The nodes loaded but the edges request failed: the graph is still worth
  /// showing, just without links.
  final bool edgesUnavailable;

  /// Whether any node carries a server-computed position.
  bool get isClustered => nodes.any((n) => n.hasPosition);
}

/// One chunk of a document, from `GET /graph/nodes/{id}/chunks`: a passage
/// of text (or, for an image, its description) that retrieval can cite.
class ChunkSatellite {
  const ChunkSatellite({
    required this.id,
    required this.ordinal,
    required this.content,
    this.page,
    this.regionType,
  });

  final String id;
  final int ordinal;

  /// May be empty (an image with no description) or very long (a whole
  /// section of a Markdown file), so callers truncate what they show.
  final String content;

  /// 1-based page in the source, when the source has pages.
  final int? page;

  /// What kind of region this was cut from (`paragraph`, `heading`, …).
  final String? regionType;

  /// [content] on one line, cut to [max] characters.
  String preview([int max = 140]) {
    final flat = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.isEmpty) return '(no text)';
    return flat.length <= max ? flat : '${flat.substring(0, max).trimRight()}…';
  }

  /// Null when the row has no usable id.
  static ChunkSatellite? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final ordinal = json['ordinal'];
    final content = json['content'];
    final meta = json['meta'];
    final page = meta is Map ? meta['page'] : null;
    final region = meta is Map ? meta['region_type'] : null;
    return ChunkSatellite(
      id: id,
      ordinal: ordinal is num ? ordinal.toInt() : 0,
      content: content is String ? content : '',
      page: page is num ? page.toInt() : null,
      regionType: region is String && region.isNotEmpty ? region : null,
    );
  }
}
