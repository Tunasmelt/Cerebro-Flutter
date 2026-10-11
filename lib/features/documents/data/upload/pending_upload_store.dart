import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/network/app_exception.dart';
import 'picked_upload.dart';

// Configured at the app entry point; isolated controller tests need no plugin.
final pendingUploadStoreProvider = Provider<PendingUploadStore?>((ref) => null);

PendingUploadStore devicePendingUploadStore() =>
    PendingUploadStore(getApplicationCacheDirectory);

/// Private cache files survive process death but are excluded from OS backups.
/// No bearer token, signed URL, sealed key, or unlock claim is persisted.
class PendingUploadStore {
  PendingUploadStore(this.directory);
  final Future<Directory> Function() directory;

  Future<Directory> _owner(String owner) async {
    final root = await directory();
    final name = base64Url.encode(utf8.encode(owner));
    return Directory('${root.path}/pending_uploads/$name');
  }

  Future<PendingUpload> save(String owner, PickedUpload source) async {
    final root = await _owner(owner);
    await root.create(recursive: true);
    final folder = await root.createTemp('upload-');
    final pending = PendingUpload(
      folder,
      source.name,
      source.mime!,
      source.sizeBytes,
    );
    await pending.checkpoint();
    final bytes = File('${folder.path}/bytes');
    final sink = bytes.openWrite();
    try {
      var copied = 0;
      await for (final chunk in source.openRead()) {
        copied += chunk.length;
        if (copied > source.sizeBytes) {
          throw const FormatException('Upload file size changed');
        }
        sink.add(chunk);
        await sink.flush();
      }
    } catch (_) {
      await sink.close();
      await folder.delete(recursive: true);
      rethrow;
    } finally {
      await sink.close();
    }
    if (await bytes.length() != source.sizeBytes) {
      await folder.delete(recursive: true);
      throw const FormatException('Upload file size changed');
    }
    return pending;
  }

  Future<List<PendingUpload>> load(String owner) async {
    final root = await _owner(owner);
    if (!await root.exists()) return [];
    final result = <PendingUpload>[];
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory) continue;
      final metadata = File('${entry.path}/metadata.json');
      if (!await metadata.exists()) {
        result.add(PendingUpload(entry, 'Saved upload', '', 0));
        continue;
      }
      try {
        final data =
            jsonDecode(await metadata.readAsString()) as Map<String, dynamic>;
        result.add(
          PendingUpload(
            entry,
            data['name'] as String,
            data['mime'] as String,
            data['size'] as int,
            documentId: data['document_id'] as String?,
          ),
        );
      } on FormatException {
        result.add(PendingUpload(entry, 'Saved upload', '', 0));
      } on TypeError {
        result.add(PendingUpload(entry, 'Saved upload', '', 0));
      }
      // Invalid records remain dismissible without blocking other uploads.
    }
    return result;
  }

  Future<void> clear(String owner) async {
    final root = await _owner(owner);
    if (await root.exists()) await root.delete(recursive: true);
  }
}

class PendingUpload {
  PendingUpload(
    this.folder,
    this.name,
    this.mime,
    this.sizeBytes, {
    this.documentId,
  });
  final Directory folder;
  final String name;
  final String mime;
  final int sizeBytes;
  String? documentId;

  PickedUpload get file => PickedUpload(
    name: name,
    mime: mime,
    sizeBytes: sizeBytes,
    openRead: () => File('${folder.path}/bytes').openRead(),
  );

  Future<void> verifyBytes() async {
    final bytes = File('${folder.path}/bytes');
    if (!await bytes.exists() || await bytes.length() != sizeBytes) {
      throw const RequestRejectedException(
        'The saved file is incomplete or unavailable. Choose the file again.',
        code: 'saved_upload_missing',
      );
    }
  }

  Future<void> checkpoint() async {
    final temporary = File('${folder.path}/metadata.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'name': name,
        'mime': mime,
        'size': sizeBytes,
        'document_id': documentId,
      }),
      flush: true,
    );
    await temporary.rename('${folder.path}/metadata.json');
  }

  Future<void> remove() async {
    if (await folder.exists()) await folder.delete(recursive: true);
  }
}
