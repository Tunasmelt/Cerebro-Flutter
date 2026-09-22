# Changelog — Cerebro Mobile

Format: date, what changed, why. Append, don't rewrite history — if a
decision gets reversed later, the reversal is a new entry, not an edit
to the old one.

## Unreleased

### Added
- Initial doc set: `CLAUDE.md`, `architecture-and-spec.md`,
  `flutter-rules.md`, `AGENTS.md`, `HANDOFF.md`, this file.

### Decided
- Signed-URL-direct-to-storage upload flow, matching web's
  post-Vercel-limit redesign.
- 2D brain graph via `flutter_force_directed_graph`, explicit choice
  over a 3D port.
- `package:cryptography` (+ optional `cryptography_flutter`) for the
  sealed tier's Argon2id + AES-256-GCM, pending exact parameter
  confirmation from the web repo's actual source.
- Typed API client generated from FastAPI's OpenAPI spec, resolving the
  typed-contract question web deferred at its own Stage 0.1.
- No BFF/proxy layer — mobile calls Supabase and FastAPI directly.

### Corrected
- The web sealed tier's KDF does not run on native browser WebCrypto —
  no shipping browser supports Argon2id yet. It's a WASM-compiled
  Argon2 library; only AES-256-GCM is native WebCrypto. This was stated
  incorrectly during initial mobile design research and corrected before
  any mobile crypto code was written.

### Open, not yet decided
- State management library (Riverpod proposed, not committed).
- Which OpenAPI-to-Dart codegen tool (`openapi_generator` vs.
  `swagger_dart_code_generator`) — pending a currency check at
  implementation time.

### Corrected
- ~~Stage-level phase plan for mobile — not written yet~~: superseded,
  `phases-and-gates.md` now exists.

## 2026-09-22

### Added
- Milestone 0.1 (project scaffold & tooling) complete on the Android
  side. `flutter create` run with folder structure matching
  `flutter-rules.md` (`lib/core`, `lib/shared`,
  `lib/features/{auth,documents,chat,graph,sealed,kanban,todo,playground}`,
  each feature split into `data/`/`presentation/`). Default
  `flutter_lints` config kept as-is; `flutter analyze` clean.
- Dev machine tooling stood up from scratch: Flutter SDK added to user
  `PATH` (was installed at `C:\tools\flutter` but unconfigured); Android
  SDK cmdline-tools installed manually (Android Studio's bundled install
  didn't include them) and all SDK licenses accepted; a system image
  (`android-36;google_apis_playstore;x86_64`) installed and an emulator
  (`cerebro_test`) created, since none existed.
- Eclipse Temurin JDK 21 installed at `C:\tools\jdk-21.0.5+11` and wired
  in via `flutter config --jdk-dir`, because Android Studio's bundled
  JBR is Java 25, which Gradle 8.14 (this project's wrapper version)
  cannot run. Without this, `flutter build apk` fails outright.
- **Verified functionally, not just compiled:** `app-debug.apk` built,
  installed on the `cerebro_test` emulator, and confirmed as the
  foreground activity (`com.cerebro.cerebro_mobile/.MainActivity`) via
  `adb`. This satisfies Milestone 0.1's actual exit criterion — the app
  running on a real emulator — not just a successful build.

### Blocked
- **iOS build/run verification (`flutter build ios --no-codesign`, iOS
  simulator launch) cannot be completed on this machine.** Dev machine
  is Windows; iOS toolchain (Xcode) is macOS-only, a hard Apple platform
  requirement, not a missing-package problem. Options to unblock:
  borrow/use a Mac, or a macOS CI runner (e.g. Codemagic, GitHub Actions
  `macos-latest`). Phase 0 Gate cannot be signed off until this is
  resolved — see `phases-and-gates.md` Phase 0 Gate checklist, which
  explicitly requires a real iOS simulator run.

### Corrected
- Milestone 0.2 references `ui-design-prompts.md`'s Design System
  section as the token source — **this file does not exist in this
  repo or the web repo.** Ported the real values instead from
  `Cerebro 2.0/apps/web/src/app/styles/tokens/{colors,typography,spacing,radius}.css`,
  which is a higher-priority source per `AGENTS.md`'s hierarchy anyway
  (actual code over prose). Tokens live in `lib/shared/tokens/`,
  assembled into `lib/shared/theme/app_theme.dart`.

### Added
- Font assets bundled: DM Sans, Outfit, JetBrains Mono variable-font
  TTFs (matching web's exact `next/font/google` declarations in
  `apps/web/src/app/layout.tsx`) sourced from the `google/fonts` GitHub
  repo — web itself stores no font files (Next.js fetches them at build
  time), so there was nothing to copy directly. Saved to
  `assets/fonts/`, registered in `pubspec.yaml` at weights
  400/500/600/700 per `typography.css`, wired into `AppTypography`.
  Confirmed rendering (not falling back to system font) on the Android
  emulator.
- Five wireframe screens built (dispatched as parallel agents): Board
  (`kanban/presentation/board_screen.dart` + `kanban_view.dart`,
  `todo/presentation/todo_view.dart`), Token Playground
  (`playground/presentation/`), sealed document unlock
  (`sealed/presentation/`), Settings (`settings/presentation/`), and an
  original Graph screen (`graph/presentation/`) derived from
  `Cerebro 2.0/Mockups 2.0/src/components/Brain.tsx`'s force-directed
  canvas design (per explicit direction — the mobile mockup's radial
  hub-and-spoke graph was not to be used). All five reuse the existing
  `AppColors`/`AppTypography`/`AppSpacing`/`AppRadius` tokens, no new
  dependencies, no `main.dart` wiring at dispatch time. A temporary
  `DebugLauncherScreen` was added to `main.dart` afterward so the
  screens are reachable for manual/visual verification before real app
  navigation exists (Milestone 1.2) — marked DEMO-ONLY, delete when
  that milestone lands.
- Five real bugs found via live emulator screenshots (not caught by
  `flutter analyze`/`flutter test`, since Dart's test harness doesn't
  render pixel output) and fixed: Board's FAB overlapped the bottom nav
  (nav bar wasn't in `Scaffold.bottomNavigationBar`); Playground had an
  "atlas-rerank-v2" branding leak the Settings screen's own Atlas fix
  didn't catch; Playground's prompt text was fully invisible (the
  invisible-text `TextField` was painted on top of, hiding, the
  highlighted `RichText` — fixed by reversing paint order with
  `IgnorePointer`); the sealed screen's locked card threw a 114px
  `RenderFlex` overflow (fixed with `SingleChildScrollView`); the
  graph's node-detail bottom sheet had no opaque background (the modal
  route's own `backgroundColor: transparent` — correct, for true
  rounded corners — assumed the sheet content would supply its own,
  which it didn't). All confirmed fixed via before/after screenshots.
- Milestone 0.3 (networking core) complete: `lib/core/network/` —
  single `Dio` instance (`ApiClient`), a `SessionTokenProvider`
  interface (kept decoupled from `supabase_flutter`, which isn't added
  until Milestone 1.1 auth work), an `AuthInterceptor` that attaches the
  JWT and fails fast with `UnauthenticatedException` when there's no
  session rather than sending the request bare, and an `ErrorMapper`
  producing distinct `NetworkUnreachableException` /
  `ServerErrorException` / `UnauthorizedException` types. Base URL is
  the real deployed Render service
  (`https://cerebro-api-d47y.onrender.com`, from `Cerebro 2.0/.env.example`
  → `API_BASE_URL`). `dio` added (5.11.1, verified publisher, 160/160
  pub points — checked per AGENTS.md before integrating). All unit
  tests plus two live-network functional tests (`/health` against the
  real deployed backend; a deliberately wrong host) pass — 13/13.
- Milestone 0.4 (typed API client generation) complete. `swagger_dart_code_generator`
  chosen over `openapi_generator` (331 vs 125 likes, 145/160 vs 130/160
  pub points, no Java toolchain dependency — checked per AGENTS.md).
  Generated client lives in `lib/core/network/generated/` (regenerated,
  never hand-edited); source spec in `lib/api_spec/cerebro_api.swagger.json`.
  Regeneration is a 3-step, 2-repo pipeline documented in
  `scripts/normalize_openapi_spec.py`'s docstring: (1) introspect the
  backend's FastAPI `app.openapi()` directly in Python from
  `Cerebro 2.0/services/api` — no live HTTP call, no auth needed, since
  `AuthMiddleware` only gates HTTP requests, not schema introspection;
  (2) normalize known generator-incompatible schema shapes via that
  script; (3) `flutter pub run build_runner build`. After each
  regeneration, delete `lib/core/network/generated/client_index.dart` —
  a known generator bug emits a broken self-import
  (`cerebro_api.swagger.swagger.dart`, doubled `.swagger`); the file is
  unused dead weight since `CerebroApi` is imported directly from
  `cerebro_api.swagger.dart` instead. `lib/core/network/generated/**`
  excluded from `flutter analyze` (cosmetic unused-import warnings in
  generated code, not actionable).
- **Finding, not a defect here:** checked every endpoint in the real
  spec — only `/health` and a dev-only probe route have typed response
  schemas; every product endpoint (`documents`, `chat`, `graph`,
  `boards`, `todos`, …) returns an untyped response (`{}` schema, no
  `response_model=` on any backend route). Request *bodies* are
  properly typed. This means "typed API client" here means typed
  requests + typed enums, `dynamic`/`Object` responses — not a full
  round-trip type contract. Flagged as a cross-repo finding per
  AGENTS.md rather than worked around; not fixed here, since response
  typing is a backend decision. Milestone 0.4's unit test was written
  against a real typed request model (`UploadInitBody`) instead of the
  nonexistent typed `Document` response the milestone doc's own example
  assumed.
- One normalization needed: `UpdateTodoBody.priority` uses the
  `anyOf: [enum, null]` shape FastAPI emits for
  `Optional[Literal[...]] = None`; `swagger_dart_code_generator` 4.1.1
  references an enum it never defines for that shape and breaks the
  whole generated file. Confirmed (full scan) it's the only field in
  the spec with this shape. Fixed by normalizing the *input* spec
  (flattening to a plain nullable enum) in
  `scripts/normalize_openapi_spec.py`, not by hand-patching generated
  output — survives regeneration.
- Proved the regeneration pipeline runs end-to-end, not just once by
  hand: added a throwaway field to the local spec, regenerated, watched
  it appear in the generated model; reverted, ran `build_runner clean`
  + rebuild, confirmed it's gone again. All 24 tests (13 from Milestone
  0.3 + 2 new unit/functional for 0.4 + 9 wireframe screen tests) pass;
  `flutter analyze` clean.
- **Known artifact from this work, not yet cleaned up:** a throwaway
  Supabase test user (`cerebro.mobile.spec.fetch@gmail.com`) exists in
  the shared Auth project from an earlier attempt to fetch the spec
  over live HTTP before the local-introspection approach was found.
  Harmless (unconfirmed→confirmed test account, no real data attached)
  but real — flagging rather than leaving it silent. Not deleted
  without being asked.
