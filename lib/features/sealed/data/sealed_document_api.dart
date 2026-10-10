import 'dart:convert';

import 'package:chopper/chopper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/sealed_crypto.dart';
import '../../../core/network/generated/cerebro_api.swagger.dart';
import '../../../core/network/generated_api_client_provider.dart';
import 'unlock_session.dart';

final sealedDocumentApiProvider = Provider<SealedDocumentApi>((ref) {
  return ApiSealedDocumentApi(ref.watch(generatedApiClientProvider));
});

abstract interface class SealedDocumentApi {
  Future<void> seal(String documentId, String passphrase);
  Future<ActiveUnlock> unlock(String documentId, String passphrase);
}

class ApiSealedDocumentApi implements SealedDocumentApi {
  ApiSealedDocumentApi(this._api);
  final CerebroApi _api;

  Map<String, dynamic> _body(Response response) {
    if (!response.isSuccessful) throw StateError('Sealed request failed');
    return response.body as Map<String, dynamic>;
  }

  @override
  Future<void> seal(String documentId, String passphrase) async {
    final body = _body(
      await _api.apiV1GraphNodesDocumentIdChunksGet(documentId: documentId),
    );
    final plaintext = body['chunks'] as List;
    if (plaintext.isEmpty) throw StateError('No content to seal');
    final salt = generateSealedSalt();
    final key = await deriveSealedKey(passphrase, salt);
    final chunks = <SealChunkBody>[];
    for (final item in plaintext) {
      final row = item as Map<String, dynamic>;
      final encrypted = await encryptSealedChunk(
        utf8.encode(row['content'] as String),
        key,
      );
      chunks.add(
        SealChunkBody(
          ordinal: row['ordinal'] as int,
          contentCiphertext: base64Encode(encrypted.ciphertext),
          salt: base64Encode(salt),
          nonce: base64Encode(encrypted.nonce),
        ),
      );
    }
    _body(
      await _api.apiV1DocumentsDocumentIdSealPost(
        documentId: documentId,
        body: SealBody(chunks: chunks),
      ),
    );
  }

  @override
  Future<ActiveUnlock> unlock(String documentId, String passphrase) async {
    final salt =
        _body(
              await _api.apiV1DocumentsDocumentIdSealSaltGet(
                documentId: documentId,
              ),
            )['salt']
            as String;
    final key = await deriveSealedKey(passphrase, base64Decode(salt));
    final keyB64 = base64Encode(await key.extractBytes());
    final claim = _body(
      await _api.apiV1DocumentsDocumentIdUnlockPost(
        documentId: documentId,
        body: UnlockBody(key: keyB64),
      ),
    );
    final expiresAt = DateTime.parse(claim['expires_at'] as String);
    final claimId = claim['claim_id'] as String;
    if (claimId.isEmpty) throw StateError('Invalid claim');
    if (!DateTime.now().isBefore(expiresAt)) throw StateError('Claim expired');
    final clear = _body(
      await _api.apiV1DocumentsDocumentIdUnsealPost(
        documentId: documentId,
        body: UnsealBody(claimId: claimId, key: keyB64),
      ),
    );
    final chunks =
        (clear['chunks'] as List).cast<Map<String, dynamic>>().toList()..sort(
          (a, b) => (a['ordinal'] as int).compareTo(b['ordinal'] as int),
        );
    if (!DateTime.now().isBefore(expiresAt)) throw StateError('Claim expired');
    return ActiveUnlock(
      documentId: documentId,
      claimId: claimId,
      key: keyB64,
      expiresAt: expiresAt,
      content: chunks.map((row) => row['content'] as String).join('\n\n'),
    );
  }
}
