# AGENTS.md — Cerebro Mobile

For any coding agent working in this repo, in addition to `CLAUDE.md`
(read that first — this file doesn't repeat its constraints).

## Source of truth hierarchy, when docs disagree

1. The web repo's actual code (`Tunasmelt/Cerebro-2.0`) — for API shape,
   sealed-tier crypto parameters, and product behavior.
2. The web repo's docs (`architecture-and-security.md`,
   `api-documentation.md`) — for intent and constraints, verified
   against #1 when precision matters (they have drifted from code
   before, per that project's own history — a documented example is the
   `documents.status` vs `ingest_jobs.state` conflict introduced and
   caught during that build).
3. This repo's docs — for mobile-specific decisions layered on top of
   the above.

If this repo's docs contradict the web repo's actual API, this repo is
wrong. Fix it here; do not build around the contradiction silently.

## Before starting any stage

State back, in your own words, what the stage's exit criteria actually
require — same discipline as the web project's kickoff prompt. If a
stage's test can't be run against a real device/emulator and a real
backend call, it isn't a valid exit criterion; say so before writing
code, don't discover it after.

## Ground rules (same spirit as the web project, restated for this repo)

- Work one stage at a time, in dependency order. Don't start a stage
  whose prerequisites haven't passed their own tests.
- A stage is done when its tests pass against a real build on a real
  device/emulator, not when `flutter analyze` is clean.
- Never mark a phase gate passed yourself. That requires the project
  owner to personally run the app and confirm it — same as web.
- If something here or in the web docs is ambiguous or contradictory,
  stop and ask. This project has already had one real cross-repo
  inconsistency (the false claim that a "Docify" retrieval core existed
  to fork) cost real time on the web side. Don't let an unverified
  assumption about the mobile side repeat that pattern.
- Before integrating any Flutter/Dart package (state management, HTTP,
  crypto, graph rendering, SSE), check its current pub.dev status
  (maintenance activity, platform support, license) — package health in
  this ecosystem changes faster than training data.
- Before writing sealed-tier crypto code, get the exact KDF parameters
  from the web repo's actual source, not from any prose description of
  them in any doc, including this one.

## What this repo does not own

Retrieval logic, embedding, clustering, chat generation, and sealed-tier
server-side enforcement all live in the FastAPI service and are out of
scope here. If a task seems to require changing backend behavior, that's
a cross-repo change — flag it rather than working around it client-side.
