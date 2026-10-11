# Cerebro Mobile

The Flutter client for **Cerebro**, a personal knowledge base you can chat
with. It is a second consumer of the existing Cerebro backend (FastAPI on
Render, Supabase for auth, data and storage), not a rebuild of it. The web
app ([`Tunasmelt/Cerebro-2.0`](https://github.com/Tunasmelt/Cerebro-2.0)) is
the source of truth for what the product does; this repo expresses the same
product on a phone.

> Status: Phases 0–6 are implemented and owner-verified. Phase 7 recovery, file viewer and native branding are implemented;
> physical/iOS release checks remain pending; see [Status](#status) for the remaining release checks.

## What works today

- **Auth**: Supabase email/password sign-up and sign-in, email confirmation
  by deep link (`cerebro://confirm-email`), session handling and route guards.
- **Documents**: list and detail views, upload from the file picker, gallery
  or camera, live ingest status (processing, ready, failed, incomplete),
  retry for failed documents, delete, and in-app original image/PDF/text viewing.
  Uploads go signed-URL-direct to Supabase Storage (`upload-init`, PUT,
  `upload-confirm`); file bytes never pass through a proxy.
- **Chat**: streamed answers over SSE with numbered citation chips that open
  the source document, stop and retry.
- **Conversations**: list past conversations, reopen one with its citations
  intact, delete one, export one to Markdown and share it.

- **Settings**: live profile, display name/avatar updates, email confirmation,
  password changes, real document storage totals and sealed-document links.
  Vault-data removal requires explicit confirmation and leaves the sign-in
  account intact. See [verification](docs/user-settings-verification.md).

## Stack

| Concern | Choice |
| --- | --- |
| Framework | Flutter 3.38 / Dart ^3.10 |
| State | Riverpod 2.6 |
| Routing | go_router 16 (`StatefulShellRoute`, bottom-nav shell) |
| Auth / data | `supabase_flutter` |
| HTTP | Dio, plus a Chopper client generated from the FastAPI OpenAPI spec (`swagger_dart_code_generator`) |
| Streaming | A purpose-built SSE parser and typed chat events in `lib/core/sse` |
| Files / sharing | `file_picker`, `image_picker`, `share_plus`, `path_provider` |

Graph rendering uses `flutter_force_directed_graph`; sealed crypto uses
`cryptography` 2.9.0. Sealed UI and backend integration are implemented.

## Project layout

```
lib/
  app/        router, routes, app shell
  core/       config, networking (Dio + generated client), SSE
  features/   auth, documents, chat, graph, kanban, todo, playground,
              sealed, settings  (each split into data/ and presentation/)
  shared/     theme, design tokens, shared widgets (e.g. ErrorView)
  api_spec/   normalised OpenAPI spec the client is generated from
scripts/      normalize_openapi_spec.py
docs/screenshots/   per-milestone verification screenshots
```

## Running it

Prerequisites: Flutter 3.38+, and an Android emulator/device or an iOS
simulator. The Supabase URL and public anon key are in
`lib/core/config/supabase_config.dart` (the anon key is meant to be public;
row-level security is the boundary).

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regenerate API client
flutter run
```

## Testing

```sh
flutter analyze
flutter test
```

Some suites talk to the **real backend** and are skipped unless you supply a
confirmed test account:

```sh
flutter test --dart-define=CEREBRO_TEST_EMAIL=you@example.com \
             --dart-define=CEREBRO_TEST_PASSWORD=...
```

Chat tests make real LLM calls and clean up the sessions and documents they
create. CI (`.github/workflows/ci.yml`) runs analyze + test, an Android debug
build and an iOS no-codesign build.

## Status

Work follows strict phases, each with mechanical test criteria per milestone
and a gate that the project owner confirms on a real device
([`phases-and-gates.md`](phases-and-gates.md)).

| Phase | Scope | State |
| --- | --- | --- |
| 0 | Foundation: scaffold, tokens/theme, networking, typed client, CI | Done; owner gate closed 2026-10-11 |
| 1 | Auth and app shell, error handling | Done; owner gate closed 2026-10-11 |
| 2 | Documents and upload | Done; owner gate closed 2026-10-11 |
| 3 | Chat and retrieval: SSE client, chat screen, session management | Done; owner gate closed 2026-10-11 |
| 4 | 2D brain graph | 4.1–4.3 implemented; 4.3 checked against the real backend and Android emulator (live pulses, Graph replay picker, automatic Chat History replay). Owner gate closed 2026-10-11. |
| 5 | Sealed tier (Argon2id + AES-256-GCM, parameter-identical to web) | 5.1-5.4 required Android checks passed, including completed sealed chat and uninterrupted real 15-minute expiry after backend repairs. 5.4 direct/injection, malformed-key and genuine cross-user checks pass after backend PR #94; owner gate closed 2026-10-11. |
| 6 | 6.1 live Kanban, 6.2 live Todo, 6.3 read-only Token Playground | Implemented and verified on Android with the deployed backend: card/task persistence and saved-turn prompt/token/cost display. Owner gate closed 2026-10-11. |
| 7 | Platform polish and release readiness | Recovery, viewer and branding implemented; Pixel checks passed. Owner gate closed 2026-10-12 by explicit direction. iOS and additional-device verification remain pending. |

The owner confirmed all implemented phase gates (0–6) on 2026-10-11.
Historical agent records retain their test/environment limitations; this
sign-off does not add an agent-run iOS test. Phase 7
is owner-accepted; outstanding iOS and device-matrix checks remain recorded.

## Design decisions worth knowing

- **2D graph on purpose.** Web uses a 3D scene; touch-based 3D navigation is
  worse than mouse control, so mobile stays 2D deliberately.
- **No second backend.** Retrieval, clustering and sealing logic live in the
  FastAPI service; this client renders state and calls endpoints.
- **Sealed tier crypto must match web parameter for parameter**, verified by
  a cross-platform round-trip test before any UI ships. The sealed tier is
  never described as "zero-knowledge": the derived key travels to the server
  per request during an unlock session.

## Documentation

- [`CLAUDE.md`](CLAUDE.md): context and non-negotiable decisions for any
  AI-assisted session
- [`architecture-and-spec.md`](architecture-and-spec.md): architecture
- [`phases-and-gates.md`](phases-and-gates.md): milestones, tests, gates
- [`flutter-rules.md`](flutter-rules.md) and [`AGENTS.md`](AGENTS.md): code
  conventions and agent rules
- [`CHANGELOG.md`](CHANGELOG.md): what changed and why
- [`HANDOFF.md`](HANDOFF.md): decisions carried over from web

Owner update (2026-10-12): all phase gates 0–7 are closed by explicit owner
direction. Outstanding hardware verification remains listed in Phase 7 records.
