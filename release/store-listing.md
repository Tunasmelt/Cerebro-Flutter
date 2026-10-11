# Cerebro store listing preparation

Status: draft assets and metadata; no store submission or public release.

## Shared listing copy

**App name:** Cerebro

**Short description:** Keep your documents, ask questions, and connect your knowledge.

**Description:**

Bring PDFs, images, text, and Markdown into your personal knowledge library.
View original files inside the app. Ask questions about your documents and
follow citations to their sources. Explore your knowledge graph and see the
memories retrieved for a conversation. Organize work with boards and tasks.

Seal documents behind a passphrase when you want additional access control.
During an active unlock session, the derived key is sent to the service per
request; sealing is not zero-knowledge encryption. A Cerebro account and an
internet connection are required for backend features.

**Suggested categories:** Productivity (Google Play), Productivity (App Store).

## Assets

- `store-assets/icon-512.png`: Play listing icon, 512 × 512.
- `store-assets/icon-1024.png`: App Store icon, 1024 × 1024.
- `store-assets/feature-graphic.png`: Play feature graphic, 1024 × 500.
- `store-assets/cerebro-source.svg`: copied web brand source, retained for review.
- Native Android launcher/splash and iOS icon/launch assets use the same mark.
- Generate bitmap assets with `flutter test tool/generate_platform_assets.dart`.

## Permissions and platform behavior

Android uses the system camera intent and document/photo pickers. It requests
no app camera runtime permission and no broad storage access; this existing
behavior is protected by `platform_config_test.dart`. Camera cancellation must
return safely to the app. Android supplies the camera app's own permission UI
when applicable; it cannot show an iOS-style app usage-description string.

On iOS, Info.plist explains that camera and photo access happen only when the
user chooses to add a document. Confirm the actual configured strings on a
fresh physical iOS install before release.

## Publication requirements still outstanding

- Fresh physical Android/iOS icon, cold-start splash, and camera-flow checks.
- Honest feature screenshots from a disposable account, without owner content.
- Public privacy-policy/support links and account-deletion instructions,
  verified against actual deployed behavior; no URL or feature is invented here.
- Store-console data-safety/privacy disclosures based on backend processing and
  the SDKs actually shipped, plus content rating and owner-approved contact data.
- Release signing: Android currently uses the existing debug signing configuration;
  this is not a store-ready signed artifact. iOS build/signing needs a Mac.
- Milestone 7.3's second-model Android and iOS functional regression matrix.
- Phase 7 owner gate is closed by explicit owner direction on 2026-10-12;
  outstanding hardware checks remain unverified.
