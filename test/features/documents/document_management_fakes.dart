import 'dart:async';

import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/documents/data/delete_document_api.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/document_actions_api.dart';

DocumentSummary managedDoc(
  String id,
  String title, {
  DocumentStatus status = DocumentStatus.ready,
}) => DocumentSummary(
  id: id,
  title: title,
  mime: 'text/plain',
  sizeBytes: 100,
  originalSizeBytes: 100,
  status: status,
  createdAt: DateTime.utc(2026, 1, 1),
);

/// Stands in for the server: rename mutates the same list the fake documents
/// repository serves, so a refetch sees the new name.
class FakeDocumentActionsApi implements DocumentActionsApi {
  FakeDocumentActionsApi(this.server);

  final List<DocumentSummary> server;
  final renames = <(String, String)>[];
  final notes = <({String text, String? title})>[];
  Object? renameError;
  Object? noteError;
  Completer<void>? noteGate;

  @override
  Future<void> rename(String documentId, String title) async {
    renames.add((documentId, title));
    if (renameError case final Object e) throw e;
    final i = server.indexWhere((d) => d.id == documentId);
    if (i >= 0) server[i] = server[i].copyWith(title: title);
  }

  @override
  Future<String> createNote({required String text, String? title}) async {
    notes.add((text: text, title: title));
    await noteGate?.future;
    if (noteError case final Object e) throw e;
    final id = 'note-${notes.length}';
    server.insert(
      0,
      managedDoc(id, title ?? text, status: DocumentStatus.processing),
    );
    return id;
  }
}

class FakeDeleteApi implements DeleteDocumentApi {
  FakeDeleteApi(this.server);

  final List<DocumentSummary> server;
  final deleted = <String>[];
  Object? error;

  @override
  Future<void> delete(String documentId) async {
    if (error case final Object e) throw e;
    deleted.add(documentId);
    server.removeWhere((d) => d.id == documentId);
  }
}

const rejected = RequestRejectedException(
  'That name is too long.',
  code: 'title_too_long',
);
