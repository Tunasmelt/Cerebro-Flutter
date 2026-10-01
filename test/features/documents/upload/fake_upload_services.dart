import 'dart:async';

import 'package:cerebro_mobile/features/documents/data/upload/picked_upload.dart';
import 'package:cerebro_mobile/features/documents/data/upload/storage_uploader.dart';
import 'package:cerebro_mobile/features/documents/data/upload/upload_api.dart';
import 'package:cerebro_mobile/features/documents/data/upload/upload_picker.dart';

/// Shared by [FakeUploadApi] and [FakeStorageUploader] so a test can
/// assert the GLOBAL order of the three calls (`init`, `put`, `confirm`),
/// not just each fake's own calls.
class CallLog {
  final List<String> entries = [];
  void add(String entry) => entries.add(entry);
}

class FakeUploadApi implements UploadApi {
  FakeUploadApi(this.log);

  final CallLog log;

  Object? initError;
  Object? confirmError;

  /// Set to hold `confirm` open until the test completes it.
  Completer<void>? confirmGate;

  String documentId = 'doc-1';

  @override
  Future<UploadInit> init({
    required String filename,
    required String mime,
    required int sizeBytes,
  }) async {
    log.add('init');
    final error = initError;
    if (error != null) throw error;
    return UploadInit(
      documentId: documentId,
      uploadUrl: Uri.parse('https://storage.example/upload?token=t'),
    );
  }

  @override
  Future<UploadConfirmation> confirm(String documentId) async {
    log.add('confirm');
    await confirmGate?.future;
    final error = confirmError;
    if (error != null) throw error;
    return UploadConfirmation(
      documentId: documentId,
      state: 'normalizing',
      sizeBytes: 1,
    );
  }
}

class FakeStorageUploader implements StorageUploader {
  FakeStorageUploader(this.log);

  final CallLog log;

  Object? putError;

  /// Set to hold the PUT open (to observe the in-flight state).
  Completer<void>? putGate;

  /// Progress events to emit before completing.
  List<(int, int)> progressEvents = const [];

  @override
  Future<void> put({
    required Uri uploadUrl,
    required PickedUpload file,
    required String mime,
    void Function(int sent, int total)? onProgress,
  }) async {
    log.add('put');
    for (final (sent, total) in progressEvents) {
      onProgress?.call(sent, total);
    }
    await putGate?.future;
    final error = putError;
    if (error != null) throw error;
  }
}

class FakeUploadPicker implements UploadPicker {
  PickedUpload? result;
  Object? error;
  final List<UploadSource> requested = [];

  @override
  Future<PickedUpload?> pick(UploadSource source) async {
    requested.add(source);
    final e = error;
    if (e != null) throw e;
    return result;
  }
}

PickedUpload fakePickedUpload({
  String name = 'notes.txt',
  String? mime = 'text/plain',
  int sizeBytes = 11,
}) {
  return PickedUpload(
    name: name,
    mime: mime,
    sizeBytes: sizeBytes,
    openRead: () => Stream<List<int>>.value(List.filled(sizeBytes, 0)),
  );
}
