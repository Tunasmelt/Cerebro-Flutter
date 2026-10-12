# UI/UX Phase C — Chat and direct document previews

2026-10-12. Phase B merged through PR #39 before this work began.

Exit criteria: readable streamed Markdown with trusted citations, accessible
copy/composer controls, scrolling that respects reading older messages, and
grouped history with safe deletion undo. The owner also requested that tapping
a document open its preview directly. Verify the real Android build against the
deployed backend; widget tests alone do not establish device behavior.

## Implementation

- Shared Markdown rendering supports headings, lists, tables and fenced code
  with copy controls. Citation validation still requires retrieval evidence and
  server-provided cited documents. Collision-free placeholders cannot be forged
  by source text; code and copied answers contain plain numbered references.
- Remote Markdown images render their labels without fetching tracking URLs.
  HTTP(S) links copy to the clipboard. Original uploaded images render normally.
- Bounded bubbles, typing dots, reduced-motion support, animated tail following,
  a Latest button, document-derived suggestions, multiline input and send haptics.
- History groups Today/Yesterday/Earlier. Swipe deletion waits five seconds for
  Undo, survives leaving the screen, cancels on account change and restores rows
  on server failure. Explicit menu deletion retains its confirmation.
- Document rows, chat citations and Graph links open `/documents/:id`; details
  are available at `/documents/:id/details` through the preview info action.
  PDF, images, text and Markdown preview inside the app. Captures without original
  storage bytes fall back to owner-scoped extracted text. Unsupported originals
  offer an explicit external-app action. Sealed originals remain blocked.

## Dependency review

[flutter_markdown_plus](https://pub.dev/packages/flutter_markdown_plus) 1.0.12
was published three months before review, maintained by ForesightMobile,
supports Android/iOS and uses BSD-3-Clause. It supports custom inline builders
without inline HTML. Existing markdown 7.3.1 is now a direct dependency. No new
backend endpoint or external-link launcher was introduced.

## Verification

- Final local checks: 958 tests passing with 30 existing opt-in skips; normal
  Android debug APK built successfully from lib/main.dart.
- Regression suite covers repeated trusted citations, malformed/raw markers,
  copying, long code/tables, history undo/failure/account changes, scrolling,
  direct preview/details/back routing, extracted text and unsupported formats.
- Pixel Maestro checks passed direct PNG preview/details/return, PDF page
  navigation/return and captured-text fallback against the deployed backend.
- Android emulator diagnostic passed live Markdown/citations at 02:46:13,
  saved response at 02:46:17 and export at 02:46:17 on 2026-10-12. The exact
  diagnostic-created conversation was deleted and its absence verified at
  02:47:05. A local screenshot confirmed rendered code and citation controls.
- An earlier diagnostic assumed a non-null conversation timestamp. The normal
  export uses the first message timestamp as fallback; the diagnostic now does
  the same. Its fixture was also removed successfully.
- The diagnostic additionally checks native clipboard and source opening.
  Those additions have not run on a connected device yet. Devices disconnected
  before the final pass; no new physical or iOS verification is claimed.

Run `flutter analyze`, `flutter test` and `flutter build apk --debug` for local
checks. `scripts/ui_c_chat_check.dart` is an optional live entrypoint requiring
a signed-in test device with architecture-and-security.md available. It creates
and deletes only its own conversation. Restore the normal lib/main.dart build
afterward. Local logs/screenshots stay under ignored dev-logs.

Phase C is prepared for review; this document does not close an owner gate.
