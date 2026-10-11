# UI/UX Phase B — Navigation shell

2026-10-12. Phase A merged into main through PR #38 before this work started.

Exit criteria: five persistent tabs, Token Inspector as a Settings child route,
stable accessible bottom navigation, and a scrollable rail at widths >=600px.
Verify tab/back navigation, authentication guards and Graph replay on Android
with the deployed backend. No new package or backend change is required.

## Implementation

- Docs, Chat, Graph, Board and Settings are the five shell branches.
- `/settings/token-inspector` hosts the existing read-only Playground screen;
  its Settings entry pushes through go_router. Back returns to Settings, and
  switching tabs preserves its stack. `/playground` redirects for compatibility.
- Fixed-size outlined icons, a token-timed animated selection surface, labels
  of at least 12px, and a full-item semantic tap target replace the shifting bar.
  Selection haptics fire only when changing tabs. Reduced motion disables the
  bottom indicator animation. Two-line label space supports 320px/1.3x text.
- A native scrollable NavigationRail replaces the bottom bar at >=600px.
- Removed the orphan sealed wireframe's decorative bottom navigation; the
  live sealed controls are unchanged. Fixed the Settings storage separator.

## Verification

- Full Flutter suite: 946 passing, 30 existing opt-in skips.
- Analysis of lib/test clean; Android debug build passes.
- Regressions cover semantic selection/actions, 44px targets, stable geometry,
  text scaling/reduced motion, short rail height, exact 599/600 breakpoint,
  resizing/tab-stack preservation, old-link redirect/back, single selection
  haptic and existing Graph replay/authentication navigation.
- Physical Pixel: revised 22-command Maestro navigation flow passes against
  the deployed service, including Graph replay picker, Board, Settings and
  Token Inspector/back. Existing session/data preserved.
- Wide emulator: rail visually inspected at 1600x1000/240dpi; manual rail
  selection opens Settings and its inspector child. Maestro returned an empty
  accessibility hierarchy after the display override, so the wide flow is not
  claimed as an automated pass. Original 1080x1920/420dpi restored afterward.
- No iOS device proof is added. Existing Phase 7 owner acceptance remains as
  recorded; this UI phase does not manufacture a new owner gate confirmation.

Next: Phase C's Markdown/citation/chat work, after reviewing Phase B's PR.

## Pressed-overlay follow-up

A reported pale box covered the tab section on press. The bottom InkWell now
uses NoSplash and a transparent pointer overlay; only keyboard focus receives
an explicit token-colored highlight. A pressed-state raster check verifies the
surrounding pixels stay dark. The Pixel held-press screenshot and repeated
22-command navigation smoke pass. No owner data or session was cleared.
