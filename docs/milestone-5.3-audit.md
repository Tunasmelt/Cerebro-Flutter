# Milestone 5.3 implementation/test audit — 2026-10-11

Scope: production controls, API flow, claim lifecycle, chat integration,
deletion/auth/navigation races and the real-device verification entrypoint.
Reviewed against actual web crypto, Documents handlers and backend sealed
and chat routes. This is a 5.3 audit; no 5.4 adversarial stage is claimed.

## Findings and fixes

### P1 — A late unlock could undo an explicit lock (fixed)

`SealedDocumentControls._submit` originally checked only the widget's
document/user generation. Two open detail screens can request the same
document independently. If the newer request completes and the owner
locks it, the older response could still call `remember` and restore
plaintext plus chat access. Deletion's `forget` had the same missing
invalidation for pending work.

A widget reproduction starts an unlock, simulates the other screen's
successful response, taps the real Lock now control, then completes the
older request. Before the fix, the expected empty session contained the
claim and private text. The regression failed in
`dev-logs/m53-audit-red.log`.

Fix: the shared unlock session issues a per-document operation token.
Only the newest pending operation can commit. Remembering a successful
unlock, explicit lock, deletion and user reset invalidate earlier work.
Expired entries also cancel pending operations for that document. The UI
requires an accepted commit and retains generic error presentation.
The widget reproduction and newest-operation/session tests now pass.

### P2 — API flow had no transport-level regression coverage (addressed)

Existing widget tests replaced the entire API with a fake, and the live
5.3 unlock/expiry run was incomplete. They could not detect incorrect
generated request fields, missing claims/keys, failure to stop after a
wrong-key response or chunk encryption mistakes.

Added tests using the real generated client, auth interceptor and crypto
against a controlled HTTP transport. They verify two ordinals encrypted
with one salt and distinct nonces, authenticated plaintext round trips,
the independently known web-derived key in the unlock body, matching
claim/key on unseal, sorted display content, no unseal after HTTP 401,
and no returned unlock/content after HTTP 429 on unseal.
These are local regression checks, not substitutes for real-device tests.

### P1 — Account switch could accept an old pending response before rebuild (fixed)

Riverpod rebuilds a dependent session lazily. Between changing users and
reading that session again, `remember` previously checked only that some
user was signed in and the operation token matched. An old response could
therefore restore another account's plaintext/key before the reset ran.
The new reproduction switches accounts without rereading the session and
attempts to commit the old token. It failed before the fix and now passes.
`remember` compares the current account with the identity captured by
`build`, rejecting that response before any state write.

### P2 — Malformed or already expired claims reached unseal (fixed)

Transport coverage showed that an empty `claim_id` and an already expired
`expires_at` continued to `/unseal`. Reject both immediately after the
unlock response, avoiding a useless request against the limited endpoint.
The existing second expiry check remains necessary when a valid claim
expires while unseal is in flight. Regressions cover both boundaries.

## Other reviewed behavior

### P1 — Backend cannot save a sealed retrieval's chunk IDs (cross-repo; fixed and live-verified)

The real Android run unlocked a 60-chunk fixture and returned the exact
original content hash. A fresh production chat retrieved that fixture,
generated its unique answer and cited it, but ended with an error rather
than `done`. An independent request to the same real chat endpoint with
the same valid claim reproduced the failure; its SSE error contains
PostgreSQL's `invalid input syntax for type uuid`.

Actual backend source explains the mismatch:
`retrieve/retrieve.py::_sealed_exact_matches` creates chunk IDs as
`document_id:ordinal`; `chat/stream.py` passes those IDs unchanged to
`ChatStorage.save_message`; `chat/storage.py` inserts them into
`chat_messages.retrieved_chunk_ids`, declared `uuid[]` by migration 0001.
The live error confirms that the storage boundary rejects this shape.
This affects web/mobile backend chat persistence, not native key derivation.

Per AGENTS.md's backend ownership boundary, this is flagged for a fix in
`Tunasmelt/Cerebro-2.0`. No backend or schema change was made, and the
client still marks this incomplete answer failed. Do not hide the terminal
error, drop evidence IDs client-side or count this as a passing chat turn.
The diagnostic chat was deleted. Sanitized evidence is in ignored
`dev-logs/m53-backend-diagnostic-expiry.log`; the Android
[failed-turn screenshot](screenshots/milestone-5.3-unlocked-chat-error.png)
shows the answer, source and incomplete-answer notice.

## Other reviewed behavior

- Local expiry is valid immediately before the timestamp and expired at
  and after it; expired keys/content are removed before new chat requests.
- Timer and resume checks clear content without requiring a restart.
- Sign-out/user changes clear sessions and invalidate late responses,
  including signing back into the same account before a response arrives.
- Manual lock and successful deletion drop local access. The server has
  no revocation endpoint, matching web's memory-only forget behavior.
- Navigation drops late unlocks; sealing after navigation still refreshes
  the owner's document list. Passphrases are obscured and cleared.
- Unlock errors remain generic; no passphrase/key/token logging or
  persistence was introduced. No package/backend change was needed.

## Earlier validation and remaining work

The follow-up [coverage plan](milestone-5.3-test-plan.md) assigned three
subagents API, UI and session/chat/deletion work. They added **54 cases**:
30 transport, 15 widget and 9 session/chat/deletion cases. API tests now
include failure at all five request stages, malformed response data,
expiry before/during unseal and sign-out between calls. UI checks include
empty/duplicate submissions, cancellation/retry, account/document changes,
late disposal, password privacy and re-unlock/navigation persistence.
Session checks cover independent documents, timer restart/disposal, lazy
account transition, deletion cancellation and actual chat callback filtering
at subscription time. Strengthened disposal coverage checks a live session.

Combined full suite: **751 passed, 30 gated skips**. `flutter analyze` and
`git diff --check` are clean. These follow the earlier audit's 697 passed;
configured/credential-dependent skips are not counted as passes.
The coverage Android build compiled and installed. Against the real
backend, an isolated 60-chunk fixture passed production sealing,
locked-chat exclusion (01:55:56 Dubai), and unlock/unseal with a full
content-hash comparison (02:00:14 Dubai). Unlocked chat exposed the
confirmed backend UUID persistence failure above. Earlier HTTP 429 and
an unreliable older fixture are recorded as unsuccessful attempts, not
passes, in the [verification record](milestone-5.3-seal-unlock.md).

The actual server-issued expiry is 02:15:13 Dubai. The emulator shut down
at 02:09:14 before expiry; F5/F7 remain unverified because a restart cannot
prove same-process removal. Read-only VM inspection proved one active
entry at 02:07:52, not its later removal. The independent server-expiry
probe passed at 02:15:16: HTTP 401/`claim_expired` for the original claim.
Cleanup is recorded in the [coverage plan](milestone-5.3-test-plan.md).
Owner Phase 4 and
Phase 5 gates remain open. iOS execution is unavailable on this Windows
host. Milestone 5.3 remains incomplete while real unlocked chat cannot
finish successfully; no dependent 5.4 work has started.


## Backend repair and completion rerun

The owner authorized the cross-repo repair on October 11. Backend
[PR #92](https://github.com/Tunasmelt/Cerebro-2.0/pull/92) merged as
`fb60b59284d4d1dd4cb576ac9998d619d4f08582`; the live `/health` reports
that exact build. Sealed retrieval uses the real sealed row UUID instead
of `document_id:ordinal`. Chat history resolves missing indexed UUIDs
against sealed metadata with caller RLS, selecting only `id,document_id`.
No schema migration, public unseal response change or plaintext lookup
was added. Regressions failed before the fix and pass afterward; full
backend suite: 543 passed, Ruff clean, both GitHub CI jobs passed.

A fresh disposable 60-chunk fixture passed production sealing, locked
chat and exact original-content hash on Android PID 4699. The original
server-issued expiry is 2026-10-10T22:56:32.909578Z (02:56:32 Dubai).
The first unlocked chat timed out before retrieval, independently of the
previous persistence defect. A fresh conversation and API diagnostic
are running while the same app stays alive for actual expiry. Completion
is not inferred from the backend unit tests or publication.


### P1 - Multi-chunk sealed IDs entered indexed graph reinforcement (fixed)

The first deployment removed the invalid-UUID persistence mismatch, but
real 60-chunk native chat timed out before retrieval. Actual graph storage
constructs every pair, awaits GET/POST for each and does not check rejected
insert responses. Sixty sealed UUIDs therefore attempt 1,770 pairs against
an edge table whose foreign keys reference indexed chunks. With legacy
synthetic IDs, the initial lookup had failed early instead.

The new regression reproduces zero eligible indexed chunks with 60 sealed
UUIDs; it failed before the fix. Reinforcement now performs one caller-RLS
indexed-ID lookup before constructing pairs. The sealed-only case makes
one metadata request and zero writes; mixed retrieval preserves indexed
pairs. Backend [PR #93](https://github.com/Tunasmelt/Cerebro-2.0/pull/93)
merged as `f4625869b5c858a6e3c14c36166854047102ee60`. Full backend suite:
545 passed, Ruff clean, both CI jobs passed. The original Android app and
claim remain active while deployment and native completion are verified.


After `/health` reported `f462586`, a fresh production native turn
completed with the exact synthetic answer and source citation. A scoped
history check confirmed exactly one completed native test chat after the
new build, with the fixture's document ID, retained citation and UUID
chunk IDs. Independent real SSE also reached `done`, saved the assistant
message and retained its citation; the diagnostic chat was deleted.
The same Android PID 4699 and original claim remained active. Evidence:
`dev-logs/m53-native-history-check.log`,
`dev-logs/m53-completion-backend-diagnostic.log`, and the
[completed native chat](screenshots/milestone-5.3-completed-chat.png).


## Final required Android outcomes

Original PID 4699 survived the full server-issued window without restart.
At 02:56:35 Dubai the production session map no longer contained the
fixture and the detail UI removed plaintext/countdown. At 02:56:38 the
original claim/key returned 401/claim_expired; at 02:56:46 a fresh native
chat completed without the fixture or synthetic fact. The successful
post-deployment native chat/history check separately supplies the positive
unlocked-turn proof missing from the initial timed-out harness attempt.
Its raw incomplete aggregate marker is preserved, not presented as a pass.
All required Android cases are verified. Disposable IDs return 404, chats
were cleaned up, and normal app restoration exited 0. Owner gates remain
open; iOS device execution is not claimed.
