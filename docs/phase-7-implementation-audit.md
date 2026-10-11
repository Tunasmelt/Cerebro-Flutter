# Phase 7 implementation and test audit

Audited 2026-10-11; updated 2026-10-12. Phase 7 is incomplete; no owner gate has been passed.

## Findings and repairs

- **Fixed — damaged saved-upload metadata blocked the entire recovery queue.** `pending_upload_store.dart` now isolates JSON/schema failures per record. The damaged record becomes a failed, dismissible row; intact records still recover. Three regressions exercise invalid JSON, invalid field types, and a missing journal, successful independent recovery, and actual on-disk dismissal.
- **Fixed — renewal/confirmation could overwrite a different failure.** Prepared backend transitions from `failed` now condition on `last_error=upload_expired` as well as state. Renewal coverage checks the actual outgoing predicate.
- **Fixed — expiry selection could become stale before mutation.** The prepared backend sweep now requests affected job rows and updates only those document IDs. An empty conditional update or upstream failure leaves documents untouched. Two regressions cover these cases; the existing sweep transport now implements the requested representation response.
- **Fixed — expiry/renewal/confirmation interleaving:** a shared lock serializes these operations under the backend’s enforced one-process/one-instance deployment. A concurrent regression proves requests from separate storage instances wait. This is not a database transaction: upstream failures/crashes can interrupt writes, and horizontal scaling requires shared transactional coordination. Published in Cerebro-2.0 PR #95 (merge `9edf71a`).

## Exit criteria review

| Requirement | Evidence / status |
| --- | --- |
| 7.1 safe areas | Pixel graph controls inspected; graph inset regression and navigation smoke pass. No iOS hardware evidence. |
| 7.1 retrieval haptics | Physical Pixel vibrator evidence and owner confirmation recorded. |
| 7.1 background upload | Physical Pixel completed after suspension against deployed backend. |
| 7.1 process-death recovery | Emulator recovered the same document against prepared local FastAPI and real Supabase. Deployed endpoint renewal and full recovery also passed on emulator on 2026-10-12. Physical Pixel same-document recovery and fixture cleanup passed on 2026-10-12. |
| 7.2 icons, splash, listing | Implemented native branding and listing assets; isolated fresh-install emulator splash/login checks passed; camera launch/cancel passed. Physical Android branding/camera checks passed; iOS verification remains pending. |
| 7.3 second-device matrix | Not started. Pixel and emulator connected for the follow-up; owner previously reported no Mac/iPhone. |
| Phase 7 owner gate | Open; requires completed milestones and owner end-to-end verification on the required devices. |

## Validation

- Full Flutter suite with viewer/recovery regressions: **873 passing**, **30 existing opt-in skips**; analysis clean.
- Focused backend upload/sweep suites: **28 passing**.
- Full backend suite: **572 passing**; existing Python/pytest deprecation warnings remain.
- Final normal Android build, PDF page counter/swipe/exit and 20-command emulator navigation smoke passed; physical Pixel recovery, branding, camera, PDF/image viewer and navigation checks also passed.
- Backend publication was separately approved, then committed, pushed and merged as PR #95 after CI passed. Viewer adds pdfx 2.11.0 (Android/iOS, MIT); no branding dependency added. No Phase 7 owner gate closure.

## Other recovery limits

Application cache can be evicted. A kill after upload-init creates its row but before the document ID is checkpointed can leave an expired orphan row; recovery is not idempotent upload initialization. Recovery resends the full file rather than resuming at a byte offset. Missing metadata directories now appear as dismissible failed rows. These limits must not be described as guaranteed lossless recovery.

## Viewer availability

Captured thoughts have no original Storage file. The current document-detail API
does not expose source/file availability, so the viewer reports the backend
not_available response for these items. Original viewing applies to uploaded
files; sealed originals remain unavailable under the existing server contract.

## Owner gate update — 2026-10-12

The owner instructed “close all gates”. Phase 7’s owner gate is closed by
that explicit direction. Outstanding iOS and additional-device checks remain
unverified; historical open-gate statements above describe the earlier status.
