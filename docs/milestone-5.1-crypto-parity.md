# Milestone 5.1 verification — 2026-10-10

Follow-up [implementation audit](milestone-5.1-audit.md) found an empty-
passphrase compatibility defect and missing KDF input-wiring coverage.
Both are now resolved: seven crypto tests, 679 full-suite passes (30 gated
skips), and a repeated Android check covering empty-password rejection and
the Unicode/nonzero-salt vector. Original validation below records 5.1's
initial implementation run.

The exit criteria require identical web/Dart Argon2id parameters and a
known-answer derived key, plus AES-256-GCM byte-preserving round trips.
This isolated milestone has no backend call. Deployed stored-document
interoperability in both directions belongs to 5.2 and has not been tested.
The owner authorized 5.1 while leaving Phase 4's owner gate open.

## Source and parameters

Checked actual `apps/web/src/lib/crypto/seal.ts` and `seal.test.ts` in
`Tunasmelt/Cerebro-2.0`, checkout
`714fcae25c5cffa9446c31455b2bbdb52adb12a5`, and backend
`services/api/app/core/sealed_storage.py`.

| Parameter | Value |
| --- | --- |
| KDF | Argon2id v19, web hash-wasm 4.12.0 |
| Memory | 65536 KiB (64 MiB) |
| Iterations / parallelism | 3 / 1 |
| Salt / derived key | 16 / 32 bytes |
| Cipher | AES-256-GCM |
| Nonce / tag | 12 / 16 bytes |
| Payload | Ciphertext followed by tag, nonce separate, no AAD |
| Password encoding | UTF-8, no trimming or normalization |

One salt/key per document, fresh nonce per chunk. Derivation runs in a
separate isolate. The module has no persistence or networking. The derived
key will transit per request during unlock integration, matching web;
this is not a zero-knowledge design.

## Dependency currency

Checked [cryptography](https://pub.dev/packages/cryptography) and its
[changelog](https://pub.dev/packages/cryptography/changelog): version 2.9.0,
Apache-2.0, Android/iOS support, latest release listed ten months ago.
Its Argon2id API exposes the required parameters. Only this dependency was
added; optional native AES acceleration is deferred.
[Supabase Flutter](https://pub.dev/packages/supabase_flutter) currently lists
2.18.2; existing locked 2.17.2 is unchanged because this module uses no auth
or storage API. Backend `main.py` has no CORS middleware/native Origin gate;
no networking behavior changed here.

## Independent vectors

Executed a byte-identical copy of the actual web `seal.ts` under Node 24
with hash-wasm 4.12.0, calling `deriveKeyBytes` and `deriveKey`, then native
WebCrypto AES-GCM. Inputs: password `known-answer-test-passphrase`, zero
16-byte salt, zero 12-byte nonce, UTF-8 plaintext `known-answer plaintext`.

Derived key (hex):
```
618f4f27fcd47aa29457002646074dfaeecd9a8cc2fa63df9dbba959e2c7ed76
```
Ciphertext followed by tag (hex):
```
9857113140ae53f7cf8fed6a2878ba560f05a3f5cec53ab38be578a2eb17f2a1841f273fbff0
```
The ciphertext also matches the web repo's existing hard-coded test vector.
These fixed salts/nonces are public test inputs, never production inputs.

## Validation

- Crypto suite: 5 passed. Covers web vectors, arbitrary bytes and empty
  plaintext, changed ciphertext/tag/nonce, wrong key, random salt/nonce,
  and invalid lengths.
- Full suite: 677 passed, 30 skipped (gated tests).
- Flutter analysis: no issues.
- Android 16 emulator (`emulator-5554`): compiled native app derived the
  expected key, produced expected ciphertext, decrypted it, and emitted
  `MILESTONE_5_1_DEVICE_PARITY_PASS` in logcat. Screenshot:
  [verified result](screenshots/milestone-5.1-crypto-parity-live.png).

Reproduce with:
```
flutter test test/core/crypto/sealed_crypto_test.dart
flutter run -d emulator-5554 -t scripts/crypto_parity_check.dart
```
The parity entrypoint displays `Crypto parity verified` only after all
three comparisons pass. Restore the normal app with
`flutter run -d emulator-5554 -t lib/main.dart` afterward.
No iOS device run, sealed UI integration, or real-document cross-platform
proof is claimed. Phase 4 and Phase 5 owner gates remain open.
