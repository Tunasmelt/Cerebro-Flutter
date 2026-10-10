# Milestone 5.1 implementation audit — 2026-10-10

Scope: crypto module, dependency wiring, tests, device parity entrypoint,
and verification claims, compared against actual web source at
`714fcae25c5cffa9446c31455b2bbdb52adb12a5`.
No production implementation changed during this audit.

**Follow-up resolution:** both findings were fixed after the owner requested
remediation. Empty passwords now throw before derivation. The nonzero-salt
Unicode vector and independent changed-password/changed-salt assertions are
in the regular suite. Seven crypto tests and the Android parity entrypoint
pass; the full suite now passes 679 tests with 30 gated skips. Original
findings below are preserved as audit history.

## Findings

### P2 — Empty passphrases are accepted where web rejects them

`lib/core/crypto/sealed_crypto.dart:27` validates salt length but not an
empty passphrase. Calling `deriveSealedKey('', sixteenZeroBytes)` succeeds
and returns a 32-byte key. The actual web `deriveKeyBytes` call rejects the
same input with `Password must be specified`: hash-wasm 4.12.0 validates
both string presence and encoded password length before derivation.

An eventual mobile caller could therefore seal with an empty passphrase
that web cannot derive a key for. No current user-facing sealing flow
exists, so this is a module compatibility defect, not a demonstrated
production data-loss incident. Reject empty passphrases in the shared
derivation helper and cover the rejection. Preserve whitespace and UTF-8
encoding for nonempty inputs; do not trim passwords.

Reproduced using the byte-identical web source copy (matching SHA-256
`FE2966938B7C60A2A67DDE1CD748EB65FA810E0B56D6820D01A67AACC00F722E`)
and a separate Dart probe. Neither production source was altered.

### P2 — KDF tests do not protect supplied salt/password wiring

`test/core/crypto/sealed_crypto_test.dart:18` exercises derivation only with
one ASCII password and an all-zero salt. The salt-randomness test does not
derive keys from those salts. Replacing the salt copy in an isolated copy
of the module with `Uint8List(sealedSaltBytes)` leaves all five existing
crypto tests passing. A regression that ignores document salts would break
interoperability and defeat their intended role without failing this suite.

Add an independent web vector with a nonzero salt and a different password,
preferably including Unicode and surrounding spaces. Also assert that
changing either password or salt changes the key. The current production
code correctly forwards both inputs; this finding is a coverage defect.

An additional audit probe already confirms the current implementation
matches web for password `  café 🔒  ` and salt bytes 0 through 15:
```
41bfbcd3214c359fe5d7f1c6e9c4f2fae4b7aefbe06ac9d034ff3c64c3834366
```
This probe is not yet part of the regular regression suite.

## Verified behavior

- Argon2id v19: 65536 KiB, 3 iterations, parallelism 1, 32-byte output;
  application salt is 16 bytes, matching web-generated document salts.
- AES-256-GCM: 12-byte secure random nonce by default, 16-byte appended
  authentication tag, no AAD. Dependency enforces 32-byte AES key length.
- Fixed actual-web key/ciphertext vectors match; byte and empty plaintext
  round trips pass. Wrong keys and altered ciphertext/tag/nonce fail
  authentication.
- KDF runs in a separate isolate. Module has no network, persistence,
  logging of secrets, or backend business logic. Current callers are tests
  and the device verification entrypoint only.
- Existing crypto suite rerun: 5 passed. Flutter analysis rerun: no issues.
- Android 16 emulator parity entrypoint rebuilt and rerun: pass marker
  observed from the new app process in logcat. Normal entrypoint restored
  after verification.
- Isolated probes: Unicode/nonzero-salt parity passed; empty-password
  acceptance reproduced; all 5 tests passed against the salt-ignoring
  mutation. Mutation was confined to ignored audit files.

The prior full-suite result (677 passed, 30 skipped) is evidence from the
implementation run, not a fresh full-suite audit run. No production code
changed to justify repeating that entire suite.

## Boundaries

Real stored-document interoperability in both directions remains 5.2.
No backend call is part of this isolated 5.1 test; no backend integration,
iOS runtime validation, or sealed UI completion is claimed.
Phase 4 and Phase 5 owner gates remain open. Resolve the two findings
before treating the module's compatibility and regression coverage as clean.
