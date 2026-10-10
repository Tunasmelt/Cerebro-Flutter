# Milestone 5.3 uncovered-case coverage plan

Scope: the implemented 5.3 seal/unlock controls, typed API flow, in-memory
claim lifecycle, chat integration and deletion. Extend existing checks
where they leave behavioral gaps; do not generate redundant tests merely
to increase counts. This plan does not start the dependent 5.4 adversarial
stage or claim exhaustive coverage of all possible inputs.

The stage must prove real sealing, locked-chat exclusion, unlocked-chat
retrieval and automatic relocking after the real server-issued 15-minute
expiry. Local tests must verify exact boundaries and failure/race handling.
Owner gates remain open regardless of automated test results.

## Delegated local work

Three subagents have disjoint file ownership. Each reproduces failures
before a minimal fix, runs its targeted suite and reports the concrete
cases added. Root reviews their changes, runs combined analysis/full tests
and installs the final Android build. No commits or backend changes are
part of this task.

| Area / owner | Uncovered behavior to exercise | Layer |
|---|---|---|
| API agent | Empty input/content; refusal or connection failure at each stage; malformed salt/claim/content; expired claim before and during unseal; missing auth between calls | Generated client + crypto + controlled transport |
| API agent | Preserve known web KDF/key/claim wire format and multi-chunk ordinal/nonce behavior while exercising failures | Existing parity and transport regressions |
| UI agent | Ready/sealed/other status eligibility; empty input; duplicate button/keyboard submit; cancellation, retry, hidden input and clearing | Widget |
| UI agent | Seal success/refusal, navigation and account changes during seal; document change/disposal during unlock; stale responses and relock/re-unlock | Widget with shared session/providers |
| Session/chat agent | Multiple documents expire independently; lock one without losing another; expired results; sign-out/account reset; pending-operation invalidation | Provider |
| Session/chat agent | Timer/resume/disposal cleanup; deleted document cancels pending unlock; current chat callback excludes expired or forgotten claims | Provider + stream transport |

## Root-owned functional work

| Case | Required evidence | Initial state |
|---|---|---|
| F1: native production seal | Real POST seal; sealed detail/list | Passed again with fresh 60-chunk fixture; exact synthetic input verified |
| F2: locked chat | Fresh real turn excludes fixture and synthetic answer | Passed again on fresh fixture at 02:41:02 Dubai |
| F3: production unlock | Real salt → unlock → unseal; visible content and countdown | Passed again 02:41:34 Dubai; full 60-chunk content hash matches |
| F4: unlocked chat | Fresh turn retrieves fixture and synthetic answer using production claim payload, then completes | Passed on live build f462586: fresh native turn completed, answer/source matched; saved retrieval/citation and UUID IDs verified |
| F5: live local expiry | Wait actual 15 minutes; content/key disappear and UI allows re-unlock without restart | Passed 02:56:35 Dubai: fixture removed from production map, plaintext/countdown cleared, PID 4699 unchanged |
| F6: server expiry | Stale claim/key returns HTTP 401 / claim_expired | Passed again 02:56:38 Dubai: original claim/key returned 401/claim_expired after actual 15 minutes |
| F7: expired chat | Another fresh turn excludes fixture and answer without restart | Passed 02:56:46 Dubai: fresh completed native turn excludes fixture and unique answer, same PID |
| F8: cleanup | Delete test chats/fixtures; GET fixtures returns 404; restore normal app | Passed: disposable fixtures GET 404; test chats deleted; normal app restored with exit 0 |

The backend shares five/hour across seal/unlock/unseal. No limit was
bypassed or changed. Fresh-fixture seal/unlock/unseal have now passed;
the original stale claim was rejected after actual expiry.
HTTP 429 from earlier attempts is not counted as a functional pass.
Never manufacture a shortened server expiry.

The completion run used `scripts/sealed_expiry_check.dart` against disposable
multi-chunk fixture `db36893c-f24c-4d8e-a167-ed4e5b3240b6`, now deleted.
Create a new disposable fixture for future runs. The older fixture could
not authenticate the documented password and is not used for positive proof.
Follow the existing
[verification instructions](milestone-5.3-seal-unlock.md). The harness
must use production UI and providers and avoid recording credentials.

## Platform and scope limits

Real Android emulator/backend checks are available here. iOS real-device
execution is unavailable on this Windows host; an iOS CI compile is not
a substitute. Keep that coverage explicitly pending. The Android run
verified all 60 real-backend chunks against their original content hash. Phase 5.4 cross-user and
prompt-injection tests remain in their own milestone after 5.3 passes.

## Completion record

All three assigned local workstreams completed and were reviewed together:

| Owner | Added cases | Final targeted result / source |
|---|---:|---|
| API agent | 30 | 34 passed: `test/features/sealed/sealed_document_api_test.dart` |
| UI agent | 15 | 22 passed: `test/features/sealed/sealed_document_controls_test.dart` |
| Session/chat agent | 9 | 47 passed across `unlock_session_test.dart`, `chat_stream_client_test.dart`, `delete_document_test.dart` |

That is **54 additional regression cases** beyond the preceding audit.
The UI disposal case was also strengthened to assert the still-live shared
session is empty, rather than only checking that no exception occurred.
The account-switch reproduction found a late response accepted before a
lazy provider rebuild; the session now checks the account captured by
`build`. API checks found empty claim IDs accepted and already expired
claims consuming an unseal request; both are rejected before unseal.
See [findings and fixes](milestone-5.3-audit.md).

Combined verification: **751 passed, 30 gated skips** with `flutter test`;
`flutter analyze` and `git diff --check` are clean. Ignored logs:
`dev-logs/{api-coverage,ui-coverage,session-chat-coverage,m53-final-tests,m53-final-analyze}.log`.
Gated skips require credentials or separately configured functional tests;
they are not passes. No dependencies, backend changes or commits were added.

`flutter test --coverage` also passed (751/30). LCOV reports **200/201
executable lines** covered across the three new production files:
`sealed_document_api.dart` 46/47, `unlock_session.dart` 49/49 and
`sealed_document_controls.dart` 105/105. The uncovered line is the API
provider factory, exercised by the real-app harness. Line coverage does
not establish every branch, input combination or platform behavior.

## Earlier functional attempts

At the time of the local coverage run, F3–F7 still required real-device/backend
verification. The subsequent completion run below closes those Android cases;
local regression results alone do not pass either owner gate.

The original app PID was 6580. Read-only Dart VM `getInstances/getObject`
inspection proved the shared unlock map had one entry at 22:07:52 UTC.
No evaluation, method invocation, restart or state mutation was performed.
At 02:09:14 Dubai the emulator log recorded a window-system failure and
shutdown; exact cause remains unverified. Its exit prevents a same-process
post-expiry assertion. Ignored evidence: `dev-logs/m53-vm-memory-proof.log`
and `dev-logs/m52-emulator-resume.log`. A restart cannot substitute for F5/F7.

Final cleanup: both retained sealed fixtures were deleted and their GETs
returned 404; the unused duplicate was already 404. Test-chat cleanup
exited 0. The normal `lib/main.dart` Android build installed and ran with
exit 0 (new PID 3983); that restart is not counted as F5/F7 evidence.
Ignored logs: `dev-logs/m53-{fixture-cleanup,chat-cleanup,normal-restored}.log`.
That attempt required a backend persistence repair followed by successful
unlocked chat and uninterrupted real 15-minute expiry checks. Both were
completed in the subsequent run below.


The owner authorized finishing 5.3 and repairing the backend before 5.4.
PRs #92 and #93 in the web/backend repo repair real UUID persistence and
indexed-only graph reinforcement. The fresh same-process completion run
uses PID 4699 and expiry 2026-10-10T22:56:32.909578Z; its verified outcomes are reflected
in the table above. Earlier interrupted/failed attempts remain
historical evidence and are not retroactively counted as passes.


Final completion rerun: required Android F1-F8 cases now pass. The
post-deployment fresh native chat completed and saved its citation, and
the original full 15-minute expiry passed on unchanged PID 4699. The raw
harness aggregate remains incomplete because it preserves its earlier
failed unlocked turn; the scoped successful native retry/history assertion
separately closes F4. No failed attempt was relabeled. Fresh fixture and
test chats cleaned up; normal app restored with exit 0. See the
[completion record](milestone-5.3-seal-unlock.md).
