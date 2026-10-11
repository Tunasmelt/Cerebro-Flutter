# Milestone 6.1 — live Kanban board

The owner personally confirmed Phase 5's device checks on 2026-10-11.
Phase 4 remains open under the earlier owner-authorized exception. Phase 6's
owner gate remains open.

## Scope and API verification

Replace the mock board with the existing authenticated Kanban API: create
cards, reorder within a column, move between columns, persist float positions,
and optionally link a document through a tappable chip. These checks require
an installed Android app and the deployed FastAPI service; analysis alone is
not completion. Todo implementation remains Milestone 6.2.

Verified against `Tunasmelt/Cerebro-2.0` main at
`8415003bdd85fbf0185f90cf8dc6a578c6a91b69`, specifically
`services/api/app/routes/kanban.py`, `core/kanban_storage.py`, and
`apps/web/src/app/kanban/page.tsx`:

- List boards; choose the first returned board, creating `My Board` only if
  the account has none. Read columns from the server.
- Card creation sends `column_name`, `title`, `description`, and optional
  `document_id`. Moves PATCH `column_name` and floating-point `position`.
- Drop indices are calculated after removing the dragged card. Positions use
  the neighboring midpoint or a 1000-unit boundary offset. Duplicate or
  exhausted float gaps normalize the destination through existing card PATCHes.
- The generated update model serializes optional null fields; the backend's
  `exclude_none=True` ignores them. No generated-client edits are necessary.
- There is no board-delete endpoint. Tests preserve the existing board and
  remove only their uniquely named cards and disposable document.

The implementation uses the existing Chopper/Riverpod providers and Flutter's
native drag widgets. No package or backend changes are required. Successful
writes reread the server; failed writes attempt reconciliation before showing
an app error. Account changes discard cached boards and late responses. Card
menus provide move and delete controls, with deletion requiring confirmation.

## Test plan and coverage

| Layer | Cases |
| --- | --- |
| Transport | Auth header, existing/empty board, card creation with document, fractional PATCH, DELETE, 401/404/422/500, malformed list/detail responses |
| Controller | Same/cross-column order, empty/append destinations, duplicate positions, trimmed creation, invalid input, concurrent writes, failed write reconciliation, load retry, account change, sign-out |
| Widgets | Actual server columns, long-press same/cross-column moves, menu reorder, busy controls, stationary edge scrolling, drag cancellation, form validation, optional document, failed-save retry, duplicate submission, delete confirmation, account switch during draft, selected document removal |
| App routing | Existing navigation checks use an explicit Kanban fake instead of touching the network |

Native edge-scroll testing found that Flutter retains its earlier DragTarget
when content scrolls under a stationary pointer. A regression reproduced a
wrong-column move. Drop resolution now checks the final rendered target
geometry; cancellation never sends a move.

## Device evidence and reproduction

Android 16, `emulator-5554`, application `com.cerebro.cerebro_mobile`, real
signed-in owner session, deployed API `https://cerebro-api-d47y.onrender.com`.
No fake repositories or local board persistence are used in the device run.

Create a disposable synthetic document through the normal upload flow, then
run the observer harness with its ID and a unique public test prefix:

```powershell
flutter run -d emulator-5554 --no-resident -t scripts/kanban_board_check.dart `
  --dart-define=KANBAN_TEST_PREFIX=m61-test-<unique-run> `
  --dart-define=KANBAN_TEST_DOCUMENT_ID=<disposable-document-id>
```

1. Through the production form, create `<prefix>-A`, `-B`, and `-C` in the first
   column. Link A to the disposable document.
2. Long-press C and drop it before B. Move A into the last column. Exercise
   horizontal edge scrolling with a stationary pointer over a column header.
3. Wait for `MILESTONE_6_1_READY_FOR_RESTART_PASS`, then force-stop and relaunch
   the installed application. Confirm a different Android process ID and
   `MILESTONE_6_1_RESTART_SERVER_ORDER_AND_DOCUMENT_PASS`.
4. Inspect the real Board screen and open A's document chip. Delete only the
   three disposable cards and their document; restore the normal `lib/main.dart`
   build. Use a new prefix for another run: checkpoints are account- and
   prefix-scoped and contain only disposable card metadata.

The harness observes real production-controller results, issues an independent
fresh authenticated GET, and stores a comparison checkpoint outside production
state. On restart it fetches again and compares IDs, columns, positions, order,
and the document reference. It prints only fixed pass/incomplete markers.

Recorded initial run on 2026-10-11: all three cards were created through the UI;
C moved from position 5000 to 3500 before B at 4000. A moved through In Progress
into Done at 1000 and retained its synthetic document reference. Process 8146
saved the verified checkpoint; after force-stop, process 8438 fetched the same
backend state and emitted the restart pass marker. The final edge-scroll fix
also passed natively: with A returned to Backlog at 5000, a stationary finger
at the right edge scrolled the board and dropped A into the final visible Done
column at 1000. After force-stop, process 9106 independently fetched the saved
state and emitted the restart pass marker.

Validation: 40 Kanban transport/controller/widget tests pass; the full suite
passes 789 tests with 30 existing opt-in integration skips. Analysis has no
issues. Host/emulator interruptions caused timeouts during earlier attempts;
the uninterrupted rerun passed. Skips are not counted as device proof.
The normal application entrypoint was rebuilt after verification. Its linked
chip opened the real synthetic document detail screen with Ready status:
[Android document-link proof](screenshots/milestone-6.1-linked-document.png).
All three disposable cards and their uploaded document were deleted. The
existing owner board and its seven original cards were preserved; the normal
app was relaunched to refresh its caches.

Windows cannot provide an iOS device run. That remains pending and is not
claimed by Android evidence or a build. The Phase 6 owner gate is not passed.


## Owner confirmation — 2026-10-11

The owner subsequently confirmed all implemented phase gates as verified.
Phase 6’s owner gate is closed; earlier pending-gate notes in this record
describe the status at implementation time. Agent-run iOS verification
was not performed in this Windows environment.
