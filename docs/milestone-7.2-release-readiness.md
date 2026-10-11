# Milestone 7.2 — Release readiness

Updated 2026-10-12. Implementation is prepared; Android physical-device checks passed;
iOS build/prompt verification remains pending. Phase 7's owner gate is open.

The exit criteria require native icons and splash matching the existing web
design, store artwork/metadata, and honest camera/storage behavior verified
after a fresh install. Android uses the system camera intent and system file
pickers without requesting app CAMERA or broad storage permission. Consequently
there is no app-specific Android camera permission description to assert.
iOS's configured camera/photo usage descriptions still require an actual iOS
build and fresh permission prompt; Windows cannot provide that evidence.

## Implemented

- Android adaptive and legacy launcher icons, dark splash including Android 12+,
  and Cerebro application label.
- iOS icon sizes, launch artwork/background and Cerebro display name.
- Existing web icon geometry and colors, exported with the checked-in
  `tool/generate_platform_assets.dart`; no branding dependency added.
- Opaque RGB store icons, feature graphic and draft listing in
  [release/store-listing.md](../release/store-listing.md).
- Optional Gradle `verificationApplicationId` for a separate fresh-install
  package that preserves the normal app's owner session and private storage.

## Actual Android evidence

On emulator-5554, an isolated `com.cerebro.cerebro_mobile.releasecheck` install
showed the native dark splash with the teal/purple mark. The cold-start screenshot
was visually inspected; Cerebro, Email and Password assertions passed.
The normal app invoked `com.android.camera2/com.android.camera.CaptureActivity`
through Take a photo, then returned to Documents on cancel. No photo was uploaded.
PDF page 1/page 2 counter, swipe and exit assertions passed in the normal build.
The existing navigation smoke passed again. No owner data was cleared.

Full Flutter suite: 873 passing, 30 existing opt-in skips. Analysis clean.
Android debug build passes. The test package is not a production release.

## Remaining release evidence

Mac/iOS build and fresh
permission checks; feature screenshots with disposable data; verified privacy
and support URLs; store-console declarations and production signing. No store
publication was performed. Milestone 7.3's device matrix remains separate.

## Physical Android follow-up — 2026-10-12

Pixel 9 Pro XL API 37: installed the isolated verification package with empty
private storage. Its cold-start splash was captured and visually matched the
brand; Cerebro/Email/Password assertions passed. The verification package was
removed afterward. The normal launcher icon and label were visually verified.
The normal authenticated app opened GoogleCamera CaptureActivity and returned
to Documents on cancellation. PDF page 1/page 2, swipe and both back navigation
steps passed; documents.png rendered correctly. The 20-command navigation smoke
passed. No owner session or existing document was deleted. Screenshots/logs
remain in ignored local dev-logs rather than public store assets.

## Owner gate update — 2026-10-12

The owner instructed “close all gates”. Phase 7’s owner gate is closed by
that explicit direction. Outstanding iOS and additional-device checks remain
unverified; historical open-gate statements above describe the earlier status.
