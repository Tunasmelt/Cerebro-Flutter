// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element_parameter

import 'package:json_annotation/json_annotation.dart';
import 'package:json_annotation/json_annotation.dart' as json;
import 'package:collection/collection.dart';
import 'dart:convert';

import 'package:chopper/chopper.dart';

import 'client_mapping.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http/http.dart' show MultipartFile;
import 'package:chopper/chopper.dart' as chopper;
import 'cerebro_api.enums.swagger.dart' as enums;
import 'cerebro_api.metadata.swagger.dart';
export 'cerebro_api.enums.swagger.dart';

part 'cerebro_api.swagger.chopper.dart';
part 'cerebro_api.swagger.g.dart';

// **************************************************************************
// SwaggerChopperGenerator
// **************************************************************************

@ChopperApi()
abstract class CerebroApi extends ChopperService {
  static CerebroApi create({
    ChopperClient? client,
    http.Client? httpClient,
    Authenticator? authenticator,
    ErrorConverter? errorConverter,
    Converter? converter,
    Uri? baseUrl,
    List<Interceptor>? interceptors,
  }) {
    if (client != null) {
      return _$CerebroApi(client);
    }

    final newClient = ChopperClient(
      services: [_$CerebroApi()],
      converter: converter ?? $JsonSerializableConverter(),
      interceptors: interceptors ?? [],
      client: httpClient,
      authenticator: authenticator,
      errorConverter: errorConverter,
      baseUrl: baseUrl,
    );
    return _$CerebroApi(newClient);
  }

  ///Upload Init
  Future<chopper.Response> apiV1DocumentsUploadInitPost({
    required UploadInitBody? body,
  }) {
    return _apiV1DocumentsUploadInitPost(body: body);
  }

  ///Upload Init
  @POST(path: '/api/v1/documents/upload-init', optionalBody: true)
  Future<chopper.Response> _apiV1DocumentsUploadInitPost({
    @Body() required UploadInitBody? body,
    @chopper.Tag()
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
  });

  ///Upload Confirm
  ///@param document_id
  Future<chopper.Response> apiV1DocumentsDocumentIdUploadConfirmPost({
    required String? documentId,
  }) {
    return _apiV1DocumentsDocumentIdUploadConfirmPost(documentId: documentId);
  }

  ///Upload Confirm
  ///@param document_id
  @POST(
    path: '/api/v1/documents/{document_id}/upload-confirm',
    optionalBody: true,
  )
  Future<chopper.Response> _apiV1DocumentsDocumentIdUploadConfirmPost({
    @Path('document_id') required String? documentId,
    @chopper.Tag()
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
  });

  ///Capture
  Future<chopper.Response> apiV1DocumentsCapturePost({
    required CaptureBody? body,
  }) {
    return _apiV1DocumentsCapturePost(body: body);
  }

  ///Capture
  @POST(path: '/api/v1/documents/capture', optionalBody: true)
  Future<chopper.Response> _apiV1DocumentsCapturePost({
    @Body() required CaptureBody? body,
    @chopper.Tag()
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
  });

  ///List Documents
  Future<chopper.Response> apiV1DocumentsGet() {
    return _apiV1DocumentsGet();
  }

  ///List Documents
  @GET(path: '/api/v1/documents')
  Future<chopper.Response> _apiV1DocumentsGet({
    @chopper.Tag()
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
  });

  ///Retry Ingest
  ///@param document_id
  Future<chopper.Response> apiV1DocumentsDocumentIdRetryIngestPost({
    required String? documentId,
  }) {
    return _apiV1DocumentsDocumentIdRetryIngestPost(documentId: documentId);
  }

  ///Retry Ingest
  ///@param document_id
  @POST(
    path: '/api/v1/documents/{document_id}/retry-ingest',
    optionalBody: true,
  )
  Future<chopper.Response> _apiV1DocumentsDocumentIdRetryIngestPost({
    @Path('document_id') required String? documentId,
    @chopper.Tag()
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
  });

  ///Get Document
  ///@param document_id
  Future<chopper.Response> apiV1DocumentsDocumentIdGet({
    required String? documentId,
  }) {
    return _apiV1DocumentsDocumentIdGet(documentId: documentId);
  }

  ///Get Document
  ///@param document_id
  @GET(path: '/api/v1/documents/{document_id}')
  Future<chopper.Response> _apiV1DocumentsDocumentIdGet({
    @Path('document_id') required String? documentId,
    @chopper.Tag()
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
  });

  ///Rename Document
  ///@param document_id
  Future<chopper.Response> apiV1DocumentsDocumentIdPatch({
    required String? documentId,
    required RenameDocumentBody? body,
  }) {
    return _apiV1DocumentsDocumentIdPatch(documentId: documentId, body: body);
  }

  ///Rename Document
  ///@param document_id
  @PATCH(path: '/api/v1/documents/{document_id}', optionalBody: true)
  Future<chopper.Response> _apiV1DocumentsDocumentIdPatch({
    @Path('document_id') required String? documentId,
    @Body() required RenameDocumentBody? body,
    @chopper.Tag()
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
  });

  ///Delete Document
  ///@param document_id
  Future<chopper.Response> apiV1DocumentsDocumentIdDelete({
    required String? documentId,
  }) {
    return _apiV1DocumentsDocumentIdDelete(documentId: documentId);
  }

  ///Delete Document
  ///@param document_id
  @DELETE(path: '/api/v1/documents/{document_id}')
  Future<chopper.Response> _apiV1DocumentsDocumentIdDelete({
    @Path('document_id') required String? documentId,
    @chopper.Tag()
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
  });

  ///Download Document
  ///@param document_id
  Future<chopper.Response> apiV1DocumentsDocumentIdDownloadGet({
    required String? documentId,
  }) {
    return _apiV1DocumentsDocumentIdDownloadGet(documentId: documentId);
  }

  ///Download Document
  ///@param document_id
  @GET(path: '/api/v1/documents/{document_id}/download')
  Future<chopper.Response> _apiV1DocumentsDocumentIdDownloadGet({
    @Path('document_id') required String? documentId,
    @chopper.Tag()
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
  });

  ///Download Original
  ///@param document_id
  Future<chopper.Response> apiV1DocumentsDocumentIdOriginalGet({
    required String? documentId,
  }) {
    return _apiV1DocumentsDocumentIdOriginalGet(documentId: documentId);
  }

  ///Download Original
  ///@param document_id
  @GET(path: '/api/v1/documents/{document_id}/original')
  Future<chopper.Response> _apiV1DocumentsDocumentIdOriginalGet({
    @Path('document_id') required String? documentId,
    @chopper.Tag()
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
  });

  ///Extract Action Items Route
  ///@param document_id
  Future<chopper.Response> apiV1DocumentsDocumentIdExtractActionItemsPost({
    required String? documentId,
  }) {
    return _apiV1DocumentsDocumentIdExtractActionItemsPost(
      documentId: documentId,
    );
  }

  ///Extract Action Items Route
  ///@param document_id
  @POST(
    path: '/api/v1/documents/{document_id}/extract-action-items',
    optionalBody: true,
  )
  Future<chopper.Response> _apiV1DocumentsDocumentIdExtractActionItemsPost({
    @Path('document_id') required String? documentId,
    @chopper.Tag()
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
  });

  ///List Sessions
  Future<chopper.Response> apiV1ChatSessionsGet() {
    return _apiV1ChatSessionsGet();
  }

  ///List Sessions
  @GET(path: '/api/v1/chat/sessions')
  Future<chopper.Response> _apiV1ChatSessionsGet({
    @chopper.Tag()
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
  });

  ///Create Session
  Future<chopper.Response> apiV1ChatSessionsPost() {
    return _apiV1ChatSessionsPost();
  }

  ///Create Session
  @POST(path: '/api/v1/chat/sessions', optionalBody: true)
  Future<chopper.Response> _apiV1ChatSessionsPost({
    @chopper.Tag()
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
  });

  ///Delete Session
  ///@param session_id
  Future<chopper.Response> apiV1ChatSessionsSessionIdDelete({
    required String? sessionId,
  }) {
    return _apiV1ChatSessionsSessionIdDelete(sessionId: sessionId);
  }

  ///Delete Session
  ///@param session_id
  @DELETE(path: '/api/v1/chat/sessions/{session_id}')
  Future<chopper.Response> _apiV1ChatSessionsSessionIdDelete({
    @Path('session_id') required String? sessionId,
    @chopper.Tag()
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
  });

  ///Get Messages
  ///@param session_id
  Future<chopper.Response> apiV1ChatSessionsSessionIdMessagesGet({
    required String? sessionId,
  }) {
    return _apiV1ChatSessionsSessionIdMessagesGet(sessionId: sessionId);
  }

  ///Get Messages
  ///@param session_id
  @GET(path: '/api/v1/chat/sessions/{session_id}/messages')
  Future<chopper.Response> _apiV1ChatSessionsSessionIdMessagesGet({
    @Path('session_id') required String? sessionId,
    @chopper.Tag()
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
  });

  ///Get Prompt Breakdown
  ///@param session_id
  ///@param message_id
  Future<chopper.Response>
  apiV1ChatSessionsSessionIdMessagesMessageIdPromptGet({
    required String? sessionId,
    required String? messageId,
  }) {
    return _apiV1ChatSessionsSessionIdMessagesMessageIdPromptGet(
      sessionId: sessionId,
      messageId: messageId,
    );
  }

  ///Get Prompt Breakdown
  ///@param session_id
  ///@param message_id
  @GET(path: '/api/v1/chat/sessions/{session_id}/messages/{message_id}/prompt')
  Future<chopper.Response>
  _apiV1ChatSessionsSessionIdMessagesMessageIdPromptGet({
    @Path('session_id') required String? sessionId,
    @Path('message_id') required String? messageId,
    @chopper.Tag()
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
  });

  ///Run Playground Prompt
  ///@param session_id
  Future<chopper.Response> apiV1ChatSessionsSessionIdPlaygroundRunPost({
    required String? sessionId,
    required PlaygroundRunBody? body,
  }) {
    return _apiV1ChatSessionsSessionIdPlaygroundRunPost(
      sessionId: sessionId,
      body: body,
    );
  }

  ///Run Playground Prompt
  ///@param session_id
  @POST(
    path: '/api/v1/chat/sessions/{session_id}/playground/run',
    optionalBody: true,
  )
  Future<chopper.Response> _apiV1ChatSessionsSessionIdPlaygroundRunPost({
    @Path('session_id') required String? sessionId,
    @Body() required PlaygroundRunBody? body,
    @chopper.Tag()
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
  });

  ///Stream
  ///@param session_id
  Future<chopper.Response> apiV1ChatSessionsSessionIdStreamPost({
    required String? sessionId,
    required StreamBody? body,
  }) {
    return _apiV1ChatSessionsSessionIdStreamPost(
      sessionId: sessionId,
      body: body,
    );
  }

  ///Stream
  ///@param session_id
  @POST(path: '/api/v1/chat/sessions/{session_id}/stream', optionalBody: true)
  Future<chopper.Response> _apiV1ChatSessionsSessionIdStreamPost({
    @Path('session_id') required String? sessionId,
    @Body() required StreamBody? body,
    @chopper.Tag()
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
  });

  ///Agent Turn
  ///@param session_id
  Future<chopper.Response> apiV1ChatSessionsSessionIdAgentTurnPost({
    required String? sessionId,
    required AgentTurnBody? body,
  }) {
    return _apiV1ChatSessionsSessionIdAgentTurnPost(
      sessionId: sessionId,
      body: body,
    );
  }

  ///Agent Turn
  ///@param session_id
  @POST(
    path: '/api/v1/chat/sessions/{session_id}/agent-turn',
    optionalBody: true,
  )
  Future<chopper.Response> _apiV1ChatSessionsSessionIdAgentTurnPost({
    @Path('session_id') required String? sessionId,
    @Body() required AgentTurnBody? body,
    @chopper.Tag()
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
  });

  ///Recluster
  Future<chopper.Response> apiV1GraphReclusterPost() {
    return _apiV1GraphReclusterPost();
  }

  ///Recluster
  @POST(path: '/api/v1/graph/recluster', optionalBody: true)
  Future<chopper.Response> _apiV1GraphReclusterPost({
    @chopper.Tag()
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
  });

  ///Nodes
  Future<chopper.Response> apiV1GraphNodesGet() {
    return _apiV1GraphNodesGet();
  }

  ///Nodes
  @GET(path: '/api/v1/graph/nodes')
  Future<chopper.Response> _apiV1GraphNodesGet({
    @chopper.Tag()
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
  });

  ///Edges
  ///@param include
  Future<chopper.Response> apiV1GraphEdgesGet({String? include}) {
    return _apiV1GraphEdgesGet(include: include);
  }

  ///Edges
  ///@param include
  @GET(path: '/api/v1/graph/edges')
  Future<chopper.Response> _apiV1GraphEdgesGet({
    @Query('include') String? include,
    @chopper.Tag()
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
  });

  ///Node Chunks
  ///@param document_id
  Future<chopper.Response> apiV1GraphNodesDocumentIdChunksGet({
    required String? documentId,
  }) {
    return _apiV1GraphNodesDocumentIdChunksGet(documentId: documentId);
  }

  ///Node Chunks
  ///@param document_id
  @GET(path: '/api/v1/graph/nodes/{document_id}/chunks')
  Future<chopper.Response> _apiV1GraphNodesDocumentIdChunksGet({
    @Path('document_id') required String? documentId,
    @chopper.Tag()
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
  });

  ///Link Chunk
  ///@param chunk_id
  Future<chopper.Response> apiV1ChunksChunkIdLinkPost({
    required String? chunkId,
    required LinkChunkBody? body,
  }) {
    return _apiV1ChunksChunkIdLinkPost(chunkId: chunkId, body: body);
  }

  ///Link Chunk
  ///@param chunk_id
  @POST(path: '/api/v1/chunks/{chunk_id}/link', optionalBody: true)
  Future<chopper.Response> _apiV1ChunksChunkIdLinkPost({
    @Path('chunk_id') required String? chunkId,
    @Body() required LinkChunkBody? body,
    @chopper.Tag()
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
  });

  ///Seal Document
  ///@param document_id
  Future<chopper.Response> apiV1DocumentsDocumentIdSealPost({
    required String? documentId,
    required SealBody? body,
  }) {
    return _apiV1DocumentsDocumentIdSealPost(
      documentId: documentId,
      body: body,
    );
  }

  ///Seal Document
  ///@param document_id
  @POST(path: '/api/v1/documents/{document_id}/seal', optionalBody: true)
  Future<chopper.Response> _apiV1DocumentsDocumentIdSealPost({
    @Path('document_id') required String? documentId,
    @Body() required SealBody? body,
    @chopper.Tag()
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
  });

  ///Get Seal Salt
  ///@param document_id
  Future<chopper.Response> apiV1DocumentsDocumentIdSealSaltGet({
    required String? documentId,
  }) {
    return _apiV1DocumentsDocumentIdSealSaltGet(documentId: documentId);
  }

  ///Get Seal Salt
  ///@param document_id
  @GET(path: '/api/v1/documents/{document_id}/seal-salt')
  Future<chopper.Response> _apiV1DocumentsDocumentIdSealSaltGet({
    @Path('document_id') required String? documentId,
    @chopper.Tag()
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
  });

  ///Unlock Document
  ///@param document_id
  Future<chopper.Response> apiV1DocumentsDocumentIdUnlockPost({
    required String? documentId,
    required UnlockBody? body,
  }) {
    return _apiV1DocumentsDocumentIdUnlockPost(
      documentId: documentId,
      body: body,
    );
  }

  ///Unlock Document
  ///@param document_id
  @POST(path: '/api/v1/documents/{document_id}/unlock', optionalBody: true)
  Future<chopper.Response> _apiV1DocumentsDocumentIdUnlockPost({
    @Path('document_id') required String? documentId,
    @Body() required UnlockBody? body,
    @chopper.Tag()
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
  });

  ///Unseal Document
  ///@param document_id
  Future<chopper.Response> apiV1DocumentsDocumentIdUnsealPost({
    required String? documentId,
    required UnsealBody? body,
  }) {
    return _apiV1DocumentsDocumentIdUnsealPost(
      documentId: documentId,
      body: body,
    );
  }

  ///Unseal Document
  ///@param document_id
  @POST(path: '/api/v1/documents/{document_id}/unseal', optionalBody: true)
  Future<chopper.Response> _apiV1DocumentsDocumentIdUnsealPost({
    @Path('document_id') required String? documentId,
    @Body() required UnsealBody? body,
    @chopper.Tag()
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
  });

  ///List Boards
  Future<chopper.Response> apiV1BoardsGet() {
    return _apiV1BoardsGet();
  }

  ///List Boards
  @GET(path: '/api/v1/boards')
  Future<chopper.Response> _apiV1BoardsGet({
    @chopper.Tag()
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
  });

  ///Create Board
  Future<chopper.Response> apiV1BoardsPost({required CreateBoardBody? body}) {
    return _apiV1BoardsPost(body: body);
  }

  ///Create Board
  @POST(path: '/api/v1/boards', optionalBody: true)
  Future<chopper.Response> _apiV1BoardsPost({
    @Body() required CreateBoardBody? body,
    @chopper.Tag()
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
  });

  ///Get Board
  ///@param board_id
  Future<chopper.Response> apiV1BoardsBoardIdGet({required String? boardId}) {
    return _apiV1BoardsBoardIdGet(boardId: boardId);
  }

  ///Get Board
  ///@param board_id
  @GET(path: '/api/v1/boards/{board_id}')
  Future<chopper.Response> _apiV1BoardsBoardIdGet({
    @Path('board_id') required String? boardId,
    @chopper.Tag()
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
  });

  ///Create Card
  ///@param board_id
  Future<chopper.Response> apiV1BoardsBoardIdCardsPost({
    required String? boardId,
    required CreateCardBody? body,
  }) {
    return _apiV1BoardsBoardIdCardsPost(boardId: boardId, body: body);
  }

  ///Create Card
  ///@param board_id
  @POST(path: '/api/v1/boards/{board_id}/cards', optionalBody: true)
  Future<chopper.Response> _apiV1BoardsBoardIdCardsPost({
    @Path('board_id') required String? boardId,
    @Body() required CreateCardBody? body,
    @chopper.Tag()
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
  });

  ///Update Card
  ///@param card_id
  Future<chopper.Response> apiV1CardsCardIdPatch({
    required String? cardId,
    required UpdateCardBody? body,
  }) {
    return _apiV1CardsCardIdPatch(cardId: cardId, body: body);
  }

  ///Update Card
  ///@param card_id
  @PATCH(path: '/api/v1/cards/{card_id}', optionalBody: true)
  Future<chopper.Response> _apiV1CardsCardIdPatch({
    @Path('card_id') required String? cardId,
    @Body() required UpdateCardBody? body,
    @chopper.Tag()
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
  });

  ///Delete Card
  ///@param card_id
  Future<chopper.Response> apiV1CardsCardIdDelete({required String? cardId}) {
    return _apiV1CardsCardIdDelete(cardId: cardId);
  }

  ///Delete Card
  ///@param card_id
  @DELETE(path: '/api/v1/cards/{card_id}')
  Future<chopper.Response> _apiV1CardsCardIdDelete({
    @Path('card_id') required String? cardId,
    @chopper.Tag()
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
  });

  ///List Todos
  Future<chopper.Response> apiV1TodosGet() {
    return _apiV1TodosGet();
  }

  ///List Todos
  @GET(path: '/api/v1/todos')
  Future<chopper.Response> _apiV1TodosGet({
    @chopper.Tag()
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
  });

  ///Create Todo
  Future<chopper.Response> apiV1TodosPost({required CreateTodoBody? body}) {
    return _apiV1TodosPost(body: body);
  }

  ///Create Todo
  @POST(path: '/api/v1/todos', optionalBody: true)
  Future<chopper.Response> _apiV1TodosPost({
    @Body() required CreateTodoBody? body,
    @chopper.Tag()
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
  });

  ///Update Todo
  ///@param todo_id
  Future<chopper.Response> apiV1TodosTodoIdPatch({
    required String? todoId,
    required UpdateTodoBody? body,
  }) {
    return _apiV1TodosTodoIdPatch(todoId: todoId, body: body);
  }

  ///Update Todo
  ///@param todo_id
  @PATCH(path: '/api/v1/todos/{todo_id}', optionalBody: true)
  Future<chopper.Response> _apiV1TodosTodoIdPatch({
    @Path('todo_id') required String? todoId,
    @Body() required UpdateTodoBody? body,
    @chopper.Tag()
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
  });

  ///Delete Todo
  ///@param todo_id
  Future<chopper.Response> apiV1TodosTodoIdDelete({required String? todoId}) {
    return _apiV1TodosTodoIdDelete(todoId: todoId);
  }

  ///Delete Todo
  ///@param todo_id
  @DELETE(path: '/api/v1/todos/{todo_id}')
  Future<chopper.Response> _apiV1TodosTodoIdDelete({
    @Path('todo_id') required String? todoId,
    @chopper.Tag()
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
  });

  ///Wipe Account
  Future<chopper.Response> apiV1AccountDelete() {
    return _apiV1AccountDelete();
  }

  ///Wipe Account
  @DELETE(path: '/api/v1/account')
  Future<chopper.Response> _apiV1AccountDelete({
    @chopper.Tag()
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
  });

  ///Health
  Future<chopper.Response<Object>> healthGet() {
    return _healthGet();
  }

  ///Health
  @GET(path: '/health')
  Future<chopper.Response<Object>> _healthGet({
    @chopper.Tag()
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
  });

  ///Probe
  Future<chopper.Response<Object>> apiV1ProbeGet() {
    return _apiV1ProbeGet();
  }

  ///Probe
  @GET(path: '/api/v1/_probe')
  Future<chopper.Response<Object>> _apiV1ProbeGet({
    @chopper.Tag()
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
  });
}

@JsonSerializable(explicitToJson: true)
class AgentTurnBody {
  const AgentTurnBody({required this.message});

  factory AgentTurnBody.fromJson(Map<String, dynamic> json) =>
      _$AgentTurnBodyFromJson(json);

  static const toJsonFactory = _$AgentTurnBodyToJson;
  Map<String, dynamic> toJson() => _$AgentTurnBodyToJson(this);

  @JsonKey(name: 'message')
  final String message;
  static const fromJsonFactory = _$AgentTurnBodyFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is AgentTurnBody &&
            (identical(other.message, message) ||
                const DeepCollectionEquality().equals(other.message, message)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(message) ^ runtimeType.hashCode;
}

extension $AgentTurnBodyExtension on AgentTurnBody {
  AgentTurnBody copyWith({String? message}) {
    return AgentTurnBody(message: message ?? this.message);
  }

  AgentTurnBody copyWithWrapped({Wrapped<String>? message}) {
    return AgentTurnBody(
      message: (message != null ? message.value : this.message),
    );
  }
}

@JsonSerializable(explicitToJson: true)
class CaptureBody {
  const CaptureBody({required this.text, this.title});

  factory CaptureBody.fromJson(Map<String, dynamic> json) =>
      _$CaptureBodyFromJson(json);

  static const toJsonFactory = _$CaptureBodyToJson;
  Map<String, dynamic> toJson() => _$CaptureBodyToJson(this);

  @JsonKey(name: 'text')
  final String text;
  @JsonKey(name: 'title')
  final String? title;
  static const fromJsonFactory = _$CaptureBodyFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is CaptureBody &&
            (identical(other.text, text) ||
                const DeepCollectionEquality().equals(other.text, text)) &&
            (identical(other.title, title) ||
                const DeepCollectionEquality().equals(other.title, title)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(text) ^
      const DeepCollectionEquality().hash(title) ^
      runtimeType.hashCode;
}

extension $CaptureBodyExtension on CaptureBody {
  CaptureBody copyWith({String? text, String? title}) {
    return CaptureBody(text: text ?? this.text, title: title ?? this.title);
  }

  CaptureBody copyWithWrapped({
    Wrapped<String>? text,
    Wrapped<String?>? title,
  }) {
    return CaptureBody(
      text: (text != null ? text.value : this.text),
      title: (title != null ? title.value : this.title),
    );
  }
}

@JsonSerializable(explicitToJson: true)
class CreateBoardBody {
  const CreateBoardBody({required this.title});

  factory CreateBoardBody.fromJson(Map<String, dynamic> json) =>
      _$CreateBoardBodyFromJson(json);

  static const toJsonFactory = _$CreateBoardBodyToJson;
  Map<String, dynamic> toJson() => _$CreateBoardBodyToJson(this);

  @JsonKey(name: 'title')
  final String title;
  static const fromJsonFactory = _$CreateBoardBodyFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is CreateBoardBody &&
            (identical(other.title, title) ||
                const DeepCollectionEquality().equals(other.title, title)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(title) ^ runtimeType.hashCode;
}

extension $CreateBoardBodyExtension on CreateBoardBody {
  CreateBoardBody copyWith({String? title}) {
    return CreateBoardBody(title: title ?? this.title);
  }

  CreateBoardBody copyWithWrapped({Wrapped<String>? title}) {
    return CreateBoardBody(title: (title != null ? title.value : this.title));
  }
}

@JsonSerializable(explicitToJson: true)
class CreateCardBody {
  const CreateCardBody({
    required this.columnName,
    required this.title,
    this.description,
    this.documentId,
  });

  factory CreateCardBody.fromJson(Map<String, dynamic> json) =>
      _$CreateCardBodyFromJson(json);

  static const toJsonFactory = _$CreateCardBodyToJson;
  Map<String, dynamic> toJson() => _$CreateCardBodyToJson(this);

  @JsonKey(name: 'column_name')
  final String columnName;
  @JsonKey(name: 'title')
  final String title;
  @JsonKey(name: 'description')
  final String? description;
  @JsonKey(name: 'document_id')
  final String? documentId;
  static const fromJsonFactory = _$CreateCardBodyFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is CreateCardBody &&
            (identical(other.columnName, columnName) ||
                const DeepCollectionEquality().equals(
                  other.columnName,
                  columnName,
                )) &&
            (identical(other.title, title) ||
                const DeepCollectionEquality().equals(other.title, title)) &&
            (identical(other.description, description) ||
                const DeepCollectionEquality().equals(
                  other.description,
                  description,
                )) &&
            (identical(other.documentId, documentId) ||
                const DeepCollectionEquality().equals(
                  other.documentId,
                  documentId,
                )));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(columnName) ^
      const DeepCollectionEquality().hash(title) ^
      const DeepCollectionEquality().hash(description) ^
      const DeepCollectionEquality().hash(documentId) ^
      runtimeType.hashCode;
}

extension $CreateCardBodyExtension on CreateCardBody {
  CreateCardBody copyWith({
    String? columnName,
    String? title,
    String? description,
    String? documentId,
  }) {
    return CreateCardBody(
      columnName: columnName ?? this.columnName,
      title: title ?? this.title,
      description: description ?? this.description,
      documentId: documentId ?? this.documentId,
    );
  }

  CreateCardBody copyWithWrapped({
    Wrapped<String>? columnName,
    Wrapped<String>? title,
    Wrapped<String?>? description,
    Wrapped<String?>? documentId,
  }) {
    return CreateCardBody(
      columnName: (columnName != null ? columnName.value : this.columnName),
      title: (title != null ? title.value : this.title),
      description: (description != null ? description.value : this.description),
      documentId: (documentId != null ? documentId.value : this.documentId),
    );
  }
}

@JsonSerializable(explicitToJson: true)
class CreateTodoBody {
  const CreateTodoBody({required this.title, this.documentId, this.priority});

  factory CreateTodoBody.fromJson(Map<String, dynamic> json) =>
      _$CreateTodoBodyFromJson(json);

  static const toJsonFactory = _$CreateTodoBodyToJson;
  Map<String, dynamic> toJson() => _$CreateTodoBodyToJson(this);

  @JsonKey(name: 'title')
  final String title;
  @JsonKey(name: 'document_id')
  final String? documentId;
  @JsonKey(
    name: 'priority',
    toJson: createTodoBodyPriorityNullableToJson,
    fromJson: createTodoBodyPriorityPriorityNullableFromJson,
  )
  final enums.CreateTodoBodyPriority? priority;
  static enums.CreateTodoBodyPriority?
  createTodoBodyPriorityPriorityNullableFromJson(Object? value) =>
      createTodoBodyPriorityNullableFromJson(
        value,
        enums.CreateTodoBodyPriority.medium,
      );

  static const fromJsonFactory = _$CreateTodoBodyFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is CreateTodoBody &&
            (identical(other.title, title) ||
                const DeepCollectionEquality().equals(other.title, title)) &&
            (identical(other.documentId, documentId) ||
                const DeepCollectionEquality().equals(
                  other.documentId,
                  documentId,
                )) &&
            (identical(other.priority, priority) ||
                const DeepCollectionEquality().equals(
                  other.priority,
                  priority,
                )));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(title) ^
      const DeepCollectionEquality().hash(documentId) ^
      const DeepCollectionEquality().hash(priority) ^
      runtimeType.hashCode;
}

extension $CreateTodoBodyExtension on CreateTodoBody {
  CreateTodoBody copyWith({
    String? title,
    String? documentId,
    enums.CreateTodoBodyPriority? priority,
  }) {
    return CreateTodoBody(
      title: title ?? this.title,
      documentId: documentId ?? this.documentId,
      priority: priority ?? this.priority,
    );
  }

  CreateTodoBody copyWithWrapped({
    Wrapped<String>? title,
    Wrapped<String?>? documentId,
    Wrapped<enums.CreateTodoBodyPriority?>? priority,
  }) {
    return CreateTodoBody(
      title: (title != null ? title.value : this.title),
      documentId: (documentId != null ? documentId.value : this.documentId),
      priority: (priority != null ? priority.value : this.priority),
    );
  }
}

@JsonSerializable(explicitToJson: true)
class HTTPValidationError {
  const HTTPValidationError({this.detail});

  factory HTTPValidationError.fromJson(Map<String, dynamic> json) =>
      _$HTTPValidationErrorFromJson(json);

  static const toJsonFactory = _$HTTPValidationErrorToJson;
  Map<String, dynamic> toJson() => _$HTTPValidationErrorToJson(this);

  @JsonKey(name: 'detail', defaultValue: <ValidationError>[])
  final List<ValidationError>? detail;
  static const fromJsonFactory = _$HTTPValidationErrorFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is HTTPValidationError &&
            (identical(other.detail, detail) ||
                const DeepCollectionEquality().equals(other.detail, detail)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(detail) ^ runtimeType.hashCode;
}

extension $HTTPValidationErrorExtension on HTTPValidationError {
  HTTPValidationError copyWith({List<ValidationError>? detail}) {
    return HTTPValidationError(detail: detail ?? this.detail);
  }

  HTTPValidationError copyWithWrapped({
    Wrapped<List<ValidationError>?>? detail,
  }) {
    return HTTPValidationError(
      detail: (detail != null ? detail.value : this.detail),
    );
  }
}

@JsonSerializable(explicitToJson: true)
class LinkChunkBody {
  const LinkChunkBody({required this.targetChunkId});

  factory LinkChunkBody.fromJson(Map<String, dynamic> json) =>
      _$LinkChunkBodyFromJson(json);

  static const toJsonFactory = _$LinkChunkBodyToJson;
  Map<String, dynamic> toJson() => _$LinkChunkBodyToJson(this);

  @JsonKey(name: 'target_chunk_id')
  final String targetChunkId;
  static const fromJsonFactory = _$LinkChunkBodyFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is LinkChunkBody &&
            (identical(other.targetChunkId, targetChunkId) ||
                const DeepCollectionEquality().equals(
                  other.targetChunkId,
                  targetChunkId,
                )));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(targetChunkId) ^ runtimeType.hashCode;
}

extension $LinkChunkBodyExtension on LinkChunkBody {
  LinkChunkBody copyWith({String? targetChunkId}) {
    return LinkChunkBody(targetChunkId: targetChunkId ?? this.targetChunkId);
  }

  LinkChunkBody copyWithWrapped({Wrapped<String>? targetChunkId}) {
    return LinkChunkBody(
      targetChunkId: (targetChunkId != null
          ? targetChunkId.value
          : this.targetChunkId),
    );
  }
}

@JsonSerializable(explicitToJson: true)
class PlaygroundContextSection {
  const PlaygroundContextSection({this.chunkId, required this.content});

  factory PlaygroundContextSection.fromJson(Map<String, dynamic> json) =>
      _$PlaygroundContextSectionFromJson(json);

  static const toJsonFactory = _$PlaygroundContextSectionToJson;
  Map<String, dynamic> toJson() => _$PlaygroundContextSectionToJson(this);

  @JsonKey(name: 'chunk_id')
  final String? chunkId;
  @JsonKey(name: 'content')
  final String content;
  static const fromJsonFactory = _$PlaygroundContextSectionFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is PlaygroundContextSection &&
            (identical(other.chunkId, chunkId) ||
                const DeepCollectionEquality().equals(
                  other.chunkId,
                  chunkId,
                )) &&
            (identical(other.content, content) ||
                const DeepCollectionEquality().equals(other.content, content)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(chunkId) ^
      const DeepCollectionEquality().hash(content) ^
      runtimeType.hashCode;
}

extension $PlaygroundContextSectionExtension on PlaygroundContextSection {
  PlaygroundContextSection copyWith({String? chunkId, String? content}) {
    return PlaygroundContextSection(
      chunkId: chunkId ?? this.chunkId,
      content: content ?? this.content,
    );
  }

  PlaygroundContextSection copyWithWrapped({
    Wrapped<String?>? chunkId,
    Wrapped<String>? content,
  }) {
    return PlaygroundContextSection(
      chunkId: (chunkId != null ? chunkId.value : this.chunkId),
      content: (content != null ? content.value : this.content),
    );
  }
}

@JsonSerializable(explicitToJson: true)
class PlaygroundRunBody {
  const PlaygroundRunBody({
    required this.systemInstructions,
    this.contextSections,
    required this.userQuery,
  });

  factory PlaygroundRunBody.fromJson(Map<String, dynamic> json) =>
      _$PlaygroundRunBodyFromJson(json);

  static const toJsonFactory = _$PlaygroundRunBodyToJson;
  Map<String, dynamic> toJson() => _$PlaygroundRunBodyToJson(this);

  @JsonKey(name: 'system_instructions')
  final String systemInstructions;
  @JsonKey(name: 'context_sections', defaultValue: <PlaygroundContextSection>[])
  final List<PlaygroundContextSection>? contextSections;
  @JsonKey(name: 'user_query')
  final String userQuery;
  static const fromJsonFactory = _$PlaygroundRunBodyFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is PlaygroundRunBody &&
            (identical(other.systemInstructions, systemInstructions) ||
                const DeepCollectionEquality().equals(
                  other.systemInstructions,
                  systemInstructions,
                )) &&
            (identical(other.contextSections, contextSections) ||
                const DeepCollectionEquality().equals(
                  other.contextSections,
                  contextSections,
                )) &&
            (identical(other.userQuery, userQuery) ||
                const DeepCollectionEquality().equals(
                  other.userQuery,
                  userQuery,
                )));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(systemInstructions) ^
      const DeepCollectionEquality().hash(contextSections) ^
      const DeepCollectionEquality().hash(userQuery) ^
      runtimeType.hashCode;
}

extension $PlaygroundRunBodyExtension on PlaygroundRunBody {
  PlaygroundRunBody copyWith({
    String? systemInstructions,
    List<PlaygroundContextSection>? contextSections,
    String? userQuery,
  }) {
    return PlaygroundRunBody(
      systemInstructions: systemInstructions ?? this.systemInstructions,
      contextSections: contextSections ?? this.contextSections,
      userQuery: userQuery ?? this.userQuery,
    );
  }

  PlaygroundRunBody copyWithWrapped({
    Wrapped<String>? systemInstructions,
    Wrapped<List<PlaygroundContextSection>?>? contextSections,
    Wrapped<String>? userQuery,
  }) {
    return PlaygroundRunBody(
      systemInstructions: (systemInstructions != null
          ? systemInstructions.value
          : this.systemInstructions),
      contextSections: (contextSections != null
          ? contextSections.value
          : this.contextSections),
      userQuery: (userQuery != null ? userQuery.value : this.userQuery),
    );
  }
}

@JsonSerializable(explicitToJson: true)
class RenameDocumentBody {
  const RenameDocumentBody({required this.title});

  factory RenameDocumentBody.fromJson(Map<String, dynamic> json) =>
      _$RenameDocumentBodyFromJson(json);

  static const toJsonFactory = _$RenameDocumentBodyToJson;
  Map<String, dynamic> toJson() => _$RenameDocumentBodyToJson(this);

  @JsonKey(name: 'title')
  final String title;
  static const fromJsonFactory = _$RenameDocumentBodyFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is RenameDocumentBody &&
            (identical(other.title, title) ||
                const DeepCollectionEquality().equals(other.title, title)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(title) ^ runtimeType.hashCode;
}

extension $RenameDocumentBodyExtension on RenameDocumentBody {
  RenameDocumentBody copyWith({String? title}) {
    return RenameDocumentBody(title: title ?? this.title);
  }

  RenameDocumentBody copyWithWrapped({Wrapped<String>? title}) {
    return RenameDocumentBody(
      title: (title != null ? title.value : this.title),
    );
  }
}

@JsonSerializable(explicitToJson: true)
class SealBody {
  const SealBody({required this.chunks});

  factory SealBody.fromJson(Map<String, dynamic> json) =>
      _$SealBodyFromJson(json);

  static const toJsonFactory = _$SealBodyToJson;
  Map<String, dynamic> toJson() => _$SealBodyToJson(this);

  @JsonKey(name: 'chunks', defaultValue: <SealChunkBody>[])
  final List<SealChunkBody> chunks;
  static const fromJsonFactory = _$SealBodyFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is SealBody &&
            (identical(other.chunks, chunks) ||
                const DeepCollectionEquality().equals(other.chunks, chunks)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(chunks) ^ runtimeType.hashCode;
}

extension $SealBodyExtension on SealBody {
  SealBody copyWith({List<SealChunkBody>? chunks}) {
    return SealBody(chunks: chunks ?? this.chunks);
  }

  SealBody copyWithWrapped({Wrapped<List<SealChunkBody>>? chunks}) {
    return SealBody(chunks: (chunks != null ? chunks.value : this.chunks));
  }
}

@JsonSerializable(explicitToJson: true)
class SealChunkBody {
  const SealChunkBody({
    required this.ordinal,
    required this.contentCiphertext,
    required this.salt,
    required this.nonce,
  });

  factory SealChunkBody.fromJson(Map<String, dynamic> json) =>
      _$SealChunkBodyFromJson(json);

  static const toJsonFactory = _$SealChunkBodyToJson;
  Map<String, dynamic> toJson() => _$SealChunkBodyToJson(this);

  @JsonKey(name: 'ordinal')
  final int ordinal;
  @JsonKey(name: 'content_ciphertext')
  final String contentCiphertext;
  @JsonKey(name: 'salt')
  final String salt;
  @JsonKey(name: 'nonce')
  final String nonce;
  static const fromJsonFactory = _$SealChunkBodyFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is SealChunkBody &&
            (identical(other.ordinal, ordinal) ||
                const DeepCollectionEquality().equals(
                  other.ordinal,
                  ordinal,
                )) &&
            (identical(other.contentCiphertext, contentCiphertext) ||
                const DeepCollectionEquality().equals(
                  other.contentCiphertext,
                  contentCiphertext,
                )) &&
            (identical(other.salt, salt) ||
                const DeepCollectionEquality().equals(other.salt, salt)) &&
            (identical(other.nonce, nonce) ||
                const DeepCollectionEquality().equals(other.nonce, nonce)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(ordinal) ^
      const DeepCollectionEquality().hash(contentCiphertext) ^
      const DeepCollectionEquality().hash(salt) ^
      const DeepCollectionEquality().hash(nonce) ^
      runtimeType.hashCode;
}

extension $SealChunkBodyExtension on SealChunkBody {
  SealChunkBody copyWith({
    int? ordinal,
    String? contentCiphertext,
    String? salt,
    String? nonce,
  }) {
    return SealChunkBody(
      ordinal: ordinal ?? this.ordinal,
      contentCiphertext: contentCiphertext ?? this.contentCiphertext,
      salt: salt ?? this.salt,
      nonce: nonce ?? this.nonce,
    );
  }

  SealChunkBody copyWithWrapped({
    Wrapped<int>? ordinal,
    Wrapped<String>? contentCiphertext,
    Wrapped<String>? salt,
    Wrapped<String>? nonce,
  }) {
    return SealChunkBody(
      ordinal: (ordinal != null ? ordinal.value : this.ordinal),
      contentCiphertext: (contentCiphertext != null
          ? contentCiphertext.value
          : this.contentCiphertext),
      salt: (salt != null ? salt.value : this.salt),
      nonce: (nonce != null ? nonce.value : this.nonce),
    );
  }
}

@JsonSerializable(explicitToJson: true)
class StreamBody {
  const StreamBody({required this.query, this.unlocked});

  factory StreamBody.fromJson(Map<String, dynamic> json) =>
      _$StreamBodyFromJson(json);

  static const toJsonFactory = _$StreamBodyToJson;
  Map<String, dynamic> toJson() => _$StreamBodyToJson(this);

  @JsonKey(name: 'query')
  final String query;
  @JsonKey(name: 'unlocked', defaultValue: <UnlockedDocumentBody>[])
  final List<UnlockedDocumentBody>? unlocked;
  static const fromJsonFactory = _$StreamBodyFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is StreamBody &&
            (identical(other.query, query) ||
                const DeepCollectionEquality().equals(other.query, query)) &&
            (identical(other.unlocked, unlocked) ||
                const DeepCollectionEquality().equals(
                  other.unlocked,
                  unlocked,
                )));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(query) ^
      const DeepCollectionEquality().hash(unlocked) ^
      runtimeType.hashCode;
}

extension $StreamBodyExtension on StreamBody {
  StreamBody copyWith({String? query, List<UnlockedDocumentBody>? unlocked}) {
    return StreamBody(
      query: query ?? this.query,
      unlocked: unlocked ?? this.unlocked,
    );
  }

  StreamBody copyWithWrapped({
    Wrapped<String>? query,
    Wrapped<List<UnlockedDocumentBody>?>? unlocked,
  }) {
    return StreamBody(
      query: (query != null ? query.value : this.query),
      unlocked: (unlocked != null ? unlocked.value : this.unlocked),
    );
  }
}

@JsonSerializable(explicitToJson: true)
class UnlockBody {
  const UnlockBody({required this.key});

  factory UnlockBody.fromJson(Map<String, dynamic> json) =>
      _$UnlockBodyFromJson(json);

  static const toJsonFactory = _$UnlockBodyToJson;
  Map<String, dynamic> toJson() => _$UnlockBodyToJson(this);

  @JsonKey(name: 'key')
  final String key;
  static const fromJsonFactory = _$UnlockBodyFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is UnlockBody &&
            (identical(other.key, key) ||
                const DeepCollectionEquality().equals(other.key, key)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(key) ^ runtimeType.hashCode;
}

extension $UnlockBodyExtension on UnlockBody {
  UnlockBody copyWith({String? key}) {
    return UnlockBody(key: key ?? this.key);
  }

  UnlockBody copyWithWrapped({Wrapped<String>? key}) {
    return UnlockBody(key: (key != null ? key.value : this.key));
  }
}

@JsonSerializable(explicitToJson: true)
class UnlockedDocumentBody {
  const UnlockedDocumentBody({
    required this.documentId,
    required this.claimId,
    required this.key,
  });

  factory UnlockedDocumentBody.fromJson(Map<String, dynamic> json) =>
      _$UnlockedDocumentBodyFromJson(json);

  static const toJsonFactory = _$UnlockedDocumentBodyToJson;
  Map<String, dynamic> toJson() => _$UnlockedDocumentBodyToJson(this);

  @JsonKey(name: 'document_id')
  final String documentId;
  @JsonKey(name: 'claim_id')
  final String claimId;
  @JsonKey(name: 'key')
  final String key;
  static const fromJsonFactory = _$UnlockedDocumentBodyFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is UnlockedDocumentBody &&
            (identical(other.documentId, documentId) ||
                const DeepCollectionEquality().equals(
                  other.documentId,
                  documentId,
                )) &&
            (identical(other.claimId, claimId) ||
                const DeepCollectionEquality().equals(
                  other.claimId,
                  claimId,
                )) &&
            (identical(other.key, key) ||
                const DeepCollectionEquality().equals(other.key, key)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(documentId) ^
      const DeepCollectionEquality().hash(claimId) ^
      const DeepCollectionEquality().hash(key) ^
      runtimeType.hashCode;
}

extension $UnlockedDocumentBodyExtension on UnlockedDocumentBody {
  UnlockedDocumentBody copyWith({
    String? documentId,
    String? claimId,
    String? key,
  }) {
    return UnlockedDocumentBody(
      documentId: documentId ?? this.documentId,
      claimId: claimId ?? this.claimId,
      key: key ?? this.key,
    );
  }

  UnlockedDocumentBody copyWithWrapped({
    Wrapped<String>? documentId,
    Wrapped<String>? claimId,
    Wrapped<String>? key,
  }) {
    return UnlockedDocumentBody(
      documentId: (documentId != null ? documentId.value : this.documentId),
      claimId: (claimId != null ? claimId.value : this.claimId),
      key: (key != null ? key.value : this.key),
    );
  }
}

@JsonSerializable(explicitToJson: true)
class UnsealBody {
  const UnsealBody({required this.claimId, required this.key});

  factory UnsealBody.fromJson(Map<String, dynamic> json) =>
      _$UnsealBodyFromJson(json);

  static const toJsonFactory = _$UnsealBodyToJson;
  Map<String, dynamic> toJson() => _$UnsealBodyToJson(this);

  @JsonKey(name: 'claim_id')
  final String claimId;
  @JsonKey(name: 'key')
  final String key;
  static const fromJsonFactory = _$UnsealBodyFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is UnsealBody &&
            (identical(other.claimId, claimId) ||
                const DeepCollectionEquality().equals(
                  other.claimId,
                  claimId,
                )) &&
            (identical(other.key, key) ||
                const DeepCollectionEquality().equals(other.key, key)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(claimId) ^
      const DeepCollectionEquality().hash(key) ^
      runtimeType.hashCode;
}

extension $UnsealBodyExtension on UnsealBody {
  UnsealBody copyWith({String? claimId, String? key}) {
    return UnsealBody(claimId: claimId ?? this.claimId, key: key ?? this.key);
  }

  UnsealBody copyWithWrapped({Wrapped<String>? claimId, Wrapped<String>? key}) {
    return UnsealBody(
      claimId: (claimId != null ? claimId.value : this.claimId),
      key: (key != null ? key.value : this.key),
    );
  }
}

@JsonSerializable(explicitToJson: true)
class UpdateCardBody {
  const UpdateCardBody({
    this.columnName,
    this.position,
    this.title,
    this.description,
    this.documentId,
  });

  factory UpdateCardBody.fromJson(Map<String, dynamic> json) =>
      _$UpdateCardBodyFromJson(json);

  static const toJsonFactory = _$UpdateCardBodyToJson;
  Map<String, dynamic> toJson() => _$UpdateCardBodyToJson(this);

  @JsonKey(name: 'column_name')
  final String? columnName;
  @JsonKey(name: 'position')
  final double? position;
  @JsonKey(name: 'title')
  final String? title;
  @JsonKey(name: 'description')
  final String? description;
  @JsonKey(name: 'document_id')
  final String? documentId;
  static const fromJsonFactory = _$UpdateCardBodyFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is UpdateCardBody &&
            (identical(other.columnName, columnName) ||
                const DeepCollectionEquality().equals(
                  other.columnName,
                  columnName,
                )) &&
            (identical(other.position, position) ||
                const DeepCollectionEquality().equals(
                  other.position,
                  position,
                )) &&
            (identical(other.title, title) ||
                const DeepCollectionEquality().equals(other.title, title)) &&
            (identical(other.description, description) ||
                const DeepCollectionEquality().equals(
                  other.description,
                  description,
                )) &&
            (identical(other.documentId, documentId) ||
                const DeepCollectionEquality().equals(
                  other.documentId,
                  documentId,
                )));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(columnName) ^
      const DeepCollectionEquality().hash(position) ^
      const DeepCollectionEquality().hash(title) ^
      const DeepCollectionEquality().hash(description) ^
      const DeepCollectionEquality().hash(documentId) ^
      runtimeType.hashCode;
}

extension $UpdateCardBodyExtension on UpdateCardBody {
  UpdateCardBody copyWith({
    String? columnName,
    double? position,
    String? title,
    String? description,
    String? documentId,
  }) {
    return UpdateCardBody(
      columnName: columnName ?? this.columnName,
      position: position ?? this.position,
      title: title ?? this.title,
      description: description ?? this.description,
      documentId: documentId ?? this.documentId,
    );
  }

  UpdateCardBody copyWithWrapped({
    Wrapped<String?>? columnName,
    Wrapped<double?>? position,
    Wrapped<String?>? title,
    Wrapped<String?>? description,
    Wrapped<String?>? documentId,
  }) {
    return UpdateCardBody(
      columnName: (columnName != null ? columnName.value : this.columnName),
      position: (position != null ? position.value : this.position),
      title: (title != null ? title.value : this.title),
      description: (description != null ? description.value : this.description),
      documentId: (documentId != null ? documentId.value : this.documentId),
    );
  }
}

@JsonSerializable(explicitToJson: true)
class UpdateTodoBody {
  const UpdateTodoBody({this.completed, this.title, this.priority});

  factory UpdateTodoBody.fromJson(Map<String, dynamic> json) =>
      _$UpdateTodoBodyFromJson(json);

  static const toJsonFactory = _$UpdateTodoBodyToJson;
  Map<String, dynamic> toJson() => _$UpdateTodoBodyToJson(this);

  @JsonKey(name: 'completed')
  final bool? completed;
  @JsonKey(name: 'title')
  final String? title;
  @JsonKey(
    name: 'priority',
    toJson: updateTodoBodyPriorityNullableToJson,
    fromJson: updateTodoBodyPriorityNullableFromJson,
  )
  final enums.UpdateTodoBodyPriority? priority;
  static const fromJsonFactory = _$UpdateTodoBodyFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is UpdateTodoBody &&
            (identical(other.completed, completed) ||
                const DeepCollectionEquality().equals(
                  other.completed,
                  completed,
                )) &&
            (identical(other.title, title) ||
                const DeepCollectionEquality().equals(other.title, title)) &&
            (identical(other.priority, priority) ||
                const DeepCollectionEquality().equals(
                  other.priority,
                  priority,
                )));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(completed) ^
      const DeepCollectionEquality().hash(title) ^
      const DeepCollectionEquality().hash(priority) ^
      runtimeType.hashCode;
}

extension $UpdateTodoBodyExtension on UpdateTodoBody {
  UpdateTodoBody copyWith({
    bool? completed,
    String? title,
    enums.UpdateTodoBodyPriority? priority,
  }) {
    return UpdateTodoBody(
      completed: completed ?? this.completed,
      title: title ?? this.title,
      priority: priority ?? this.priority,
    );
  }

  UpdateTodoBody copyWithWrapped({
    Wrapped<bool?>? completed,
    Wrapped<String?>? title,
    Wrapped<enums.UpdateTodoBodyPriority?>? priority,
  }) {
    return UpdateTodoBody(
      completed: (completed != null ? completed.value : this.completed),
      title: (title != null ? title.value : this.title),
      priority: (priority != null ? priority.value : this.priority),
    );
  }
}

@JsonSerializable(explicitToJson: true)
class UploadInitBody {
  const UploadInitBody({
    required this.filename,
    required this.mime,
    required this.sizeBytes,
  });

  factory UploadInitBody.fromJson(Map<String, dynamic> json) =>
      _$UploadInitBodyFromJson(json);

  static const toJsonFactory = _$UploadInitBodyToJson;
  Map<String, dynamic> toJson() => _$UploadInitBodyToJson(this);

  @JsonKey(name: 'filename')
  final String filename;
  @JsonKey(name: 'mime')
  final String mime;
  @JsonKey(name: 'size_bytes')
  final int sizeBytes;
  static const fromJsonFactory = _$UploadInitBodyFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is UploadInitBody &&
            (identical(other.filename, filename) ||
                const DeepCollectionEquality().equals(
                  other.filename,
                  filename,
                )) &&
            (identical(other.mime, mime) ||
                const DeepCollectionEquality().equals(other.mime, mime)) &&
            (identical(other.sizeBytes, sizeBytes) ||
                const DeepCollectionEquality().equals(
                  other.sizeBytes,
                  sizeBytes,
                )));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(filename) ^
      const DeepCollectionEquality().hash(mime) ^
      const DeepCollectionEquality().hash(sizeBytes) ^
      runtimeType.hashCode;
}

extension $UploadInitBodyExtension on UploadInitBody {
  UploadInitBody copyWith({String? filename, String? mime, int? sizeBytes}) {
    return UploadInitBody(
      filename: filename ?? this.filename,
      mime: mime ?? this.mime,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }

  UploadInitBody copyWithWrapped({
    Wrapped<String>? filename,
    Wrapped<String>? mime,
    Wrapped<int>? sizeBytes,
  }) {
    return UploadInitBody(
      filename: (filename != null ? filename.value : this.filename),
      mime: (mime != null ? mime.value : this.mime),
      sizeBytes: (sizeBytes != null ? sizeBytes.value : this.sizeBytes),
    );
  }
}

@JsonSerializable(explicitToJson: true)
class ValidationError {
  const ValidationError({
    required this.loc,
    required this.msg,
    required this.type,
  });

  factory ValidationError.fromJson(Map<String, dynamic> json) =>
      _$ValidationErrorFromJson(json);

  static const toJsonFactory = _$ValidationErrorToJson;
  Map<String, dynamic> toJson() => _$ValidationErrorToJson(this);

  @JsonKey(name: 'loc', defaultValue: <Object>[])
  final List<Object> loc;
  @JsonKey(name: 'msg')
  final String msg;
  @JsonKey(name: 'type')
  final String type;
  static const fromJsonFactory = _$ValidationErrorFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ValidationError &&
            (identical(other.loc, loc) ||
                const DeepCollectionEquality().equals(other.loc, loc)) &&
            (identical(other.msg, msg) ||
                const DeepCollectionEquality().equals(other.msg, msg)) &&
            (identical(other.type, type) ||
                const DeepCollectionEquality().equals(other.type, type)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(loc) ^
      const DeepCollectionEquality().hash(msg) ^
      const DeepCollectionEquality().hash(type) ^
      runtimeType.hashCode;
}

extension $ValidationErrorExtension on ValidationError {
  ValidationError copyWith({List<Object>? loc, String? msg, String? type}) {
    return ValidationError(
      loc: loc ?? this.loc,
      msg: msg ?? this.msg,
      type: type ?? this.type,
    );
  }

  ValidationError copyWithWrapped({
    Wrapped<List<Object>>? loc,
    Wrapped<String>? msg,
    Wrapped<String>? type,
  }) {
    return ValidationError(
      loc: (loc != null ? loc.value : this.loc),
      msg: (msg != null ? msg.value : this.msg),
      type: (type != null ? type.value : this.type),
    );
  }
}

String? createTodoBodyPriorityNullableToJson(
  enums.CreateTodoBodyPriority? createTodoBodyPriority,
) {
  return createTodoBodyPriority?.value;
}

String? createTodoBodyPriorityToJson(
  enums.CreateTodoBodyPriority createTodoBodyPriority,
) {
  return createTodoBodyPriority.value;
}

enums.CreateTodoBodyPriority createTodoBodyPriorityFromJson(
  Object? createTodoBodyPriority, [
  enums.CreateTodoBodyPriority? defaultValue,
]) {
  return enums.CreateTodoBodyPriority.values.firstWhereOrNull(
        (e) => e.value == createTodoBodyPriority,
      ) ??
      defaultValue ??
      enums.CreateTodoBodyPriority.swaggerGeneratedUnknown;
}

enums.CreateTodoBodyPriority? createTodoBodyPriorityNullableFromJson(
  Object? createTodoBodyPriority, [
  enums.CreateTodoBodyPriority? defaultValue,
]) {
  if (createTodoBodyPriority == null) {
    return null;
  }
  return enums.CreateTodoBodyPriority.values.firstWhereOrNull(
        (e) => e.value == createTodoBodyPriority,
      ) ??
      defaultValue;
}

String createTodoBodyPriorityExplodedListToJson(
  List<enums.CreateTodoBodyPriority>? createTodoBodyPriority,
) {
  return createTodoBodyPriority?.map((e) => e.value!).join(',') ?? '';
}

List<String> createTodoBodyPriorityListToJson(
  List<enums.CreateTodoBodyPriority>? createTodoBodyPriority,
) {
  if (createTodoBodyPriority == null) {
    return [];
  }

  return createTodoBodyPriority.map((e) => e.value!).toList();
}

List<enums.CreateTodoBodyPriority> createTodoBodyPriorityListFromJson(
  List? createTodoBodyPriority, [
  List<enums.CreateTodoBodyPriority>? defaultValue,
]) {
  if (createTodoBodyPriority == null) {
    return defaultValue ?? [];
  }

  return createTodoBodyPriority
      .map((e) => createTodoBodyPriorityFromJson(e.toString()))
      .toList();
}

List<enums.CreateTodoBodyPriority>? createTodoBodyPriorityNullableListFromJson(
  List? createTodoBodyPriority, [
  List<enums.CreateTodoBodyPriority>? defaultValue,
]) {
  if (createTodoBodyPriority == null) {
    return defaultValue;
  }

  return createTodoBodyPriority
      .map((e) => createTodoBodyPriorityFromJson(e.toString()))
      .toList();
}

String? updateTodoBodyPriorityNullableToJson(
  enums.UpdateTodoBodyPriority? updateTodoBodyPriority,
) {
  return updateTodoBodyPriority?.value;
}

String? updateTodoBodyPriorityToJson(
  enums.UpdateTodoBodyPriority updateTodoBodyPriority,
) {
  return updateTodoBodyPriority.value;
}

enums.UpdateTodoBodyPriority updateTodoBodyPriorityFromJson(
  Object? updateTodoBodyPriority, [
  enums.UpdateTodoBodyPriority? defaultValue,
]) {
  return enums.UpdateTodoBodyPriority.values.firstWhereOrNull(
        (e) => e.value == updateTodoBodyPriority,
      ) ??
      defaultValue ??
      enums.UpdateTodoBodyPriority.swaggerGeneratedUnknown;
}

enums.UpdateTodoBodyPriority? updateTodoBodyPriorityNullableFromJson(
  Object? updateTodoBodyPriority, [
  enums.UpdateTodoBodyPriority? defaultValue,
]) {
  if (updateTodoBodyPriority == null) {
    return null;
  }
  return enums.UpdateTodoBodyPriority.values.firstWhereOrNull(
        (e) => e.value == updateTodoBodyPriority,
      ) ??
      defaultValue;
}

String updateTodoBodyPriorityExplodedListToJson(
  List<enums.UpdateTodoBodyPriority>? updateTodoBodyPriority,
) {
  return updateTodoBodyPriority?.map((e) => e.value!).join(',') ?? '';
}

List<String> updateTodoBodyPriorityListToJson(
  List<enums.UpdateTodoBodyPriority>? updateTodoBodyPriority,
) {
  if (updateTodoBodyPriority == null) {
    return [];
  }

  return updateTodoBodyPriority.map((e) => e.value!).toList();
}

List<enums.UpdateTodoBodyPriority> updateTodoBodyPriorityListFromJson(
  List? updateTodoBodyPriority, [
  List<enums.UpdateTodoBodyPriority>? defaultValue,
]) {
  if (updateTodoBodyPriority == null) {
    return defaultValue ?? [];
  }

  return updateTodoBodyPriority
      .map((e) => updateTodoBodyPriorityFromJson(e.toString()))
      .toList();
}

List<enums.UpdateTodoBodyPriority>? updateTodoBodyPriorityNullableListFromJson(
  List? updateTodoBodyPriority, [
  List<enums.UpdateTodoBodyPriority>? defaultValue,
]) {
  if (updateTodoBodyPriority == null) {
    return defaultValue;
  }

  return updateTodoBodyPriority
      .map((e) => updateTodoBodyPriorityFromJson(e.toString()))
      .toList();
}

typedef $JsonFactory<T> = T Function(Map<String, dynamic> json);

class $CustomJsonDecoder {
  $CustomJsonDecoder(this.factories);

  final Map<Type, $JsonFactory> factories;

  dynamic decode<T>(dynamic entity) {
    if (entity is Iterable) {
      return _decodeList<T>(entity);
    }

    if (entity is T) {
      return entity;
    }

    if (isTypeOf<T, Map>()) {
      return entity;
    }

    if (isTypeOf<T, Iterable>()) {
      return entity;
    }

    if (entity is Map<String, dynamic>) {
      return _decodeMap<T>(entity);
    }

    return entity;
  }

  T _decodeMap<T>(Map<String, dynamic> values) {
    final jsonFactory = factories[T];
    if (jsonFactory == null || jsonFactory is! $JsonFactory<T>) {
      return throw "Could not find factory for type $T. Is '$T: $T.fromJsonFactory' included in the CustomJsonDecoder instance creation in bootstrapper.dart?";
    }

    return jsonFactory(values);
  }

  List<T> _decodeList<T>(Iterable values) =>
      values.where((v) => v != null).map<T>((v) => decode<T>(v) as T).toList();
}

class $JsonSerializableConverter extends chopper.JsonConverter {
  @override
  FutureOr<chopper.Response<ResultType>> convertResponse<ResultType, Item>(
    chopper.Response response,
  ) async {
    if (response.bodyString.isEmpty) {
      // In rare cases, when let's say 204 (no content) is returned -
      // we cannot decode the missing json with the result type specified
      return chopper.Response(response.base, null, error: response.error);
    }

    if (ResultType == String) {
      return response.copyWith();
    }

    if (ResultType == DateTime) {
      return response.copyWith(
        body:
            DateTime.parse((response.body as String).replaceAll('"', ''))
                as ResultType,
      );
    }

    final jsonRes = await super.convertResponse(response);
    return jsonRes.copyWith<ResultType>(
      body: $jsonDecoder.decode<Item>(jsonRes.body) as ResultType,
    );
  }
}

final $jsonDecoder = $CustomJsonDecoder(generatedMapping);

// ignore: unused_element
String? _dateToJson(DateTime? date) {
  if (date == null) {
    return null;
  }

  final year = date.year.toString();
  final month = date.month < 10 ? '0${date.month}' : date.month.toString();
  final day = date.day < 10 ? '0${date.day}' : date.day.toString();

  return '$year-$month-$day';
}

class Wrapped<T> {
  final T value;
  const Wrapped.value(this.value);
}
