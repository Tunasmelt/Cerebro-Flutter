// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cerebro_api.swagger.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentTurnBody _$AgentTurnBodyFromJson(Map<String, dynamic> json) =>
    AgentTurnBody(message: json['message'] as String);

Map<String, dynamic> _$AgentTurnBodyToJson(AgentTurnBody instance) =>
    <String, dynamic>{'message': instance.message};

CaptureBody _$CaptureBodyFromJson(Map<String, dynamic> json) =>
    CaptureBody(text: json['text'] as String, title: json['title'] as String?);

Map<String, dynamic> _$CaptureBodyToJson(CaptureBody instance) =>
    <String, dynamic>{'text': instance.text, 'title': instance.title};

CreateBoardBody _$CreateBoardBodyFromJson(Map<String, dynamic> json) =>
    CreateBoardBody(title: json['title'] as String);

Map<String, dynamic> _$CreateBoardBodyToJson(CreateBoardBody instance) =>
    <String, dynamic>{'title': instance.title};

CreateCardBody _$CreateCardBodyFromJson(Map<String, dynamic> json) =>
    CreateCardBody(
      columnName: json['column_name'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      documentId: json['document_id'] as String?,
    );

Map<String, dynamic> _$CreateCardBodyToJson(CreateCardBody instance) =>
    <String, dynamic>{
      'column_name': instance.columnName,
      'title': instance.title,
      'description': instance.description,
      'document_id': instance.documentId,
    };

CreateTodoBody _$CreateTodoBodyFromJson(Map<String, dynamic> json) =>
    CreateTodoBody(
      title: json['title'] as String,
      documentId: json['document_id'] as String?,
      priority: CreateTodoBody.createTodoBodyPriorityPriorityNullableFromJson(
        json['priority'],
      ),
    );

Map<String, dynamic> _$CreateTodoBodyToJson(CreateTodoBody instance) =>
    <String, dynamic>{
      'title': instance.title,
      'document_id': instance.documentId,
      'priority': createTodoBodyPriorityNullableToJson(instance.priority),
    };

HTTPValidationError _$HTTPValidationErrorFromJson(Map<String, dynamic> json) =>
    HTTPValidationError(
      detail:
          (json['detail'] as List<dynamic>?)
              ?.map((e) => ValidationError.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$HTTPValidationErrorToJson(
  HTTPValidationError instance,
) => <String, dynamic>{
  'detail': instance.detail?.map((e) => e.toJson()).toList(),
};

LinkChunkBody _$LinkChunkBodyFromJson(Map<String, dynamic> json) =>
    LinkChunkBody(targetChunkId: json['target_chunk_id'] as String);

Map<String, dynamic> _$LinkChunkBodyToJson(LinkChunkBody instance) =>
    <String, dynamic>{'target_chunk_id': instance.targetChunkId};

PlaygroundContextSection _$PlaygroundContextSectionFromJson(
  Map<String, dynamic> json,
) => PlaygroundContextSection(
  chunkId: json['chunk_id'] as String?,
  content: json['content'] as String,
);

Map<String, dynamic> _$PlaygroundContextSectionToJson(
  PlaygroundContextSection instance,
) => <String, dynamic>{
  'chunk_id': instance.chunkId,
  'content': instance.content,
};

PlaygroundRunBody _$PlaygroundRunBodyFromJson(Map<String, dynamic> json) =>
    PlaygroundRunBody(
      systemInstructions: json['system_instructions'] as String,
      contextSections:
          (json['context_sections'] as List<dynamic>?)
              ?.map(
                (e) => PlaygroundContextSection.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
      userQuery: json['user_query'] as String,
    );

Map<String, dynamic> _$PlaygroundRunBodyToJson(
  PlaygroundRunBody instance,
) => <String, dynamic>{
  'system_instructions': instance.systemInstructions,
  'context_sections': instance.contextSections?.map((e) => e.toJson()).toList(),
  'user_query': instance.userQuery,
};

RenameDocumentBody _$RenameDocumentBodyFromJson(Map<String, dynamic> json) =>
    RenameDocumentBody(title: json['title'] as String);

Map<String, dynamic> _$RenameDocumentBodyToJson(RenameDocumentBody instance) =>
    <String, dynamic>{'title': instance.title};

SealBody _$SealBodyFromJson(Map<String, dynamic> json) => SealBody(
  chunks:
      (json['chunks'] as List<dynamic>?)
          ?.map((e) => SealChunkBody.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$SealBodyToJson(SealBody instance) => <String, dynamic>{
  'chunks': instance.chunks.map((e) => e.toJson()).toList(),
};

SealChunkBody _$SealChunkBodyFromJson(Map<String, dynamic> json) =>
    SealChunkBody(
      ordinal: (json['ordinal'] as num).toInt(),
      contentCiphertext: json['content_ciphertext'] as String,
      salt: json['salt'] as String,
      nonce: json['nonce'] as String,
    );

Map<String, dynamic> _$SealChunkBodyToJson(SealChunkBody instance) =>
    <String, dynamic>{
      'ordinal': instance.ordinal,
      'content_ciphertext': instance.contentCiphertext,
      'salt': instance.salt,
      'nonce': instance.nonce,
    };

StreamBody _$StreamBodyFromJson(Map<String, dynamic> json) => StreamBody(
  query: json['query'] as String,
  unlocked:
      (json['unlocked'] as List<dynamic>?)
          ?.map((e) => UnlockedDocumentBody.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$StreamBodyToJson(StreamBody instance) =>
    <String, dynamic>{
      'query': instance.query,
      'unlocked': instance.unlocked?.map((e) => e.toJson()).toList(),
    };

UnlockBody _$UnlockBodyFromJson(Map<String, dynamic> json) =>
    UnlockBody(key: json['key'] as String);

Map<String, dynamic> _$UnlockBodyToJson(UnlockBody instance) =>
    <String, dynamic>{'key': instance.key};

UnlockedDocumentBody _$UnlockedDocumentBodyFromJson(
  Map<String, dynamic> json,
) => UnlockedDocumentBody(
  documentId: json['document_id'] as String,
  claimId: json['claim_id'] as String,
  key: json['key'] as String,
);

Map<String, dynamic> _$UnlockedDocumentBodyToJson(
  UnlockedDocumentBody instance,
) => <String, dynamic>{
  'document_id': instance.documentId,
  'claim_id': instance.claimId,
  'key': instance.key,
};

UnsealBody _$UnsealBodyFromJson(Map<String, dynamic> json) =>
    UnsealBody(claimId: json['claim_id'] as String, key: json['key'] as String);

Map<String, dynamic> _$UnsealBodyToJson(UnsealBody instance) =>
    <String, dynamic>{'claim_id': instance.claimId, 'key': instance.key};

UpdateCardBody _$UpdateCardBodyFromJson(Map<String, dynamic> json) =>
    UpdateCardBody(
      columnName: json['column_name'] as String?,
      position: (json['position'] as num?)?.toDouble(),
      title: json['title'] as String?,
      description: json['description'] as String?,
      documentId: json['document_id'] as String?,
    );

Map<String, dynamic> _$UpdateCardBodyToJson(UpdateCardBody instance) =>
    <String, dynamic>{
      'column_name': instance.columnName,
      'position': instance.position,
      'title': instance.title,
      'description': instance.description,
      'document_id': instance.documentId,
    };

UpdateTodoBody _$UpdateTodoBodyFromJson(Map<String, dynamic> json) =>
    UpdateTodoBody(
      completed: json['completed'] as bool?,
      title: json['title'] as String?,
      priority: updateTodoBodyPriorityNullableFromJson(json['priority']),
    );

Map<String, dynamic> _$UpdateTodoBodyToJson(UpdateTodoBody instance) =>
    <String, dynamic>{
      'completed': instance.completed,
      'title': instance.title,
      'priority': updateTodoBodyPriorityNullableToJson(instance.priority),
    };

UploadInitBody _$UploadInitBodyFromJson(Map<String, dynamic> json) =>
    UploadInitBody(
      filename: json['filename'] as String,
      mime: json['mime'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
    );

Map<String, dynamic> _$UploadInitBodyToJson(UploadInitBody instance) =>
    <String, dynamic>{
      'filename': instance.filename,
      'mime': instance.mime,
      'size_bytes': instance.sizeBytes,
    };

ValidationError _$ValidationErrorFromJson(
  Map<String, dynamic> json,
) => ValidationError(
  loc: (json['loc'] as List<dynamic>?)?.map((e) => e as Object).toList() ?? [],
  msg: json['msg'] as String,
  type: json['type'] as String,
);

Map<String, dynamic> _$ValidationErrorToJson(ValidationError instance) =>
    <String, dynamic>{
      'loc': instance.loc,
      'msg': instance.msg,
      'type': instance.type,
    };
