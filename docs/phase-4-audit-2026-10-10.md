
## Follow-up: requested fixes (2026-10-10)
Findings 1–3 above have implementation fixes and permanent regressions.
Graph initialization consumes an existing pulse, and entering Graph replays
current conversation retrievals after branch activation. New chat clears and
cancels replay; active-session deletion uses that same path. History retry
retains its opening replay policy and generation guard. Router test covers
history-before-first-Graph entry after replay has already finished; controller
tests cover New chat, active deletion, and retry with/without replay enabled.
Full suite: 672 passed, 30 skipped; analysis clean; Android APK builds.
Findings 4–5 were outside the requested fixes and remain open.
