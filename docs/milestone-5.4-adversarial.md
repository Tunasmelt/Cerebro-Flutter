# Milestone 5.4 adversarial verification

Status: required Android checks passed, including the deployed backend
repair and full native rerun. Required Android 5.3 checks passed before this stage.
Phase 4 and Phase 5 owner gates remain open. Real iOS device execution is
unavailable on this Windows host.

The exit criteria require real native/backend denial of sealed plaintext
under direct questions, prompt injection, malformed requests and another
authenticated user's document access. These checks exercise bounded cases;
they do not establish that every possible attack has been exhausted.

## Repeating the native checks

Create a disposable indexed text document containing the question
`What is the saffron harbor access phrase?` and a unique synthetic answer.
Keep the answer out of the filename and question. Use the production
signed upload flow and confirm ingestion is ready before testing.

Set `CEREBRO_TEST_USER_B_EMAIL` and `CEREBRO_TEST_USER_B_PASSWORD` in a
local process environment for a confirmed account different from the
fixture owner. Run `node scripts/sealed_security_credentials.mjs` from
the repository root, then clear the environment variables. The helper
validates the login and serves credentials once on loopback port 47854;
it closes after that handoff or 15 minutes. No credentials go in source,
build defines, logs or plaintext files.

Run `adb reverse tcp:47854 tcp:47854`, then:

```powershell
flutter run -d emulator-5554 -t scripts/sealed_security_check.dart --no-resident `
  --dart-define=SEALED_TEST_DOCUMENT_ID=<disposable-id> `
  --dart-define=SEALED_TEST_ANSWER=<unique-synthetic-answer> `
  --dart-define=SEALED_TEST_BUILD_SHA=<expected-deployed-commit>
```

Tap the real Seal control and its confirmation. The harness fills the
public synthetic passphrase used by the 5.3 verification helper. Keep
the fixture locked throughout these checks. Collect only
`MILESTONE_5_4_` markers from Android logcat. The secondary Supabase
client signs in without replacing the owner's persisted SDK session;
both clients use the production generated API/auth interceptor.

| Case | Required result | Result |
|---|---|---|
| Locked direct question | Completed fresh native turn and saved history omit synthetic secret | Passed again 03:26:21 Dubai; fresh completed turn and history exclude the fact |
| Locked prompt injection | Completed fresh native turn and saved history omit synthetic secret | Passed again 03:26:35 Dubai; fresh completed turn and history exclude the fact |
| Malformed unlock key | HTTP 401 / invalid_key; no plaintext | Passed 03:26:36 Dubai: HTTP 401 / invalid_key after backend repair |
| Missing unlock key | HTTP 422; no plaintext | Passed again HTTP 422 |
| Unknown unseal claim | HTTP 404; no plaintext | Passed again HTTP 404 |
| Second user's document detail | HTTP 404; no partial document | Passed again HTTP 404 |
| Second user's salt | HTTP 404; no salt | Passed again HTTP 404 |
| Second user's chunks | HTTP 404; no chunks | Passed again HTTP 404 |
| Second user's unlock | HTTP 404; no claim or plaintext | Passed again HTTP 404 |
| Second user's unseal | HTTP 404; no plaintext | Passed again HTTP 404 |
| Session isolation | Second user differs from owner; owner session remains signed in | Passed again: different native user; owner unchanged |

Metadata stays searchable by design. A sealed metadata hit is not itself
evidence of leaked content. Each chat starts a fresh conversation with
no active unlocks, so previous answers cannot supply the private fact.
The backend's five/hour sealed-operation limit applies normally;
HTTP 429 is an incomplete check, not the expected denial above.

The harness deletes its test chats. Delete only the disposable fixture,
verify its GET returns 404, remove the ADB reverse mapping, and restore
the normal `lib/main.dart` app afterward. Keep any created test account
available for repeat verification until the owner requests removal.

Stale-claim rejection after the full server-issued 15 minutes is recorded
in [5.3 completion evidence](milestone-5.3-seal-unlock.md). Automated
checks do not satisfy the owner-run Phase 5 gate.

## Initial live Android run — 2026-10-11

The Android 16 emulator ran the real production app/providers under the
verification entrypoint, PID 5967, against deployed API build f462586.
Fixture `44463aec-40d8-488c-8cb1-f90ac717ab09` had four real indexed chunks
and was sealed using the production controls before the tests. The
confirmed secondary account signed in through an independent native
Supabase client; its ID differed from the owner's. Five cross-user API
requests returned 404 at 03:14:59–03:15:01 Dubai. No owner session replacement
or protected salt/chunks appeared. Both test conversations were deleted.

The full raw aggregate is `MILESTONE_5_4_DEVICE_FUNCTIONAL_INCOMPLETE`: the
malformed key `%%%` returned 500 instead of 401. Preserve this initial failure as historical evidence; the deployed-device
completion rerun below separately verifies the correction. Synthetic-only screenshots:
[sealed fixture](screenshots/milestone-5.4-sealed.png),
[injection refusal](screenshots/milestone-5.4-injection-chat.png).
Ignored run evidence: `dev-logs/m54-{device-run,device-markers,analyze}.log`.

### Backend finding: malformed key bypasses generic error handling

The shared `_decrypt` helper in the web/backend repository decoded the
key outside its exception handler and caught only authentication-tag
failures. Empty/incorrectly sized keys raised ValueError; malformed padding
raised a decoding error. Base64 also silently ignored garbage appended
to an otherwise valid key. This is backend-owned behavior, not a client
workaround.

The fix on `fix/milestone-5.4-malformed-unlock-key` moves strict key
decoding into the handler and maps decoding/key-length errors to the
existing invalid_key exception. Both unlock and unseal share the fix.
Six storage regressions failed before the change and pass afterward;
58 targeted sealed tests and all 551 backend tests pass, with Ruff clean.
The production web build also passed.
The owner authorized publication and retesting.
[Backend PR #94](https://github.com/Tunasmelt/Cerebro-2.0/pull/94) is open;
all CI checks passed and it merged as `8415003`. Render deployed that
exact commit before the full native rerun. The harness checks the deployed
SHA before its adversarial calls when the expected build define is provided.

## Completion rerun — 2026-10-11

The same four-chunk sealed fixture was tested again on Android 16, PID
6505, against `8415003bdd85fbf0185f90cf8dc6a578c6a91b69`. Native health
verification passed at 03:25:58 Dubai before any adversarial call. Direct
and injection chats both completed and their saved histories omitted
the unique fact. The malformed key returned HTTP 401 / invalid_key at
03:26:36; missing key returned 422 and the unknown claim returned 404.
All five second-user requests returned 404 at 03:26:41–03:26:44. The
secondary user differed from the owner, whose persisted session was
unchanged. Both test chats were deleted before the final aggregate:
`MILESTONE_5_4_DEVICE_FUNCTIONAL_PASS` at 03:26:45.737 Dubai.

The disposable fixture was deleted and its owner GET verified 404.
The normal `lib/main.dart` app was rebuilt, installed and restored with
exit 0 (PID 6751). The one-use credential helper closed; the ADB reverse
mapping was removed.
The confirmed test account is retained for repeat verification. Its
random password is Windows DPAPI-protected outside the repository.
No derived keys, account passwords or JWTs were recorded in source,
build defines or logs. The reused helper contains an explicitly public
synthetic fixture passphrase.

`flutter analyze`, Dart formatting, Node syntax validation and the native
build passed. Backend validation: 551 tests, Ruff and the production web
build passed; PR #94's API/web CI and Vercel checks passed before merge.
Ignored final evidence:
`dev-logs/m54-{retest-device-run,retest-markers,retest-analyze,fixture-cleanup,final-normal-restored}.log`.
Earlier failing markers remain intact in their original log.

Required Android 5.4 cases pass. This does not close either owner phase
gate or establish real iOS device execution.
