# Cerebro Mobile — Handoff

Read this once, at the start, alongside `CLAUDE.md`. It exists to carry
context that isn't naturally a "rule" or a "spec" — the reasoning behind
decisions, so they don't get silently re-litigated.

## Where this came from

Cerebro's web app (`Tunasmelt/Cerebro-2.0`) shipped through Phases 0–4
and is partway through Phase 5 (RAG quality, associative memory graph,
production hardening) with Phase 6 (data export) not yet started. Mobile
is a new client against that existing product, not a new product.

**Check the web repo's current phase status before assuming this
handoff's description of it is still accurate** — this document was
written at a point in time, the web project wasn't.

## Decisions already made, and why, so they aren't re-opened by accident

- **Signed-URL-direct-to-storage upload**, not a proxied upload. Forced
  by Vercel's hard function-body-size limit on web; carried over to
  mobile for consistency and because it's the correct pattern for large
  binary uploads regardless of platform, not because mobile has the same
  constraint.
- **2D graph, not a 3D port.** Explicitly chosen, not a limitation
  apologized for — touch-based 3D navigation is a worse experience than
  desktop mouse control, and native mobile effort is better spent on
  camera uploads, quick chat, and task notifications than on
  reimplementing a WebGL scene in a language with no mature equivalent.
- **No BFF/proxy layer for mobile.** Web's Next.js proxy existed for
  browser-specific reasons (CORS, hiding origin, cookie handling) that
  don't apply to a native client. Mobile calls Supabase and FastAPI
  directly. This is a simplification versus web's architecture, not a
  security regression — RLS and bucket policies are the real boundary in
  both cases.
- **The web sealed tier's actual mechanism was initially misdescribed**
  during design (stated as running via native browser WebCrypto for
  Argon2id; no browser ships that yet — it's a WASM library). This was
  caught during research for mobile, not before. Any prose description
  of "how the web sealed tier works" — including in this doc set —
  should be verified against the actual web source before being treated
  as fact, precisely because this kind of error has already happened
  once.
- **A typed API contract was deliberately deferred on web** ("minimal
  stub, revisit when a real client needs it") and never fully resolved
  before a third language entered the picture. Mobile is the forcing
  function to finally generate a client from the OpenAPI spec rather
  than defer a third time.

## What "done" means for this handoff

This doc set defines architecture and rules. It does not define a phase
plan with stage-level exit criteria — that's the next artifact, written
only when explicitly requested, following the same stage/gate discipline
as the web project's `phases-and-gates.md`. Don't start implementation
against these docs alone without that plan existing; "architecture
exists" and "build order and verification exist" are different
documents on purpose, same separation as web had from the start.
