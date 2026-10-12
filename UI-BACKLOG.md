# UI backlog — owner-reported issues

Status 2026-10-12: items 2 and 3 fixed, item 1 not reproduced (see each);
new findings in section "Found while fixing".

Found by the owner on a real device (Pixel 9 Pro XL, debug build, 2026-10-12)
while reviewing UI/UX Phase D. Open until moved to CHANGELOG as fixed.

## 1. Documents list scrolls with a little lag — NOT REPRODUCED, needs owner check
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

## 2. Documents: filters and search take too much room — FIXED
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

## 3. App-wide font: use a better one — FIXED
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

**Status:** measured, not fixed. `integration_test/documents_scroll_perf_test.dart`
flings a 300-row list on a device in profile mode and prints build/raster
times. On the emulator (software GPU): build is cheap (avg 1.3-2.6 ms, p95
about 3-7 ms) and raster swings between identical runs (3 to 108 frames over
16.7 ms out of ~540), with the old font and the new one alike. So row building
is not the cost, and the emulator cannot show the rest. The owner saw it on a
**debug** build, which is much slower than release. **Owner to re-check on a
profile/release build on the phone**; run the perf test on the phone too:
`flutter drive --driver=test_driver/integration_test.dart --target=integration_test/documents_scroll_perf_test.dart --profile -d <phone>`.

## Found while fixing
- **Expired session does not send the user to Sign in.** On the emulator the
  stored session had expired; the app stayed on its tabs showing "Your session
  has expired. Sign in again." with a Retry button instead of routing to the
  sign-in screen. Signing out manually (Settings) worked. Probably the auth
  redirect only reacts to sign-out, not to a refresh failure.
- Numbers and labels still use JetBrains Mono (the font change covers UI and
  headings). If the owner wants that changed too, it is one constant.

## Refinements spotted on the emulator walk (Graph is phase F)
Status: the Graph items below (double border, legend over nodes, lowercase
labels, crowded note) were fixed in F1.
- **Graph:** the search field shows a double border (a rounded field inside a
  rounded container); the type legend sits on top of nodes; "history" and
  "dismiss" are lowercase and look like body text; the grey "Groups are not
  computed yet..." line crowds the search bar. All belong to Phase F1.
- **Documents:** the "+" button covers the status pill of the row beneath it
  when scrolled; a little more bottom padding or a smaller/extended button
  would stop that.
- **Settings:** not re-checked in this walk; Phase E3.
