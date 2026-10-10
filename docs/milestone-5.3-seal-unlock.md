# Milestone 5.3 â€” implemented; functional verification in progress

Started 2026-10-11 after 5.2's real Android/deployed-web checks passed.
Phase 4 and Phase 5 owner gates remain open. No 5.4 work started.

## Required outcome

Production controls must seal through `/seal`, derive from stored salt,
obtain `/unlock` claims and fetch `/unseal` content. Chat supplies active
document IDs, claims and keys. Sealed content must be excluded before
unlock, retrievable during the claim, and excluded after automatic expiry
without restarting the app. The server enforces a fixed 15-minute window;
its actual source has no shortened-expiry testing option.

## Implementation

- Ready/sealed document detail pages expose seal/unlock controls with
  hidden passphrase input, busy state, generic failure and cancellation.
  Passphrases are not trimmed and are cleared on submit, cancellation,
  document/user change and disposal. Input learning/suggestions are off.
- Reuses 5.1's isolated Argon2id and AES-GCM helper: one document salt/key,
  fresh chunk nonce, ciphertext with appended authentication tag. No new
  package or backend change.
- `unlockSessionProvider` retains keys, claim IDs and visible plaintext
  only in memory across navigation. Server-provided `expires_at` controls
  countdown and removal; the exact boundary is expired. A periodic timer
  and resume check clear expired entries. Chat prunes them before sending.
- Manual lock, deletion, sign-out and user change drop active entries.
  Pending unlocks use shared per-document operation tokens: a late
  response cannot undo manual lock/deletion or replace a newer unlock.
  Closing a screen or changing users/documents discards late unlock
  responses. Sealing completion refreshes the owner's list even if the
  screen has closed.
- Chat's existing streaming client sends web's `unlocked` array with
  `document_id`, `claim_id`, `key`. No unlock data is persisted or logged.
  Server enforcement remains authoritative; local clocks cannot extend a
  claim's server validity. Manual lock forgets local access, matching web;
  the API provides no claim-revocation endpoint.

## Evidence so far

- Unit/widget checks cover the 15-minute boundary, removal of expired
  content/keys, user changes, resume, manual lock, generic failure,
  late responses, sealing completion after navigation, deletion and chat
  payloads. After the delegated coverage work, full suite: **751 passed,
  30 gated skips**; analysis is clean. The [coverage plan](milestone-5.3-test-plan.md)
  records 54 additional cases and the fixes they exposed.
  Transport tests also cover multiple chunk ordinals/nonces and the exact
  web key/claim body through the real generated client. See the local
  test/analyze logs in ignored `dev-logs/`.
- A real Android build opened the production Document screen and sealed
  disposable document `014476b5-7037-4d65-bc0b-c76f83a20e70`, named
  `m53-expiry-1791665719708.txt`.
- At **2026-10-11 00:59:44 Asia/Dubai**, the production chat controller
  completed a fresh real turn: retrieval omitted this sealed document
  and its synthetic answer was absent. It emitted
  `MILESTONE_5_3_LOCKED_CHAT_PASS`.
- Production unlock displayed the generic failure. A backend diagnostic
  at **2026-10-10 21:01:24 UTC** returned HTTP 429 with
  `Retry-After: 2224`, predicting the next slot around **2026-10-11
  01:38:28 Asia/Dubai**. The shared limit is five sealed operations per
  user/hour. Generic UI alone is not a successful unlock test. No limit
  was bypassed or backend configuration changed.
- Test-created chat `ceb196e2-52d7-410e-96fe-fd547b189ffe` was deleted.
  The original synthetic document was retained for later checks and the
  normal Android entrypoint restored at that point. Subsequent runs used
  fresh fixtures; their baselines in ignored `dev-logs/` contain no credentials.
- Audit follow-up: the corrected Android build repeated locked-chat
  exclusion at **01:16:59 Asia/Dubai**. Unlock again displayed the generic
  failure; a diagnostic at **2026-10-10 21:18:20 UTC** returned 429 with
  `Retry-After: 1209`, predicting **01:38:29 Asia/Dubai**. The follow-up
  test chat `a9add9a5-e63f-43eb-9e79-edc943aa4059` was deleted. Analysis
  is clean, and the normal app restored after the run. Live unlock and
  real expiry remain pending, rather than inferred from local tests.

[Production sealed state](screenshots/milestone-5.3-sealed.png) Â·
[Generic unlock failure during rate limiting](screenshots/milestone-5.3-unlock-rate-limited.png)

### Coverage follow-up device run

The final coverage build repeated `LOCKED_CHAT_PASS` at **01:37:43 Dubai**.
At **01:40:05**, unlock returned HTTP 401, stopped the harness and cleaned
up its test chat. This is not a positive unlock or a verified wrong-key
test: the observer initially recorded status alone. Diagnostic local
decryption of only this synthetic fixture's ciphertext through the owner's
normal RLS-scoped read could not authenticate the documented test password.
Those diagnostics are not claim/backend functional evidence. Independent
review found no crypto/wire discrepancy; the retained fixture/input is
unreliable, and its exact cause remains unproven.

A fresh 60-chunk synthetic fixture was used for the positive run.
The verification entrypoint fills the exact public test passphrase into
the real Flutter field/controller; the production confirmation controls
still perform seal/unlock. It can compare a supplied SHA-256 of the sorted
original chunks joined with `\n\n` against returned display content.
It refreshes an expired saved sign-in before starting and records only
whitelisted error codes/status/retry delay, never keys or tokens. No
production auth/crypto behavior or backend limit was changed.

The fresh fixture `fbd5dd22-be28-44d0-91fa-4df32f28737f` passed
production sealing and isolated locked-chat exclusion at **01:55:56 Dubai**.
Production unlock/unseal passed at **02:00:14 Dubai**: all 60 chunks,
sorted and joined with `\n\n`, matched original SHA-256
`86ffc6de098b3232c9232231e5056ede0f67a3969c7bdc72df12e3c8c161f9b6`.
The exact server-issued expiry is **2026-10-10 22:15:13.403930 UTC**
(**02:15:13 Dubai**).

A fresh unlocked chat retrieved the fixture, generated its unique answer
and cited it, but failed to complete. An independent real SSE request
confirmed `chat_turn_failed` with PostgreSQL invalid-UUID rejection:
sealed retrieval creates `document_id:ordinal` IDs and chat persistence
writes them into `uuid[]`. See the [open backend finding](milestone-5.3-audit.md).
This is not a passing unlocked-chat test. The mobile client correctly
shows the incomplete-answer notice. No backend/schema change was made.

[60-chunk sealed state](screenshots/milestone-5.3-multi-sealed.png) ·
[Unlocked content/countdown](screenshots/milestone-5.3-multi-unlocked.png) ·
[Backend-failed chat turn](screenshots/milestone-5.3-unlocked-chat-error.png)

The emulator shut down at **02:09:14 Dubai**, before real expiry. Its log
records a window-system failure followed by shutdown; exact cause is
unverified. Read-only VM inspection proved one cached unlock at 02:07:52,
but no same-process post-expiry observation was possible. Local automatic
relocking and expired-chat exclusion without restart remain **unverified**;
the passing timer/transport regressions do not replace that device proof.
The independent server-expiry check **passed** after the original real
expiry: at 02:15:16 Dubai, the original claim/key returned HTTP 401 with
`claim_expired`. No server window was shortened or limit bypassed.
Sanitized evidence: ignored `dev-logs/m53-backend-diagnostic-expiry.log`.

All three disposable document IDs now return 404; test chats were cleaned
up, and the normal `lib/main.dart` Android app was rebuilt and restored
with exit 0. No synthetic fixture remains for reuse.

## Repeatable device check

Create a disposable fixture containing the script's literal query and
unique answer. Record its ready-state chunks sorted by ordinal and hash
their plaintext joined with `\n\n`; use the fresh ID/hash, not a deleted
fixture from an earlier run. Then run:

```powershell
flutter run -d emulator-5554 -t scripts/sealed_expiry_check.dart --dart-define=SEALED_TEST_DOCUMENT_ID=<fresh-id> --dart-define=SEALED_TEST_CONTENT_SHA256=<original-hash>
```

The script opens the production app with its restored real sign-in and
providers. Open Seal/Unlock and tap the actual confirmation controls;
the harness fills the public synthetic passphrase `Milestone-5.3-test-only`.
Reserve four sealed-operation slots for seal, unlock, unseal and the
post-expiry rejection. Do not shorten expiry or bypass the real rate limit.
Fresh chat queries contain the exact phrase because backend sealed retrieval
uses exact substring matching. Every chat assertion also requires a
complete terminal result, not just a generated answer.

The harness checks locked exclusion, full-content hash, unlocked chat,
actual 15-minute local expiry, server HTTP 401/`claim_expired`, and fresh
expired-chat exclusion. It cleans up its test chats. A failed unlocked
chat is recorded separately while independent expiry checks continue;
any such failure prevents `DEVICE_FUNCTIONAL_PASS`.

Delete only the disposable fixtures, verify GET returns 404, and restore
`lib/main.dart` after verification. Results are recorded in the
[coverage plan](milestone-5.3-test-plan.md). This milestone remains **incomplete**
until the backend chat persistence defect is fixed and the real unlocked
turn passes. iOS execution and owner gates remain pending.

## Source checks

The [5.3 audit](milestone-5.3-audit.md) records the lock race, its failing
reproduction, the fix and the transport coverage added on October 11.

Actual web source checked: `lib/crypto/seal.ts`, `unlockSession.ts`,
Documents handlers; backend `routes/sealed.py`, `routes/chat.py`,
`core/sealed_storage.py`, `retrieve/retrieve.py`. API currency is verified
by this run's native real-backend calls and 5.2's prior round trips.
Existing package APIs were checked against installed source and current
[Supabase Flutter](https://pub.dev/packages/supabase_flutter) and
[cryptography](https://pub.dev/packages/cryptography) listings. Existing
versions remain unchanged.
