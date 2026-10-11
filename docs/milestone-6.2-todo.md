# Milestone 6.2 — live Todo list

Tasks must create and complete through the real API, appear in a collapsible
Completed section, and retain their completed state after an app restart.
The mixed-list grouping test is required, but does not replace device proof.
Phase 6's owner gate remains open; iOS device verification is unavailable on
this Windows host.

## API and implementation

Verified against `Tunasmelt/Cerebro-2.0` main
`8415003bdd85fbf0185f90cf8dc6a578c6a91b69`:
`services/api/app/routes/todos.py`, `core/todo_storage.py`, and
`apps/web/src/app/tasks/page.tsx`.

- Tasks are account-owned, flat, and ordered newest first by the server. They
  have low/medium/high priority; there is no due-date API. The old mock
  Today/Upcoming groups have been replaced with Active and Completed.
- GET `/api/v1/todos` returns `{todos: [...]}`. POST creates a task; PATCH and
  DELETE address `/api/v1/todos/{id}`. Existing generated-client authentication
  and error mapping are reused.
- Creation explicitly sends medium priority by default. The generated nullable
  field would otherwise send `null`, which the backend rejects. PATCH's optional
  null fields are ignored by the backend's `exclude_none=True` behavior.
- The server sets or clears `completed_at`. The client sends only the completion
  boolean and rereads the server after successful mutations. Failed mutations
  attempt reconciliation and retain a safe error, with retry available.
- Active and completed tasks share the priority filter. Completed starts
  collapsed and supports reopening tasks. Editing and confirmed deletion match
  web behavior; optional existing document references open the document detail.
- Writes are serialized, controls disable while busy, and account changes clear
  state and discard late responses. An old account's editor closes without saving.

No new dependencies, generated-client edits, or backend changes are required.

## Automated coverage

31 Todo transport/controller/widget checks cover authentication and wire shape,
server timestamps, malformed responses, 401/404/422/429/500 errors, mixed-list
grouping and ordering, creation/edit/deletion, completion/reopening, validation,
duplicate writes, failure reconciliation, load retry, account changes, sign-out,
collapsed completed tasks, priority filtering, failed drafts, and confirmation.
Existing shell and Board navigation tests use an explicit Todo fake.

## Android reproduction

Use the signed-in owner session on `emulator-5554` and the deployed API
`https://cerebro-api-d47y.onrender.com`. The observer uses the production UI,
controller, and API, with no fake data or local production-state persistence.

```powershell
flutter run -d emulator-5554 --no-resident -t scripts/todo_persistence_check.dart `
  --dart-define=TODO_TEST_TITLE=m62-test-<unique-run>
```

1. Switch to Todo and create the uniquely named task through Add task.
2. Complete its checkbox. Confirm it disappears from Active and the Completed
   section stays collapsed. Expand and collapse that section to inspect it.
3. Wait for `MILESTONE_6_2_READY_FOR_RESTART_PASS`; force-stop and relaunch the
   installed application. Confirm a different Android process ID and
   `MILESTONE_6_2_RESTART_COMPLETION_PASS`.
4. Switch to Todo again: Completed starts collapsed. Expand it and confirm the
   completed checkbox and task title. Delete only the disposable task, then
   rebuild and relaunch the normal `lib/main.dart` application.

The harness independently fetches the task and compares its ID, title,
completion boolean, server timestamp, and priority across restart. Its
account-scoped checkpoint contains only disposable metadata. It prints fixed
pass/incomplete markers, never credentials or private task content. Use a new
title for each run.

Recorded on 2026-10-11, Android 16, `com.cerebro.cerebro_mobile`: task
`m62-test-1791732347796` was created through the production form, edited through
its action menu, and completed through its checkbox. The server assigned
`completed_at` of `2026-10-11T15:39:38.684506Z`. Process 10323 emitted the ready
marker; after force-stop, process 10946 independently fetched the same ID,
priority, completion boolean, and timestamp and emitted the restart pass.
The reopened Todo screen started with Completed collapsed; expanding displayed
the checked, struck-through task. Initial ADB/runtime stalls were resolved by
relaunching, and dropped native text-input characters were repaired through
Edit before the checkpoint. Those interrupted attempts are not counted as passes.

Validation: 31 Todo checks and 819 full-suite tests pass, with 30 existing
opt-in integration skips. The final UI adjustments pass all seven Todo widget
tests, and analysis has no issues. No skipped test counts as device evidence.


The disposable task was deleted through its exact ID, and a fresh backend GET
confirmed it was absent. The normal `lib/main.dart` Android build was rebuilt,
installed, and relaunched after verification. Existing owner data was preserved.
Phase 6's owner gate remains open, and iOS device checks remain pending.


## Owner confirmation — 2026-10-11

The owner subsequently confirmed all implemented phase gates as verified.
Phase 6’s owner gate is closed; earlier pending-gate notes in this record
describe the status at implementation time. Agent-run iOS verification
was not performed in this Windows environment.
