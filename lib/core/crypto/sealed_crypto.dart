import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

// Exact values from Cerebro-2.0/apps/web/src/lib/crypto/seal.ts.
const sealedSaltBytes = 16;
const sealedNonceBytes = 12;
const sealedTagBytes = 16;
const sealedKeyBytes = 32;
const sealedMemoryKiB = 65536;
const sealedIterations = 3;
const sealedParallelism = 1;

final _aes = AesGcm.with256bits(nonceLength: sealedNonceBytes);

Uint8List generateSealedSalt() {
  final random = Random.secure();
  return Uint8List.fromList(
    List.generate(sealedSaltBytes, (_) => random.nextInt(256)),
  );
}

/// No persistence or networking. Derivation runs away from the UI isolate.
/// Passphrase encoding is UTF-8 without trimming/normalization, matching web.
Future<SecretKey> deriveSealedKey(String passphrase, List<int> salt) async {
  if (passphrase.isEmpty) {
    throw ArgumentError('Password must be specified.');
  }
  if (salt.length != sealedSaltBytes) {
    throw ArgumentError('Salt must be 16 bytes.');
  }
  final copiedSalt = Uint8List.fromList(salt);
  final bytes = await Isolate.run(() async {
    final key = await Argon2id(
      memory: sealedMemoryKiB,
      iterations: sealedIterations,
      parallelism: sealedParallelism,
      hashLength: sealedKeyBytes,
    ).deriveKeyFromPassword(password: passphrase, nonce: copiedSalt);
    return key.extractBytes();
  });
  return SecretKey(bytes);
}

/// WebCrypto's wire format: ciphertext followed by its 16-byte GCM tag.
class SealedChunk {
  const SealedChunk({required this.ciphertext, required this.nonce});
  final List<int> ciphertext;
  final List<int> nonce;
}

/// Derive one key per document; reuse it with a fresh nonce for each chunk.
/// Leave [nonce] omitted in production. Explicit nonces are for fixed-vector
/// verification; never reuse a nonce under the same key.
Future<SealedChunk> encryptSealedChunk(
  List<int> plaintext,
  SecretKey key, {
  List<int>? nonce,
}) async {
  if (nonce != null && nonce.length != sealedNonceBytes) {
    throw ArgumentError('Nonce must be 12 bytes.');
  }
  final box = await _aes.encrypt(plaintext, secretKey: key, nonce: nonce);
  return SealedChunk(
    ciphertext: Uint8List.fromList([...box.cipherText, ...box.mac.bytes]),
    nonce: Uint8List.fromList(box.nonce),
  );
}

/// Authenticated decryption: wrong key or modified bytes throw, never return
/// unauthenticated plaintext. UI error mapping belongs to the integration.
Future<List<int>> decryptSealedChunk(SealedChunk chunk, SecretKey key) async {
  if (chunk.nonce.length != sealedNonceBytes ||
      chunk.ciphertext.length < sealedTagBytes) {
    throw ArgumentError('Invalid sealed payload length.');
  }
  final tagStart = chunk.ciphertext.length - sealedTagBytes;
  return _aes.decrypt(
    SecretBox(
      chunk.ciphertext.sublist(0, tagStart),
      nonce: chunk.nonce,
      mac: Mac(chunk.ciphertext.sublist(tagStart)),
    ),
    secretKey: key,
  );
}
