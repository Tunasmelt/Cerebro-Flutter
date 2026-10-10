// Run with flutter run -d <device> -t scripts/crypto_parity_check.dart.
// This replaces the installed app entrypoint; restore lib/main.dart afterward.
// Fixed public test vectors only: no backend credentials or stored documents.
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cerebro_mobile/core/crypto/sealed_crypto.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('Checking crypto parity...'))),
    ),
  );
  final key = await deriveSealedKey(
    'known-answer-test-passphrase',
    Uint8List(16),
  );
  final keyHex = (await key.extractBytes())
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  final sealed = await encryptSealedChunk(
    utf8.encode('known-answer plaintext'),
    key,
    nonce: Uint8List(12),
  );
  final cipherHex = sealed.ciphertext
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  final clear = utf8.decode(await decryptSealedChunk(sealed, key));
  if (keyHex !=
          '618f4f27fcd47aa29457002646074dfaeecd9a8cc2fa63df9dbba959e2c7ed76' ||
      cipherHex !=
          '9857113140ae53f7cf8fed6a2878ba560f05a3f5cec53ab38be578a2eb17f2a1841f273fbff0' ||
      clear != 'known-answer plaintext') {
    throw StateError('Crypto parity failed');
  }
  debugPrint('MILESTONE_5_1_DEVICE_PARITY_PASS');
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('Crypto parity verified'))),
    ),
  );
}
