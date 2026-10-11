# Milestone 6.3 — read-only Token Playground

The owner selected read-only scope on 2026-10-11. Mobile shows a saved assistant
turn's reconstructed prompt and estimates. Web also offers edited generation;
that additional surface is outside the owner's selected mobile scope.

## Contract and implementation

Verified against `Tunasmelt/Cerebro-2.0` main
`8415003bdd85fbf0185f90cf8dc6a578c6a91b69`, specifically
`services/api/app/routes/chat.py`, `services/api/app/chat/playground.py`, and
`apps/web/src/app/playground/page.tsx`.

- Conversation listing reuses the existing chat-history API. Assistant selection
  preserves the database message IDs from the messages endpoint; the chat
  bubble's local integer IDs cannot identify a prompt-breakdown request.
- GET `/api/v1/chat/sessions/{session_id}/messages/{message_id}/prompt` returns
  model, ordered sections (label/content/tokens/citation), saved response and its
  token count, total estimated tokens, and estimated USD cost. Non-assistant,
  missing, and inaccessible messages receive 404.
- The backend reconstructs prompt sections from saved retrieval references. This
  is labeled as reconstructed, with estimated tokens and cost, rather than an
  immutable snapshot or measured usage.
- Mobile displays returned values directly. Input tokens are total minus response
  tokens. Section badges exclude assembled formatting, so their sum is not used
  to replace the server's total. No client tokenizer, price calculation, invented
  latency, editable field, or generation button remains.
- Auto-disposed Riverpod futures handle selection changes and late results.
  Account changes clear both selections. Each failed read can retry its own
  endpoint; empty conversations and empty assistant lists have explicit guidance.

Existing Chopper/Riverpod, selectable text, and the existing stat tile suffice.
No new package, generated-client edit, backend change, or production write is
needed. The unused mock code editor was removed.

## Automated tests

22 API/widget tests cover authenticated GET paths, preservation of assistant
database IDs, server values, malformed responses, 401/404/422/429/500 errors,
read-only rendering, section/citation display, selection changes, empty states,
retries, and an account change while a prompt response is pending.
The full suite passes 839 tests with 30 existing opt-in skips. Skips are not
device proof. The Phase 6 owner gate remains open; iOS device verification
remains unavailable on this Windows host.

## Real-device verification

Use Android 16, `emulator-5554`, the normal signed-in owner session, and deployed
API `https://cerebro-api-d47y.onrender.com`. Fetch a saved assistant turn's
breakdown through an authenticated GET. Keep content in memory; supply only its
public IDs and a SHA-256 of the normalized response to the observer harness:

```powershell
flutter run -d emulator-5554 --no-resident -t scripts/playground_readonly_check.dart `
  --dart-define=PLAYGROUND_TEST_SESSION=<session-id> `
  --dart-define=PLAYGROUND_TEST_MESSAGE=<assistant-message-id> `
  --dart-define=PLAYGROUND_EXPECTED_SHA256=<normalized-response-digest>
```

The normalized JSON has keys, in order: `model`, `sections`, `response`,
`total_tokens`, `cost`. Section keys are `label`, `content`, `tokens`, `citation`;
response keys are `content`, `tokens`; cost is a string with six decimal places.
Encode as UTF-8 and hash with SHA-256. The script contains the exact normalization.

Select that conversation and assistant reply through the production pickers.
Only that UI-triggered provider result activates verification: the observer
does not load a prompt on startup. It compares both the displayed model and
all content/estimates with the expected digest and a fresh independent GET,
then prints `MILESTONE_6_3_UI_AND_FRESH_BACKEND_BREAKDOWN_PASS`.
Inspect the displayed estimates and scroll the sections/response; confirm
there are no editable fields or run controls. Restore the normal `lib/main.dart`
build afterward. Do not publish private conversation screenshots or content.

Recorded on 2026-10-11 with the real signed-in owner and production pickers:
process 11642 emitted the full UI/fresh-backend digest pass marker; after an
emulator reboot, process 2103 emitted the same pass again. The native screen
showed the returned model, 616 input tokens, 124 output tokens, 740 total tokens,
and estimated USD cost of $0.000495. Android UI inspection confirmed those
values and the absence of editable fields. Scrolling displayed retrieved
sections/citation labels and reached the saved user query and response.

The initial conversation-list read failed; its production Retry loaded the
real sessions. UI-inspection connection stalls were resolved by rebooting the
emulator while preserving its account and app data. The fresh run's inspection
was responsive. A helper's whole-section text matching could not match the
complete long system section in a single viewport; the full-content digest
check and direct visual inspection cover that distinction. Interrupted runs
and partial text matches are not counted as full-content proof.

No history or prompt data was created, modified, or deleted. Private screenshots
remain in ignored local logs and are not included in the repository. The normal
`lib/main.dart` application was rebuilt and restored after verification.
Analysis has no issues. The Phase 6 owner gate remains open, and iOS device
checks remain pending.



## Owner confirmation — 2026-10-11

The owner subsequently confirmed all implemented phase gates as verified.
Phase 6’s owner gate is closed; earlier pending-gate notes in this record
describe the status at implementation time. Agent-run iOS verification
was not performed in this Windows environment.
