# Cerebro Mobile — Architecture & Spec

Companion to `CLAUDE.md`. This is the technical detail; `CLAUDE.md` is
the constraint summary. Where the two disagree, this file is wrong and
needs fixing — `CLAUDE.md` encodes decisions that must not silently
drift.

---

## 1. System position

```
Flutter app (iOS/Android)
   │
   ├─ supabase_flutter → Supabase Auth (JWT), direct signed-URL PUTs
   │                      to Supabase Storage
   │
   └─ generated REST client → FastAPI (Render) → Supabase Postgres/RLS
                                              → hosted AI providers
```

Mobile talks to two things directly: Supabase (for auth and the actual
storage byte transfer, both already RLS/policy-protected at that layer)
and FastAPI (for everything requiring server-side logic — retrieval,
chat, graph, sealed-tier operations, job creation). There is no
Next.js-equivalent BFF layer for mobile, and there doesn't need to be —
the BFF on web existed for browser-specific reasons (CORS, hiding the
backend origin from view-source, a place to hold cookies) that don't
apply to a native client making direct HTTPS calls with a bearer token.

**This does mean Render's CORS/allowed-origin config needs to permit
non-browser clients** — confirm the current FastAPI CORS middleware
setup doesn't assume every caller sends an `Origin` header a browser
would send; a native HTTP client may not, and a policy written only
against expected web origins could reject it.

---

## 2. Typed client

The deferred "real typing strategy" from the web project's Stage 0.1
gets resolved here, not re-deferred: generate a Dart client from
FastAPI's OpenAPI spec (`openapi_generator` or `swagger_dart_code_generator`
— confirm which is better maintained at build time) rather than hand-
writing request/response models a second time in a second language.
Regenerate on every backend API change; do not hand-patch the generated
client when the spec is slow to update — fix the spec instead.

---

## 3. Upload flow

Identical in shape to web's Stage 1.1 redesign, because the constraint
that forced it — a platform body-size limit on any proxying layer — is
just as real for a mobile client if it were ever routed through one,
which it isn't here since mobile skips the proxy entirely:

```
1. Call POST /documents/upload-init (filename, mime, size_bytes)
   → creates documents + ingest_jobs rows BEFORE any signed URL exists
   → returns document id + a short-lived Supabase signed upload URL
2. PUT file bytes directly to Supabase Storage with that URL
3. Call POST /documents/{id}/upload-confirm
   → server verifies the object actually exists (existence + size)
     before advancing the job past `uploading`
```

Size enforcement is Supabase Storage's bucket-level `file_size_limit` —
a platform ceiling on the Supabase plan in use, not a number this app
chooses. Any client-side size check here is UX only, same as web.

**Mobile-specific addition worth designing for, not required for parity:**
camera-roll and in-app-camera capture as upload sources, not just a file
picker — this is the one upload UX mobile can do better than desktop,
per the earlier discussion, and it's a source-selection detail on top of
the same three-call flow, not a different flow.

---

## 4. Sealed tier

**Correction carried forward from the web project's own history:**
Argon2id is not natively supported by browser WebCrypto — no shipping
browser has it as of this writing (there is an open cross-browser
tracking issue for it). The web implementation's KDF step is a
WASM-compiled Argon2 library; only its AES-256-GCM step is genuinely
native WebCrypto. **Confirm exactly which library and which parameters
the web repo's actual crypto code uses before writing a single line of
Dart against this section** — this document describes the shape of the
solution, not the literal numbers, because the literal numbers live in
the web repo, not here.

Dart side:

```dart
final algorithm = Argon2id(
  memory: <MATCH_WEB_EXACTLY>,      // KiB
  parallelism: <MATCH_WEB_EXACTLY>,
  iterations: <MATCH_WEB_EXACTLY>,
  hashLength: <MATCH_WEB_EXACTLY>,  // bytes
);
final secretKey = await algorithm.deriveKeyFromPassword(
  password: passphrase,
  nonce: salt,                      // same salt convention as web
);
```

AES-256-GCM via the same `package:cryptography` package (or
`cryptography_flutter` for native-speed acceleration, falling back
automatically where unavailable) — nonce length and tag length
(standard: 12-byte nonce, 128-bit tag) must match web's convention.

**Required before this ships, not optional hardening:** a cross-platform
test — seal a document on web, unlock it on mobile; seal on mobile,
unlock on web. Same-algorithm-name is not proof of same output; only
the round-trip test is.

Everything else about the sealed tier is unchanged from web: metadata
stays searchable while sealed, content does not; unlock issues a
session-scoped claim with a server-enforced expiry, not a client-trusted
one; sealed content must fail closed on any missing filter, adversarial
prompt, or expired claim — same adversarial test suite web already
built, run again here, not assumed to transfer because "it's the same
API."

---

## 5. Brain graph (2D)

Deliberate choice per `CLAUDE.md`, not a fallback. Library:
`flutter_force_directed_graph` (verified publisher, minimal dependency
footprint — `collection`, `flutter`, `vector_math` only, built-in
pan/zoom/drag gesture handling).

**The layout truth stays server-side, unchanged from web's Phase 2
design:** document-level clustering (k-means) and 2D projection (PCA/SVD)
happen in the same `graph/` module already running for web. Mobile's
`/graph/nodes` and `/graph/edges` calls hit the same endpoints web's
graph view calls — this is a second renderer for an existing API, not a
new graph API. Cluster membership is real; node position within a
cluster is cosmetic; that distinction doesn't change because the
renderer changed languages.

Retrieval-replay (nodes pulsing because they were actually retrieved,
not decoratively) requires SSE support in Dart — `http`'s `Client` has
no native `EventSource` equivalent. Use a streaming-response approach
(`http.Client().send()` with a `StreamedResponse`, parsed as SSE frames)
or a maintained SSE package; confirm current package health before
depending on one, this corner of the Dart ecosystem moves.

---

## 6. What does not get rebuilt

Kanban, todo list, and the token playground are CRUD screens against
existing endpoints — no new design decisions, straightforward client
work once auth and the typed client exist. Not detailed further here
because there's nothing architecturally interesting about them; treat
them as low-risk, sequence them late.

Query rewriting, HyDE, and the associative memory graph are entirely
server-side (per web's Phase 5) — mobile does not implement any of this
logic, it only renders results that already reflect it.
