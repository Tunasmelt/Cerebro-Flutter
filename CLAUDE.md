# CLAUDE.md — Cerebro Mobile

Context for any Claude session (chat, Code, or an agent) working in this
repo. Read this before touching code. Companion docs in this same
folder: `architecture-and-spec.md`, `flutter-rules.md`, `AGENTS.md`,
`HANDOFF.md`, `CHANGELOG.md`.

## What this is

The Flutter client for Cerebro — same backend (FastAPI on Render,
Supabase for data/auth/storage), a second consumer of the existing REST
+ SSE API, not a rebuild of it. Web (`Tunasmelt/Cerebro-2.0`) is the
source of truth for what the product does; this repo's job is to
express the same product on a phone, not to reinterpret it.

## Precondition — read before assuming API stability

At the time this repo was started, the web project's own status table
listed Phase 5 (RAG quality, associative memory graph, production
hardening) as ongoing and Phase 6 (data export) as not started. If the
web API has moved since — new fields, changed endpoints, a different
upload flow — `api-documentation.md` in the web repo is the source of
truth, not this file's memory of it. Check there first when something
here looks stale.

## Non-negotiable decisions carried over from the web project

- **Sealed-tier crypto must be parameter-identical to web, not just
  algorithm-identical.** Argon2id via `package:cryptography`, AES-256-GCM
  via the same package (optionally `cryptography_flutter` for native
  speed). The exact memory cost, iteration count, parallelism, salt
  length, and hash length must match the web implementation's actual
  values byte for byte — confirm those values directly from the web
  repo's crypto code, don't assume the numbers stated anywhere in prose.
  See `architecture-and-spec.md` §Sealed tier for the required
  cross-platform test.
- **The web sealed tier does not run on native browser WebCrypto for
  Argon2id** — no browser ships that natively yet. It's a WASM-compiled
  Argon2 implementation; only the AES-GCM half is native WebCrypto.
  Confirm which specific JS library the web repo actually calls before
  writing the Dart side against an assumption.
- **The 2D graph is a deliberate choice, not a fallback.** Web moved to
  a hand-rolled 3D three.js scene in its own Phase 5; mobile stays 2D on
  purpose — touch-based 3D navigation is worse than desktop mouse
  control, and this isn't a capability gap to apologize for.
- **The upload flow is signed-URL-direct-to-storage**, identical in
  shape to web's: call `upload-init`, PUT bytes straight to Supabase
  Storage, call `upload-confirm`. Do not route file bytes through any
  proxy — this exists because Vercel's function body limit forced the
  same redesign on web; the same constraint doesn't disappear because
  the client changed.
- **Do not build a second backend, a second retrieval pipeline, or a
  second auth system.** Every non-trivial piece of business logic
  belongs in the existing FastAPI service. This client renders state
  and calls endpoints; it does not reimplement RAG, clustering, or
  sealing logic locally.

## Stack

Flutter (Dart), `supabase_flutter` for auth/session, a generated HTTP
client from the FastAPI OpenAPI spec (see `architecture-and-spec.md`
§Typed client), `flutter_force_directed_graph` for the 2D brain view,
`package:cryptography` (+ `cryptography_flutter`) for the sealed tier.

## Before writing ingest/upload or sealed-tier code

- Re-read `architecture-and-spec.md` §Upload flow and §Sealed tier in
  full — both encode hard-won corrections from the web build (the
  Vercel body-limit failure, the WebCrypto/Argon2id correction) and
  repeating either mistake independently would be a real regression in
  process, not just in code.
- Run an API-currency check (Supabase Flutter SDK version, Render CORS
  config for a non-browser client, current `package:cryptography` API
  surface) before writing code against any of them from memory.

## Testing & CI gate

Same discipline as web: a stage is not done when the code compiles, it's
done when its stated tests pass against a real device or emulator, not
just `flutter analyze`. See `phases-and-gates.md` (to be written) for
the stage/gate structure once mobile phases are scoped.

## Naming discipline

Same rule as web, restated because a second client is a second chance to
get it wrong independently: never call the sealed tier "encrypted" in
isolation or "zero-knowledge." The derived key transits to the server
per request during an active unlock session, on mobile exactly as on
web.
