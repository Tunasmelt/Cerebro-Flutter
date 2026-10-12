# UI backlog — owner-reported issues

Found by the owner on a real device (Pixel 9 Pro XL, debug build, 2026-10-12)
while reviewing UI/UX Phase D. Open until moved to CHANGELOG as fixed.

## 1. Documents list scrolls with a little lag
- **Seen:** scrolling the Documents list up and down feels slightly laggy on
  the device (debug build; a release/profile build may differ).
- **To do:** reproduce on a profile build first (debug builds are slower than
  release). Then look at per-row cost: each row builds three decorated
  containers and a `StatusPill` with `Semantics(excludeSemantics)`; the list is
  a plain `ListView.separated` (lazy, so row count is not the issue). Check for
  rebuilds of the whole list on every keystroke in the search box
  (`setState` in the screen) and on ingest polling.
- **Done when:** a profile-build trace of a fast fling shows no dropped frames
  with the owner's 22 documents, and with a 300-row fixture.

## 2. Documents: filters and search take too much room
- **Seen:** the search box and five chips occupy the upper part of the screen
  before any document appears.
- **Wanted by the owner:**
  - Only two filters: **Sealed** and **Ready** (drop All / Processing /
    Failed as chips; a second tap on the selected chip returns to all). Note:
    this removes the only way to find Failed or Incomplete documents from the
    list — decide where those surface (e.g. a badge on the row is already
    there) before removing.
  - Search becomes an **icon** in the header that opens the search bar on
    demand (and closes it again), instead of a permanent box.
- **Touches:** `documents_screen.dart` (`_SearchAndFilters`),
  `document_presentation.dart` (`DocumentFilter`, `filterDocuments`), and the
  tests in `documents_filter_test.dart` (the chip set and the "Failed includes
  abandoned" rule would change).

## 3. App-wide font: use a better one
- **Seen:** the owner finds the current typography unattractive overall.
- **Currently:** DM Sans (UI), Outfit (headings), JetBrains Mono (numbers and
  labels) — `lib/shared/tokens/app_typography.dart`, mirrored from the web
  tokens.
- **Conflict to settle first:** the UI/UX direction chosen on 2026-10-12 was
  "modernize within the tokens" — keep the web palette, fonts and radii. A new
  font is a deliberate departure from the web source of truth, so the owner
  should confirm it is app-only (web unchanged) before it is applied.
- **To do:** pick candidates (try them on-device in the real screens, not on a
  specimen page), check they ship all weights used (400/500/600/700) and cover
  the characters the app shows, bundle them as assets (no runtime network
  fetch), update `AppTypography`, re-run the contrast and text-scale tests.
