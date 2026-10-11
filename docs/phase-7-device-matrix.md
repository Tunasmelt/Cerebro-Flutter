# Phase 7 device regression matrix

Updated 2026-10-12. Milestone 7.3 is pending; no Phase 7 owner sign-off.

Its exit test requires re-running Phases 1–6 live checks against the deployed
backend on an additional physical model per platform. Unit/widget tests and
emulators support regression work but cannot satisfy this hardware requirement.

| Check | Existing Android evidence | Additional Android model | iOS models |
| --- | --- | --- | --- |
| Auth, confirmation, session/account changes | Prior phase records | Pending | Pending |
| Files/camera uploads, ingest, retries, deletion | Prior records; Pixel background recovery | Pending | Pending |
| Chat stream, citations, history and export | Prior phase records | Pending | Pending |
| Graph, live retrieval and saved replay | Pixel safe areas and owner-felt haptics | Pending | Pending |
| Sealing, unlock/expiry and cross-user isolation | Prior Phase 5 records and owner confirmation | Pending | Pending |
| Kanban, todo, read-only playground | Prior Phase 6 records and owner confirmation | Pending | Pending |
| Original image/PDF/text viewer | Android emulator and physical Pixel live checks | Pending | Pending |
| Process-death recovery | Deployed emulator and Pixel same-document recovery | Pending additional model | Pending |

Pixel 9 Pro XL and emulator-5554 are currently connected;
no Mac/iPhone is available according to the owner. Record model, OS, build,
backend environment, actual result and cleanup for each future device run.
The owner must personally confirm the required end-to-end sessions before
closing the Phase 7 gate.

## Owner gate update — 2026-10-12

The owner instructed “close all gates”. Phase 7’s owner gate is closed by
that explicit direction. Outstanding iOS and additional-device checks remain
unverified; historical open-gate statements above describe the earlier status.
