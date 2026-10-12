# UI/UX F2 — Graph interactions

F1 PR #47 merged into main on 2026-10-12 before this branch began.

Exit criteria: draggable node details with snap points, selected-node placement
using the current sheet extent and zoom, empty-canvas collapse, double-tap zoom,
search-result cycling and a shared multiline question field. Verify the Android
build with real graph/chunk responses and retain existing chat/send regressions.

Implemented on ui/f2-graph-interactions:

- Native DraggableScrollableSheet snaps at 25%, 45% and 80%. A lazy chunk list
  scrolls with the sheet; document actions remain fixed at the bottom.
- Selected-node placement uses the actual canvas size, safe-area insets, sheet
  extent and graph scale. Empty canvas taps collapse; double taps zoom.
- Next match cycles and wraps through matching titles, centers each result and
  disables when there are no results. Changing the query resets navigation.
- Chat and Graph reuse AskField for multiline input. Graph keeps a draft editable
  while a reply runs, disables duplicate submission and adds send haptics.

Validation on 2026-10-12:

- flutter analyze: clean. Full suite: 1,033 passed, 30 existing opt-in skips.
- Normal Android debug APK built and installed on Pixel 9 Pro XL, USB device
  49041FDAS0015H, preserving its saved session.
- Maestro passed search/match navigation, clear search, zoom in/out/fit, sheet
  opening with real chunks, expansion/shrink with document actions visible,
  opening the original file preview, empty-canvas collapse, double-tap interaction
  and entering/clearing a Chat draft. A final targeted search found exactly one
  architecture-and-security match, centered it, opened its real chunk panel and
  closed it successfully. No new chat was submitted by these device flows.
- One exploratory flow's final Graph tab tap failed because returning from the
  file restored keyboard focus. Hiding the keyboard and rerunning navigation
  passed. This failure is not counted as a passing whole flow.

Local screenshots and logs remain under ignored dev-logs; private document
contents are not published. No new package/backend change and no owner gate
closure. F3 accessibility, F4 pulse polish and F5 recluster verification remain.
