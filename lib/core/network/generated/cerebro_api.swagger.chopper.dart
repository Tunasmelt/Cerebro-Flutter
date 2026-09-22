// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'cerebro_api.swagger.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$CerebroApi extends CerebroApi {
  _$CerebroApi([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = CerebroApi;

  @override
  Future<Response<dynamic>> _apiV1DocumentsUploadInitPost({
    required UploadInitBody? body,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '',
      summary: 'Upload Init',
      operationId: 'upload_init_api_v1_documents_upload_init_post',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/documents/upload-init');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1DocumentsDocumentIdUploadConfirmPost({
    required String? documentId,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '',
      summary: 'Upload Confirm',
      operationId:
          'upload_confirm_api_v1_documents__document_id__upload_confirm_post',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse(
      '/api/v1/documents/${documentId}/upload-confirm',
    );
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1DocumentsCapturePost({
    required CaptureBody? body,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description:
          '''Stage 5.5 — quick capture: a persistent, always-available way to
get a thought into the vault without going through the file-upload
flow. Feeds the same extract -> embed pipeline every uploaded
document does (_run_capture_pipeline), just skipping normalize —
see documents_storage.py\'s create_capture for why.''',
      summary: 'Capture',
      operationId: 'capture_api_v1_documents_capture_post',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/documents/capture');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1DocumentsGet({
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '',
      summary: 'List Documents',
      operationId: 'list_documents_api_v1_documents_get',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/documents');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1DocumentsDocumentIdRetryIngestPost({
    required String? documentId,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description:
          '''Retries a failed ingest job from wherever it\'s safe to resume —
see check_retry_eligible\'s docstring for the embedding vs.
normalizing/extracting split (Stage 7.5 closed the gap where only
embed-stage failures were retryable).''',
      summary: 'Retry Ingest',
      operationId:
          'retry_ingest_api_v1_documents__document_id__retry_ingest_post',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/documents/${documentId}/retry-ingest');
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1DocumentsDocumentIdGet({
    required String? documentId,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description:
          '''Stage 3.6 — ingest_state/last_error are folded in directly rather
than a separate GET /ingest-jobs/{id}: the frontend only ever has a
document_id to poll with, never a raw ingest_jobs.id, so a second
endpoint keyed by a different id space would add surface without
adding capability.''',
      summary: 'Get Document',
      operationId: 'get_document_api_v1_documents__document_id__get',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/documents/${documentId}');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1DocumentsDocumentIdPatch({
    required String? documentId,
    required RenameDocumentBody? body,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '',
      summary: 'Rename Document',
      operationId: 'rename_document_api_v1_documents__document_id__patch',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/documents/${documentId}');
    final $body = body;
    final Request $request = Request(
      'PATCH',
      $url,
      client.baseUrl,
      body: $body,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1DocumentsDocumentIdDelete({
    required String? documentId,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description:
          '''Deletes both Storage objects (best-effort) then the documents
row, which cascades chunks/sealed_chunks/ingest_jobs/
document_clusters/document_edges/unlock_claims via each table\'s own
FK — no new migration needed, every cascade was already declared.
Works on sealed documents too; deleting only requires ownership
(RLS), never the passphrase.''',
      summary: 'Delete Document',
      operationId: 'delete_document_api_v1_documents__document_id__delete',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/documents/${documentId}');
    final Request $request = Request(
      'DELETE',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1DocumentsDocumentIdDownloadGet({
    required String? documentId,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description:
          '''Signed URL to the normalized (indexed) file. A sealed document
rejects this with 423 — sealing (Stage 3.3) only ever removed
plaintext from `chunks`, never re-encrypted the Storage object
itself, so a signed URL here would bypass the passphrase entirely
if not blocked explicitly.''',
      summary: 'Download Document',
      operationId:
          'download_document_api_v1_documents__document_id__download_get',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/documents/${documentId}/download');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1DocumentsDocumentIdOriginalGet({
    required String? documentId,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description:
          'Same sealed-document rejection as /download, same reasoning.',
      summary: 'Download Original',
      operationId:
          'download_original_api_v1_documents__document_id__original_get',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/documents/${documentId}/original');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1DocumentsDocumentIdExtractActionItemsPost({
    required String? documentId,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description:
          '''Stage 4.6 — single-document action-item extraction. Returns
candidates only; nothing is persisted here. Confirming a candidate
is a normal POST /boards/{id}/cards with document_id set to this
document (Stage 4.2\'s route already accepts it) — no separate
confirm endpoint exists because none was needed.''',
      summary: 'Extract Action Items Route',
      operationId:
          'extract_action_items_route_api_v1_documents__document_id__extract_action_items_post',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse(
      '/api/v1/documents/${documentId}/extract-action-items',
    );
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1ChatSessionsGet({
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '',
      summary: 'List Sessions',
      operationId: 'list_sessions_api_v1_chat_sessions_get',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/chat/sessions');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1ChatSessionsPost({
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '',
      summary: 'Create Session',
      operationId: 'create_session_api_v1_chat_sessions_post',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/chat/sessions');
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1ChatSessionsSessionIdDelete({
    required String? sessionId,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description:
          '''Chat management pass — deleting a session cascades its messages
(chat_messages.session_id already has on delete cascade, Stage
0.2\'s original schema). RLS-scoped: a session that isn\'t the
caller\'s own deletes zero rows, same 404-not-403 pattern every
other delete route in this app uses.''',
      summary: 'Delete Session',
      operationId: 'delete_session_api_v1_chat_sessions__session_id__delete',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/chat/sessions/${sessionId}');
    final Request $request = Request(
      'DELETE',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1ChatSessionsSessionIdMessagesGet({
    required String? sessionId,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description:
          '''Stage 2.4 — history for reopening a past conversation, with each
message\'s retrieved_chunk_ids resolved to retrieved_document_ids so
the frontend can replay the same graph pulse that happened live,
without re-deriving anything from the (possibly different by now)
live retrieval pipeline. Each assistant message also carries a real
`citations` array (chunk_id/document_id/document_title, in
first-appearance order) — the chat-management pass\'s fix for a real
gap: reopening a conversation used to only ever pulse the graph,
never render the actual text with working citation chips.''',
      summary: 'Get Messages',
      operationId:
          'get_messages_api_v1_chat_sessions__session_id__messages_get',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/chat/sessions/${sessionId}/messages');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>>
  _apiV1ChatSessionsSessionIdMessagesMessageIdPromptGet({
    required String? sessionId,
    required String? messageId,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description:
          '''Stage 4.4 — read-only token/cost playground: reconstructs the
prompt actually sent for a past assistant message.''',
      summary: 'Get Prompt Breakdown',
      operationId:
          'get_prompt_breakdown_api_v1_chat_sessions__session_id__messages__message_id__prompt_get',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse(
      '/api/v1/chat/sessions/${sessionId}/messages/${messageId}/prompt',
    );
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1ChatSessionsSessionIdPlaygroundRunPost({
    required String? sessionId,
    required PlaygroundRunBody? body,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description:
          '''Stage 5.6 — the deferred, editable half of Stage 4.4\'s mockup: runs
a user-edited prompt for real against Gemini, scoped to a session the
caller owns (RLS via ChatPlaygroundStorage), never persisted.''',
      summary: 'Run Playground Prompt',
      operationId:
          'run_playground_prompt_api_v1_chat_sessions__session_id__playground_run_post',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse(
      '/api/v1/chat/sessions/${sessionId}/playground/run',
    );
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1ChatSessionsSessionIdStreamPost({
    required String? sessionId,
    required StreamBody? body,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '',
      summary: 'Stream',
      operationId: 'stream_api_v1_chat_sessions__session_id__stream_post',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/chat/sessions/${sessionId}/stream');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1ChatSessionsSessionIdAgentTurnPost({
    required String? sessionId,
    required AgentTurnBody? body,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description:
          '''Stage 4.5 (stretch) — a tool-calling turn separate from the normal
chat path: the model may call create_kanban_card against one of the
caller\'s own boards. Session-scoped the same way stream() is (404,
not 403, for a session that isn\'t the caller\'s).''',
      summary: 'Agent Turn',
      operationId:
          'agent_turn_api_v1_chat_sessions__session_id__agent_turn_post',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/chat/sessions/${sessionId}/agent-turn');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1GraphReclusterPost({
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '''Triggers a full re-cluster (Stage 2.1 — this stage always
recomputes everything; Stage 2.5 adds incremental placement for new
uploads instead of a full recompute every time). Runs as a
BackgroundTask, same in-process pattern as the ingest pipeline —
no separate worker, per CLAUDE.md\'s Render free-tier constraint.''',
      summary: 'Recluster',
      operationId: 'recluster_api_v1_graph_recluster_post',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/graph/recluster');
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1GraphNodesGet({
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '''Every ready document, current as of this call — a document
uploaded since the last recluster still appears (with cluster_id/x/y
null) rather than being missing, per the exit criteria\'s "no
stale/missing nodes after an upload or delete".''',
      summary: 'Nodes',
      operationId: 'nodes_api_v1_graph_nodes_get',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/graph/nodes');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1GraphEdgesGet({
    String? include,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '''kNN edges as of the last recluster run — these DO go stale
relative to new uploads until the next recluster, unlike nodes; see
architecture-and-security.md\'s Clustering pipeline section.

Stage 5.4 — ?include=associative additionally returns
associative_edges: Stage 5.3\'s chunk_edges aggregated up to
document pairs (a chunk-level table; the graph only shows document
nodes). Additive, not a breaking response shape change — the
`edges` key and its shape are exactly what they were before this
param existed, so every pre-5.4 caller keeps working unmodified.''',
      summary: 'Edges',
      operationId: 'edges_api_v1_graph_edges_get',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/graph/edges');
    final Map<String, dynamic> $params = <String, dynamic>{'include': include};
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1GraphNodesDocumentIdChunksGet({
    required String? documentId,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '',
      summary: 'Node Chunks',
      operationId: 'node_chunks_api_v1_graph_nodes__document_id__chunks_get',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/graph/nodes/${documentId}/chunks');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1ChunksChunkIdLinkPost({
    required String? chunkId,
    required LinkChunkBody? body,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description:
          '''Stage 5.3 — an explicit, user-drawn associative edge. Both chunks
must be the caller\'s own (RLS-scoped lookup inside
create_explicit_link, same pattern kanban_storage.create_card already
uses for board_id) — a chunk_id belonging to another user, or one
that no longer exists (e.g. a sealed document\'s, already deleted),
is indistinguishable from "not found" here, never a 403.''',
      summary: 'Link Chunk',
      operationId: 'link_chunk_api_v1_chunks__chunk_id__link_post',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/chunks/${chunkId}/link');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1DocumentsDocumentIdSealPost({
    required String? documentId,
    required SealBody? body,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '',
      summary: 'Seal Document',
      operationId: 'seal_document_api_v1_documents__document_id__seal_post',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/documents/${documentId}/seal');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1DocumentsDocumentIdSealSaltGet({
    required String? documentId,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description:
          '''The one piece of information the client needs before it can even
attempt an unlock: the salt its own passphrase must be re-derived
against. Not secret (see SupabaseSealedStorage.get_salt\'s docstring)
— RLS still scopes this to the caller\'s own document either way.''',
      summary: 'Get Seal Salt',
      operationId: 'get_seal_salt_api_v1_documents__document_id__seal_salt_get',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/documents/${documentId}/seal-salt');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1DocumentsDocumentIdUnlockPost({
    required String? documentId,
    required UnlockBody? body,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '',
      summary: 'Unlock Document',
      operationId: 'unlock_document_api_v1_documents__document_id__unlock_post',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/documents/${documentId}/unlock');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1DocumentsDocumentIdUnsealPost({
    required String? documentId,
    required UnsealBody? body,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '',
      summary: 'Unseal Document',
      operationId: 'unseal_document_api_v1_documents__document_id__unseal_post',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/documents/${documentId}/unseal');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1BoardsGet({
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '',
      summary: 'List Boards',
      operationId: 'list_boards_api_v1_boards_get',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/boards');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1BoardsPost({
    required CreateBoardBody? body,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '',
      summary: 'Create Board',
      operationId: 'create_board_api_v1_boards_post',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/boards');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1BoardsBoardIdGet({
    required String? boardId,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '',
      summary: 'Get Board',
      operationId: 'get_board_api_v1_boards__board_id__get',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/boards/${boardId}');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1BoardsBoardIdCardsPost({
    required String? boardId,
    required CreateCardBody? body,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '',
      summary: 'Create Card',
      operationId: 'create_card_api_v1_boards__board_id__cards_post',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/boards/${boardId}/cards');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1CardsCardIdPatch({
    required String? cardId,
    required UpdateCardBody? body,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description:
          '''Also the move/reorder endpoint — dragging a card to a new column
or a new spot within one is just a PATCH with a new column_name
and/or position, computed client-side (see kanban_storage.py\'s
module docstring for why position is a float).''',
      summary: 'Update Card',
      operationId: 'update_card_api_v1_cards__card_id__patch',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/cards/${cardId}');
    final $body = body;
    final Request $request = Request(
      'PATCH',
      $url,
      client.baseUrl,
      body: $body,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1CardsCardIdDelete({
    required String? cardId,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '',
      summary: 'Delete Card',
      operationId: 'delete_card_api_v1_cards__card_id__delete',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/cards/${cardId}');
    final Request $request = Request(
      'DELETE',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1TodosGet({
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '',
      summary: 'List Todos',
      operationId: 'list_todos_api_v1_todos_get',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/todos');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1TodosPost({
    required CreateTodoBody? body,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '',
      summary: 'Create Todo',
      operationId: 'create_todo_api_v1_todos_post',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/todos');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1TodosTodoIdPatch({
    required String? todoId,
    required UpdateTodoBody? body,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '',
      summary: 'Update Todo',
      operationId: 'update_todo_api_v1_todos__todo_id__patch',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/todos/${todoId}');
    final $body = body;
    final Request $request = Request(
      'PATCH',
      $url,
      client.baseUrl,
      body: $body,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1TodosTodoIdDelete({
    required String? todoId,
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '',
      summary: 'Delete Todo',
      operationId: 'delete_todo_api_v1_todos__todo_id__delete',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/todos/${todoId}');
    final Request $request = Request(
      'DELETE',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV1AccountDelete({
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description:
          '''Wipes all application data the caller owns. Does not delete the
auth account itself — see account_storage.py\'s module docstring for
why. Idempotent: calling this again on an already-empty account
deletes zero rows and still returns 200, never an error.''',
      summary: 'Wipe Account',
      operationId: 'wipe_account_api_v1_account_delete',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/account');
    final Request $request = Request(
      'DELETE',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<Object>> _healthGet({
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description: '',
      summary: 'Health',
      operationId: 'health_health_get',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/health');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<Object, Object>($request);
  }

  @override
  Future<Response<Object>> _apiV1ProbeGet({
    SwaggerMetaData swaggerMetaData = const SwaggerMetaData(
      description:
          '''Stage 0.5 probe route — proves AuthMiddleware actually reaches a
handler on a valid token, not a real product endpoint.''',
      summary: 'Probe',
      operationId: 'probe_api_v1__probe_get',
      consumes: [],
      produces: [],
      security: [],
      tags: [],
      deprecated: false,
    ),
  }) {
    final Uri $url = Uri.parse('/api/v1/_probe');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      tag: swaggerMetaData,
    );
    return client.send<Object, Object>($request);
  }
}
