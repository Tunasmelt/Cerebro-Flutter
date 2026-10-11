# Milestone 7.1 — Platform handling

Status: Android physical checks passed, 2026-10-12; iOS pending. Phase 6 and owner confirmation merged in
[PR #36](https://github.com/Tunasmelt/Cerebro-Flutter/pull/36). Mobile implementation and verification are recorded in the Phase 7 commits. The backend renewal change is
published in `Tunasmelt/Cerebro-2.0` PR #95. Deployed emulator recovery passed.
Milestone 7.2 Android physical checks passed; iOS checks and 7.3 remain pending.

## Exit criteria

Controls must remain accessible on a physical notched device, retrieval
pulses must produce physical haptics, and Android uploads must survive
background suspension and recover after process death without starting a
new document. Compilation and widget tests alone cannot prove these exits.
The Pixel 9 Pro XL was connected for the first checks but disconnected before
physical process-death verification. No Mac or iPhone is available.

## Implementation

- Graph's node panel uses `SafeArea(top: false)` for side and bottom insets.
- Documents refreshes the authenticated server list and restarts ingest
  polling on resume; it disposes its lifecycle listener and suppresses
  concurrent refreshes.
- A SocketException carried by an unknown Dio error becomes a safe network
  error. Storage retries once after a background interruption and foreground
  return, using the original document authorization and a fresh session token.
  Foreground, authorization, size, and server failures are not automatically
  retried. Session changes cancel pending retries and prevent old-owner PUTs.
- The normal app configures an owner-scoped upload store. Selected bytes are
  streamed into private application cache before upload-init; an atomic
  metadata checkpoint records filename, MIME, byte count and document ID.
  Bearer tokens, signed URLs, sealed keys and unlock claims are never stored.
  Successful uploads and explicitly dismissed failures remove their copies;
  signing out or switching accounts clears the former owner's queue.
- Startup recovery checks the server's ingest state. Active or finished ingest
  is retained without reconfirming. If Storage already accepted the bytes,
  recovery only confirms. Otherwise it renews authorization for the same
  document, PUTs the cached file, then confirms. A failure retains the queue
  and shows a failed row; reopening retries recovery.
- The prepared backend `POST /api/v1/documents/{id}/upload-resume` creates no
  rows. It accepts owned uploading jobs or upload-expired failures, rejects
  sealed/completed/other-owner documents, and renews the one-hour upload
  activity window. Supabase bucket limits and RLS still enforce the upload.
  Confirmation now claims the ingest transition once and does not reset an
  already running or finished job when a response is lost.

Private cache survives process death but can be removed by the OS or app-data
clearing. Recovery cannot recreate bytes after that removal. Killing during
upload-init before its document-ID checkpoint is a separate response-loss
window: cached bytes survive, but the current API cannot identify the row
created by a lost init response. Recovery can create a new row in that window;
the backend expires the original abandoned row. No byte-range resume is
claimed: an interrupted PUT retransmits the cached file for the same document.

## Real-device evidence

Pixel 9 Pro XL (`49041FDAS0015H`, Android API 37):

- Maestro inspected the real Graph controls and expanded a node. Search and
  refresh were below the cutout; node-panel actions and navigation were above
  the home indicator. Panel Collapse, Chat about this and Open in Documents
  assertions passed.
- Native vibrator records show completed Cerebro light-impact events at
  21:54:56 and 21:54:58. The owner confirmed feeling the retrieval vibrations.
  Touch haptics were enabled at the owner's request.
- At 21:52:16 process 24883 began the real Storage PUT. Home backgrounded it
  at 21:52:17; the socket failed at 21:52:22. The same process resumed and
  reopened the stream at 21:52:44, confirmed at 21:53:01, reached Ready at
  21:53:19, and deleted the fixture at 21:53:25. This proves suspension
  recovery against the deployed backend, not process-death recovery.
- The prior diagnostic fixture was deleted by its exact synthetic filename.
  Existing owner documents were not changed.

Android emulator 5554, prepared local FastAPI service with real Supabase:

- Process 7848 started a real upload at 22:17:41 and was backgrounded. `am kill`
  did not terminate the previous activity process; this was explicitly checked.
  An app-UID SIGKILL then removed that process while recovery was pending.
- New process 8009 loaded the saved fixture at 22:18:32, renewed the same
  document at 22:18:36 without another upload-init, streamed the cache, confirmed
  at 22:18:54, reached Ready at 22:19:03, and deleted the fixture at 22:19:05.
  This is real process-death and backend evidence on an emulator, not proof of
  physical Android power-management behavior or deployed endpoint availability.

`maestro/platform_navigation.yaml` passed its 20-command, read-only flow on
both Pixel and emulator with the normal app build and existing signed-in
session. It checks Documents, Graph/replay picker, Board, Play and Settings.
It never clears application state or writes owner data. Native screenshots
and private diagnostics stay in ignored local logs, not in the repository.

## Running the diagnostic

Build `scripts/platform_background_check.dart`. Normal runs use the deployed
API. For the prepared local endpoint, run FastAPI on localhost port 8766,
configure `adb -s DEVICE reverse tcp:8766 tcp:8766`, and build with
`--dart-define=PLATFORM_VERIFICATION_API=http://127.0.0.1:8766`.

The harness caches its 645-byte synthetic file through production code, then
paces the actual PUT over 15 seconds. Background at `STREAM_STARTED`. For
process-death checks, verify the old PID disappeared before reopening. A saved
diagnostic fixture makes the next launch recover it instead of creating a new
one. Require `SAME_DOCUMENT_RENEWAL_PASS`, `PROCESS_DEATH_RECOVERY_PASS`, and
`FIXTURE_CLEANUP_PASS`. Restore a normal `lib/main.dart` build afterward and
remove the temporary ADB reverse. Exact prior fixtures can be cleaned with
`PLATFORM_CLEANUP_FILENAME`; prefix-based deletion is prohibited.

## Validation

Final Flutter suite: 873 passed, 30 existing opt-in skips; analysis clean.
Android debug builds pass. Backend: 572 tests and lint pass; production web
lint and build pass. The new store uses the existing `path_provider` 2.1.6;
[pub.dev](https://pub.dev/packages/path_provider) confirms maintained Flutter
publisher support for Android/iOS and the BSD-3-Clause license. No new
Flutter or backend dependency was introduced. Code generation uses the bundled
Flutter Dart SDK with `build_runner build --force-jit`: native build hooks
prevent the runner's default AOT compilation in this workspace.

## Remaining

- Backend publication and deployed emulator recovery are complete (PR #95).
- Physical Pixel process-death recovery passed against the deployed endpoint (see below).
- iOS live verification remains unavailable; CI compilation is not device proof.
- Complete milestones 7.2 and 7.3 before requesting Phase 7 owner confirmation.
  No phase gate has been marked passed by the agent.

## Deployed recovery update — 2026-10-12

Owner approved publication; Cerebro-2.0 PR #95 merged as `9edf71a` with
572 backend tests and API/web CI passing. The publication also serializes
expiry/renewal/confirmation under the enforced single-process deployment.

Emulator process 10135 started a real deployed Storage PUT at 00:07:37.
An app-UID SIGKILL removed that PID; absence was checked before reopening.
Process 10308 restored the saved fixture at 00:07:42, renewed the same
document through the deployed endpoint at 00:07:49, confirmed at 00:08:09,
observed Ready at 00:08:23, and deleted its own fixture at 00:08:28. No
second upload-init occurred in the recovered process. This passes the full
process-death diagnostic against the deployed service and real Supabase.

Two earlier deployed attempts completed Storage upload and confirmation but
hit the original 80-second diagnostic ingest deadline and cleaned up without
passing. The harness now allows the same ten-minute polling window as the app;
only the later observed-Ready run is counted as passed.

The earlier physical Pixel background, safe-area and owner-confirmed haptic
checks, plus this deployed emulator process-death run, support advancing to
7.2. The Pixel disconnected again before a physical process-death repeat;
that additional hardware check remains pending. This does not close the
Phase 7 owner gate or establish iOS/second-model matrix coverage.

The separate original-file viewer adds pdfx and is documented in
`docs/in-app-file-viewer.md`; the upload store itself adds no dependency.

## Physical deployed recovery — 2026-10-12

Pixel 9 Pro XL, Android API 37: process 22763 began the synthetic upload at
00:36:21. The app was backgrounded and killed with its own UID; PID absence
was verified before relaunch. New process 22963 loaded the saved fixture at
00:36:24, renewed the same document at 00:36:29 without another upload-init,
confirmed at 00:36:47, passed the Ready check at 00:37:09, and verified fixture
deletion at 00:37:15. This used the deployed API and real Supabase Storage.
The normal build was restored, preserving the signed-in owner session.
