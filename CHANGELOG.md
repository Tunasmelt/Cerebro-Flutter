# Changelog — Cerebro Mobile

Format: date, what changed, why. Append, don't rewrite history — if a
decision gets reversed later, the reversal is a new entry, not an edit
to the old one.

## 2026-10-12 — UI/UX Phase C and direct previews

- Render chat Markdown with trusted inline citations, code/answer copy,
  accessible targets, typing feedback, respectful tail scrolling and Latest.
- Group conversation history by date and add delayed swipe deletion with Undo,
  account-change cancellation and failure recovery.
- Open document previews directly from Docs, Chat and Graph, with a details
  action. Render uploaded Markdown and captured extracted text; offer explicit
  external opening for unsupported originals while preserving sealed guards.
- Verified 958 tests (30 existing opt-in skips), Android debug build, real
  backend Markdown/citations/history/export and Pixel image/PDF navigation.
  Further native clipboard/source-opening checks await a connected device.
  Evidence and scope: docs/ui-ux-phase-c-chat-and-previews.md.

## Unreleased

### Added
- Initial doc set: `CLAUDE.md`, `architecture-and-spec.md`,
  `flutter-rules.md`, `AGENTS.md`, `HANDOFF.md`, this file.

### Decided
- Riverpod for state management, per Phase 1 audit (2026-09-22) —
  `flutter-rules.md`'s proposed default, committed now because Phase 1
  auth needs app-wide session state shared across nav guards, the
  interceptor, and every screen; can no longer stay deferred.
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

### Corrected
- ~~Stage-level phase plan for mobile — not written yet~~: superseded,
  `phases-and-gates.md` now exists.
- ~~Which OpenAPI-to-Dart codegen tool — pending a currency check~~:
  superseded, resolved at Milestone 0.4 (`swagger_dart_code_generator`
  chosen, see the 2026-09-22 entry below).

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
- Project published to GitHub: `Tunasmelt/Cerebro-Flutter`, `main`
  branch. `.claude/` and `dev-logs/` (scratch debugging output, not
  deliverables) added to `.gitignore` before the initial commit; full
  secret scan across all staged files came back clean.
- Milestone 0.5 (CI pipeline) complete. `.github/workflows/ci.yml`:
  three jobs — `Analyze & test` (ubuntu), `Build Android (debug)`
  (ubuntu, debug APK), `Build iOS (no codesign)` (macOS runner, since
  iOS builds need one — same constraint that blocked Milestone 0.1's
  local iOS verification). `flutter analyze` defaults to
  `--fatal-warnings` on, confirmed before relying on it — no CI config
  change needed for the warning-level proof test.
- Branch protection on `main`: all three checks required,
  `enforce_admins` on (so admins can't bypass it either). Note: setting
  this needed the GitHub token's "Administration" and "Pull requests"
  permissions, neither present initially — the token was regenerated
  mid-task with both added. The first protection rule attempt (set via
  GitHub's web UI) saved with an **empty required-checks list**, i.e.
  looked configured but enforced nothing; caught via the API once
  permissions allowed reading it, fixed via a direct API call with the
  three check names.
- Both functional tests proven on real PRs, not inferred from the
  workflow file: PR #1 (deliberately failing test) and PR #2 (a bare
  `unused_import` warning, no compile error) each got
  `mergeStateStatus: "BLOCKED"` from GitHub's live API. Both closed
  without merging; proof branches deleted after.

### Phase 1 audit (pre-work, before any Phase 1 code)
- **Real finding, checked directly against the live Supabase project:
  it requires email confirmation before a session exists.** A fresh
  sign-up returns no session; sign-in fails with `email_not_confirmed`
  until confirmed (hit this directly during Milestone 0.4's spec-access
  detour). This breaks Milestone 1.1's functional test as originally
  written ("sign up a real test user, confirm a session exists,
  restart, confirm it persists") — a fresh sign-up alone can't satisfy
  that.
- The web app already solved this
  (`apps/web/src/app/signup/page.tsx` + `auth/confirm/page.tsx`):
  sign-up → "Check your email" screen → user taps the emailed link →
  PKCE `exchangeCodeForSession` → session. **Mobile's version is
  harder**: there's no web page to redirect to, so this needs a real
  deep link / custom URL scheme (Android `AndroidManifest.xml`
  intent-filter, iOS `Info.plist` URL scheme,
  `supabase_flutter`'s deep-link listener) — not mentioned anywhere in
  `architecture-and-spec.md` or `phases-and-gates.md` before now.
- The reviewed sign-in mockup (`Mockups 2.0/src/components/SignIn.tsx`)
  has no "check your email" state and no separate sign-up screen —
  matches web's sign-in only. A mobile sign-up screen with this state
  needs to be designed; none exists in `Mockups/` yet.
- **Decided:** build the real email-confirmation deep-link flow as part
  of Milestone 1.1, not a stopgap — matches actual product behavior and
  the milestone's own test needs a real post-signup session.
- `supabase_flutter` checked per `AGENTS.md` before adding: 2.17.2
  stable (3.0.0-dev.4 prerelease also exists), officially
  Supabase-maintained — healthy, matches `architecture-and-spec.md`'s
  existing choice.

### Milestone 1.1 — Supabase auth integration
- `supabase_flutter` + `flutter_riverpod` added. Deep-link scheme
  `cerebro://confirm-email` registered natively (Android
  `AndroidManifest.xml` intent-filter, iOS `Info.plist`
  `CFBundleURLTypes`) — `supabase_flutter` handles the callback
  automatically once initialized (uses `app_links` internally, PKCE
  flow by default for any deep-link auth), no manual URL-parsing code
  needed. Supabase URL + anon/publishable key live in
  `lib/core/config/supabase_config.dart` — the anon key is meant to be
  public (RLS is the real boundary, not key secrecy), safe to commit;
  the `service_role` key is never embedded anywhere in this app.
- `lib/features/auth/data/`: `AuthRepository` interface (same
  decoupling discipline as `SessionTokenProvider` — testable without a
  real Supabase client), `SupabaseAuthRepository` (maps Supabase's
  `AuthException` to plain-language messages, `code` preferred but
  falls back to matching `message` text since `code` has been reported
  null on some genuinely-coded errors even on current supabase_flutter),
  `AuthNotifier` (Riverpod `Notifier`, states: `AuthLoading` /
  `Authenticated` / `Unauthenticated` / `AwaitingEmailConfirmation`).
  `SupabaseSessionTokenProvider` completes the seam
  `core/network/session_token_provider.dart` was built for back in
  Milestone 0.3 specifically so this could be wired in later without
  touching that code. A Riverpod `apiClientProvider` now gives the app
  one shared `ApiClient` instance using it.
- Sign-in screen adapted from `Mockups 2.0/src/components/SignIn.tsx`.
  No sign-up mockup exists — built mirroring web's real, working
  pattern instead (`apps/web/src/app/signup/page.tsx`): email/password/
  confirm, then a "Check your email" state, since
  `AwaitingEmailConfirmation` is the expected outcome on this project,
  not an edge case. Both wired into `DebugLauncherScreen` for manual
  verification (real nav is Milestone 1.2).
- **Real finding, not a code bug — confirmed by bypassing
  `package:gotrue` entirely with a raw `http.post`, same result:** this
  Supabase project's email-sending is rate-limited
  (`429 over_email_send_rate_limit`), and testing across this session
  (Milestone 0.4's spec-access detour + this milestone's own debugging)
  exhausted it. The built-in Supabase test SMTP has a strict default
  limit; a custom SMTP provider (Resend, SendGrid, etc.) would remove
  it — a real decision for whoever owns the Supabase project, not made
  here.
- Because of the above, the real-signup integration test
  (`test/features/auth/data/supabase_auth_integration_test.dart`) is
  gated behind `--dart-define=RUN_REAL_SIGNUP_TEST=true`, **skipped by
  default including in CI** — unlike the `/health` checks elsewhere,
  every real signup call sends an actual email against a shared,
  rate-limited resource, so running it on every CI trigger would make
  CI flaky from quota exhaustion, not real bugs, and could starve real
  users' signup emails. The "user exists in Supabase's Auth table"
  cross-check and the wrong-password test additionally need
  `--dart-define=SUPABASE_SERVICE_ROLE_KEY=...` (never hardcoded).
  Unit tests (4) and widget tests (5) — all mocked, unaffected by the
  rate limit — pass. Live verification against the real backend is
  pending the rate limit resetting.
- "Session persists across a real app restart" is inherently on-device
  behavior (supabase_flutter's own tested responsibility, restoring a
  persisted session before `Supabase.initialize()` completes) —
  verified live on the emulator, not by an automated test.

### Milestone 1.1 audit — mystery resolved: live sign-in works
- Re-ran `flutter analyze`/`flutter test` on merged `main`: still clean,
  33 pass / 3 skip. Code review of `AuthNotifier`/
  `SupabaseAuthRepository`/both screens found no logic bugs.
- **Root-caused the "empty response" failure from the PR description as
  dev-shell-specific, not a real bug.** Sign-in (unlike sign-up) never
  sends an email, so it's free to test without the rate limit. Live
  `signInWithPassword()` calls from `flutter test` on this Windows dev
  machine deterministically failed 3/3 retries with
  `AuthUnknownException: Received an empty response with status code 400`
  — while raw `http.post` replicating gotrue's exact headers *and* exact
  body (including the `gotrue_meta_security` field) succeeded every
  time with a proper response. Checked gotrue-dart's own GitHub history
  first (`supabase/supabase-flutter#1143`) — confirms the phenomenon is
  known/acknowledged upstream (the maintainer hit it during their own
  testing, in 2025, without ever isolating a root cause either), so this
  wasn't a symptom to dismiss. Isolated it to something inside
  `supabase_flutter`/`gotrue`'s internal `http.Client` usage — leading
  hypothesis is a persistent-connection/keep-alive quirk specific to
  this sandboxed dev machine's network path (raw calls each open a
  fresh one-shot connection; gotrue reuses a persistent client) — not
  confirmed further, since the next test settled the practical
  question.
- **Tested live on the Android emulator instead of the dev shell**
  (real Android networking, not this machine's Dart-VM/test-runner
  path): entered a deliberately wrong email/password on the real
  `SignInScreen`, tapped Sign in. Got **"Incorrect email or password."**
  — the correct, properly-mapped inline error, exactly as designed.
  Confirms the live auth flow genuinely works; the empty-response
  failure was specific to running gotrue from `flutter test` on this
  dev machine, not a defect in the app, the Supabase project, or
  gotrue-dart generally.
- Real signup/confirm/session-persistence verification is still
  pending — separately blocked by the email rate limit, unaffected by
  this finding. This is the one piece of Milestone 1.1 that still
  needs to happen before the milestone exits.
- Emulator itself proved unstable during this session (crashed twice
  before a run stuck; SystemUI ANR once mid-test) — unrelated to the
  app, worth knowing if this dev machine keeps doing it.

### Milestone 1.2 — App shell & navigation
- Added `go_router` (16.3.0) and built the real app shell: a
  `StatefulShellRoute.indexedStack` with six branches (Documents, Chat,
  Graph, Board, Playground, Settings) behind a single persistent
  `AppBottomNav`, replacing the per-screen decorative bottom nav bars
  built during the wireframe milestone (Board's `_BottomNavBar`,
  Playground's `PlaygroundBottomNav`, Settings' `_BottomNavBar` — all
  three deleted, their shape promoted into `shared/widgets/app_bottom_nav.dart`).
- Auth guard: `computeRedirect()` in `lib/app/router.dart` is a pure
  function (unit-tested directly, no `BuildContext`/router needed) —
  unauthenticated users are sent to `/sign-in` from any protected
  route, authenticated users are sent away from `/sign-in`/`/sign-up`
  to `/documents`. Wired into `GoRouter.redirect` via a small
  `ChangeNotifier` bridging `authNotifierProvider`'s stream into
  go_router's `refreshListenable`, so a sign-in or sign-out re-routes
  automatically — no manual `context.go` call from either auth screen.
- Added placeholder `DocumentsScreen`/`ChatScreen` so every nav
  destination has a real screen instead of a dangling route; both are
  explicitly temporary (real Documents is Phase 2, Chat is unscoped).
- Wired Settings' previously-stubbed sign-out button to
  `authNotifierProvider.notifier.signOut()` — this is what actually
  exercises the auth-guard redirect on sign-out, not just on launch.
- Removed `DebugLauncherScreen`/`TokenShowcaseScreen` from `main.dart`
  and their test (`test/widget_test.dart`) — served their purpose
  during Milestone 0.2 (visual comparison against web's component
  sheet) and Milestone 1.2 (screen index before real nav existed);
  every screen they linked to is now reachable through the real shell
  or the auth flow.
- Fixed a real (if minor) layout bug found writing these tests: the
  promoted `AppBottomNav`'s active-item circle badge overflowed its
  `SizedBox(height: 64)` by 2px in certain render passes — bumped to
  68px.
- Tests: 1 router-redirect unit test file (7 cases, pure function,
  covers every `AuthState` variant × route combination), 1 app-shell
  widget test file (7 cases — lands on Documents by default, each of
  the 6 destinations renders its expected screen, sign-out redirects
  to Sign in), 1 router-guard widget test file (launching
  unauthenticated cannot reach `/documents` even via a direct
  `router.go()` deep link, not just by UI navigation). All pass.
- Live-verified on the Android emulator: a fresh unauthenticated
  launch lands on Sign in with no path to the shell (screenshot:
  `docs/screenshots/milestone-1.2-unauthenticated-redirect.png`). The
  authenticated-shell side (all 6 destinations, sign-out) was **not**
  separately live-verified — no confirmed test account's password was
  available in this session, same Supabase email-confirmation rate
  limit blocking Milestone 1.1's remaining live checks. Covered
  instead by the automated widget-test suite above, which is
  comprehensive for this milestone's exit criteria.

### Milestone 1.3 — Error handling framework
- Added `ErrorPresentation.of(AppException)` in
  `lib/core/network/error_presentation.dart` — a pure, exhaustive
  mapping from each of Milestone 0.3's five `AppException` subtypes to
  an icon/color/`ErrorKind`, keeping "offline" and "server error"
  visually distinct rather than collapsed into one generic look. The
  exception's own plain-language `message` passes through unchanged;
  this layer only adds the icon/kind.
- Added `ErrorView`, the app's one shared inline error widget
  (`lib/shared/widgets/error_view.dart`) — compact (inline, matches
  `SignInScreen`'s existing error-banner footprint) or `expanded`
  (full-section replacement), with an optional Retry action. Nothing
  in the app should ever render a raw `Exception.toString()` again;
  this is the one place that decision gets made.
- Since no feature screen calls the real `ApiClient` yet (Documents/
  Chat are still Phase 2+ placeholders — see Milestone 1.2), added a
  minimal but real wiring point so the framework has an actual caller
  instead of sitting untested-in-practice: a "Connection" section in
  Settings (`ConnectionStatusNotifier` in
  `lib/core/network/connection_status_notifier.dart`) that calls the
  real deployed backend's `/health` endpoint via `apiClientProvider`,
  rendered through `ErrorView` on failure. This will very likely get
  superseded by a more meaningful real integration point once Phase 2
  builds the Documents list against the real API — that's expected,
  not a sign this was wasted work now.
- `ConnectionStatusNotifier.checkConnection()` is deliberately not
  private, so tests can fake just that one call (see
  `test/core/network/fake_connection_status_notifier.dart`) without
  reaching through the whole provider graph to a real, Supabase-backed
  `ApiClient` — every other Settings widget test now overrides
  `connectionStatusProvider` with an instant-success fake so they stay
  fast and network-free, matching this project's established
  fake-vs-real test split (mocked widget tests vs. dedicated
  `*_integration_test.dart` files that hit the real backend
  unconditionally).
- Tests: unit tests for `ErrorPresentation.of` (one case per exception
  type, plus a same-icon/same-color collision check), widget tests for
  `ErrorView` (compact/expanded, Retry only when given), 5 new widget
  tests for Settings' Connection section (checking/connected/offline/
  server-error states, Retry re-triggers the check) — all using the
  fake, and a real-backend functional test file
  (`connection_status_notifier_test.dart`, mirroring
  `api_client_integration_test.dart`'s established pattern) proving
  both a real success against the deployed Render backend and a real
  failure against a deliberately unreachable host resolves to
  `NetworkUnreachableException` rather than hanging — the automatable
  stand-in for "device network disabled" (the Dart VM `flutter test`
  runs in has no airplane-mode toggle to actually disable). All pass.
- Live-verified app still boots cleanly on the Android emulator after
  these changes (no crash, no new errors in `flutter run`'s log). The
  Settings screen itself — where the only concrete usage of this
  milestone's framework currently lives — was **not** live-verified
  interactively, same blocker as Milestones 1.1/1.2: no confirmed test
  account's password was available this session to reach the
  authenticated app shell.

### Phase 1 audit (post-Milestone 1.3, 2026-09-24)
Scope: everything merged for Milestones 1.1–1.3, checked against
`phases-and-gates.md`'s Phase 1 Gate. Method: re-ran `flutter analyze`
and the full suite on `main` (clean; 65 pass / 3 skip; CI green on all
four Phase 1 merges), read the auth/router/settings code, then
**reproduced each suspected defect with a throwaway test through the
real router or live on the emulator before recording it** — one
suspect (sign-out offline) was downgraded after reading gotrue's
source, and one initial "pass" (finding 4) turned out to be a
false positive of my own probe and was re-checked by dumping the
visible widget text. Nothing below is inferred.

**Verdict: Phase 1 is NOT ready to close.** A dead-end on the
sign-up → confirm path (finding 2) sits directly on the flow the gate
requires a human to walk through live, and none of the three gate
checks has been done.

> **Correction (same day, before merge): finding 1 is retracted.** My
> first probes waited only 400ms after each route change, which is
> shorter than go_router's pop/replace transition on this setup (the
> old route is still in the tree at 800ms and gone by ~1200ms). Re-run
> against the untouched original code with fully settled animations,
> the "stale Sign-up screen over the shell" does **not** occur — it was
> a timing artifact of my test, and I reported it as HIGH. Findings 2,
> 3 and 4 were re-verified the same settled way and **do** reproduce;
> finding 5 was observed live on the emulator and never depended on
> this. The lesson is now in the method line above: assert only after
> `pumpAndSettle`, and check a claimed "stuck" state survives it.

#### Defects (all reproduced; none fixed in this PR — audit only)
1. ~~**HIGH — stale Sign-up screen stays on top of the app after a
   session arrives outside the form.**~~ **RETRACTED — did not
   reproduce once animations were settled (see Correction above).**
   What remains true: `SignInScreen` opened Sign up with
   `Navigator.push(MaterialPageRoute)` (sign_in_screen.dart:149)
   instead of the router's existing `/sign-up` route — two ways to
   reach one screen. That is a hygiene smell, not a demonstrated bug.
2. **HIGH — "Check your email" is a dead end.** `_CheckEmailScreen`
   has no back, no resend, no "use a different email", and
   `AwaitingEmailConfirmation` lives in the *global* `AuthNotifier`,
   so leaving and re-opening Sign up shows the stale confirmation
   screen again. Reproduced. A typo'd address strands the user until
   the process restarts.
3. **MEDIUM — auth errors leak across screens.** Same global-state
   cause: a failed sign-in's "Incorrect email or password." renders
   inside `SignUpScreen` when the user taps Sign up. Reproduced with a
   descendant finder scoped to `SignUpScreen`.
4. **MEDIUM — an authenticated user opening any unknown route sees
   go_router's default "Page Not Found" page.** Verified: navigating
   to `/confirm-email` while signed in leaves URI `/confirm-email`
   with "Page Not Found"/"Home" visible over the shell. Reachable in
   practice by re-tapping an old confirmation link. (Unauthenticated,
   the guard sends unknown routes to Sign in — verified live via
   `adb ... -d cerebro://confirm-email?...`: no error page.)
5. **MEDIUM — a failed/expired confirmation link fails silently.**
   Verified live: firing the deep link with an invalid code makes
   supabase_flutter's own handler throw an *unhandled exception*
   ("Code verifier could not be found in local storage") and the UI
   shows nothing. PKCE's verifier is device-local, so a link opened
   after app-data clear, on another device, or in a desktop mail
   client will fail the same way. Needs a user-visible message and a
   resend path (ties into finding 2).
6. **LOW — sign-out swallows nothing.** `AuthNotifier.signOut()` has
   no error handling. Read gotrue 2.27.2: it removes the local
   session and emits `signedOut` *before* the server call, so an
   offline sign-out still logs the user out locally — only a stray
   unhandled exception and an un-revoked server-side refresh token
   result. Relevant to the airplane-mode gate item; not a blocker.
7. **LOW — error display is not yet "consistent across the app".**
   `ErrorView` covers `AppException`; the auth screens still build
   their own banner `Container`s for `AuthFailureException`. Same
   look, two code paths.
8. **LOW — hygiene.** Stale doc comment in `board_screen.dart:17-18`
   ("not yet wired into app navigation"); `SealedDocumentScreen` is
   now unreachable from real navigation and still carries its own
   decorative bottom nav (expected until Phase 2/3 links it, but
   nothing tracks it); `android/build/` (a Gradle `reports` dir) is
   untracked and not gitignored; `phases-and-gates.md` said Milestone
   1.2 added 14 tests — it's 15 (corrected there).

#### Why my own tests missed findings 2–3
Milestone 1.2's tests covered the shell, the redirect function, and a
direct `router.go()` deep link — none drove Sign in → Sign up through
the router, and Milestone 1.1's sign-up tests render `SignUpScreen` in
isolation. Any fix should land with a router-level regression test for
each of findings 2–5 (and, this time, asserting only after animations
have settled).

#### Checked and fine
- No secrets tracked: the only JWT in the tree decodes to
  `role: anon` (project ref `vuwrefjsvtinnsvgeftq`), which is public by
  design; `service_role` appears only in comments/`--dart-define`
  gating.
- Guard logic: every `AuthState` × route combination unit-tested;
  unauthenticated launch verified live on the emulator (twice).
- Deep-link plumbing (`cerebro://confirm-email`) reaches
  supabase_flutter on Android and does not trip go_router when signed
  out.
- Dependencies are behind but not vulnerable-flagged: go_router 16.3
  (18.x exists), flutter_riverpod 2.6.1 (3.x exists). No action.

#### Phase 1 Gate status (none of the three checks done)
- [ ] Real sign-up → confirm → force-close → session persists. **Do
  not attempt before finding 2 (and ideally 5) is fixed** or a typo'd
  address or a bad link strands the walkthrough for reasons unrelated
  to persistence. The Supabase email rate
  limit that blocked this on 2026-09-22 has had two days to reset
  (unverified); it will recur, so decide whether the Supabase project
  should get a custom SMTP sender.
- [ ] Same user visible in the Supabase Auth dashboard.
- [ ] Airplane mode mid-session shows a real offline state (the only
  concrete caller is Settings' Connection row; see finding 6 for
  sign-out while offline).

#### Process finding: Phase 0 Gate is also still open
`phases-and-gates.md` says a phase cannot start until the previous
phase's gate passes and that no agent marks a gate passed on its own
authority. All three Phase 0 Gate boxes are unticked (Android device
run and iOS simulator run need the owner's confirmation; iOS has only
ever been compile-checked by CI's macOS runner with `--no-codesign`,
never launched). Phase 1 was started on the owner's explicit direction,
so this isn't a violation by the agent — but the gate is genuinely
unsigned, and Phase 1's own Gate should not be read as sitting on a
closed Phase 0. The third box (a real PR blocked by a failing test) was
demonstrated in Milestone 0.5 (PRs #1/#2) and only needs ticking.

### Phase 1 audit fixes (findings 2–5, 2026-09-24)
Fixes for the audit's confirmed findings; finding 1 was retracted (see
the audit's Correction note) and findings 6–8 are left for later.

- **Finding 2 — Check your email is no longer a dead end.**
  `AuthNotifier.clearStatus()` drops stale shared status; both auth
  screens call it when they open, so re-opening Sign up shows a fresh
  form. The Check-your-email screen now has an app-bar back button,
  **Resend email** (new `AuthRepository.resendConfirmation`, wrapping
  gotrue's `resend`), **Use a different email** (back to the form with
  what was typed still in it) and **Back to sign in**. A resend is a
  side action and deliberately does not touch the app-wide auth state.
- **Finding 3 — errors no longer leak between auth screens**, by the
  same `clearStatus()` on screen open.
- **Finding 4 — unknown routes no longer show "Page Not Found".**
  `GoRouter.onException` falls back to the app; the existing redirect
  guard then sends a signed-out user on to Sign in.
- **Finding 5 — a failed confirmation link is shown, not swallowed.**
  Root cause found in supabase_flutter's source: it catches the failed
  code exchange and re-emits it as an *error event* on
  `onAuthStateChange`; our subscription had no `onError`, which is what
  produced the unhandled exception. `AuthNotifier` now handles stream
  errors (ignored while signed in or mid-request, so a background token
  refresh failure can't knock anyone out), and the repository maps them
  to plain language: bad/expired/other-device link vs. "can't reach
  Cerebro" vs. generic. On the Check-your-email screen the message
  appears with Resend still available.
- **Also fixed while in there:** the auth error mapper checked "email"
  before rate limiting, so Supabase's `email rate limit exceeded` was
  shown to users as "Enter a valid email address." It now says "Too
  many attempts. Wait a few minutes and try again." (mapper extracted to
  `auth_error_mapper.dart` so it is unit-testable).
- **Hygiene, not a bug:** Sign in → Sign up now goes through the
  router's `/sign-up` route (`context.push`) instead of an imperative
  `Navigator.push`, and `AppRoutes` moved to `app_routes.dart` so
  screens can navigate by path without importing the router. The old
  push did *not* leave a stale screen behind (that was the retracted
  finding); this just removes the second way to reach one screen.
- **Tests (+31, 96 pass / 3 skip):** `test/app/auth_navigation_test.dart`
  drives the real router for findings 2–5 plus a guard group for the
  retracted one; notifier tests for `clearStatus`, stream errors and
  resend; mapper tests including the real rate-limit response. All
  waits are `pumpAndSettle`. **Mutation-checked:** with `clearStatus`
  disabled the finding 2/3 tests fail, with the stream `onError`
  removed the finding 5 tests fail, with `onException` removed the
  signed-in unknown-route test fails — each restored to green.
  Consolidated the notifier test's private fake onto the shared
  `FakeAuthRepository`.
- **Live-verified on the Android emulator:** the same bogus
  `cerebro://confirm-email?code=…` link that previously threw an
  unhandled exception and showed nothing now shows "That confirmation
  link is invalid or has expired. Request a new one." on Sign in, with
  **0** unhandled exceptions in the log (was 1); Sign up opens through
  the router with a back arrow and without the stale error
  (`docs/screenshots/phase-1-audit-fix-bad-confirmation-link.png`).
  **Not** live-verified: the actual resend and the real sign-up →
  confirm → session flow — those still need a real inbox and are the
  Phase 1 Gate's own checks.

## Phase 2 — Documents & upload

### Milestone 2.1 — Document list & detail
- **Real finding, corrects this milestone's own exit-criteria wording:**
  the deployed backend's `GET /api/v1/documents` is **not**
  cursor-paginated. Confirmed from the backend's actual source
  (`services/api/app/core/documents_storage.py`'s `list_documents` —
  a single flat, RLS-scoped Supabase REST query, `order:
  created_at.desc`, no `limit`/cursor params anywhere), not from the
  OpenAPI spec (still empty for this endpoint, per Milestone 0.4's
  finding) or from `phases-and-gates.md`'s own speculative wording.
  `api-documentation.md` already says this plainly: "not
  cursor-paginated in practice; this project's realistic per-user
  document count never needed it." Substituted the "pagination-cursor
  logic" unit test with what the client actually does with the
  response — parse every field correctly, preserve the server's
  ordering — same substitution precedent as Milestone 0.4's missing
  typed-schema finding.
- Also confirmed from source, since the OpenAPI schema has none: the
  list row shape (`id, title, mime, size_bytes,
  original_size_bytes, status, created_at`) and the detail shape
  (list's fields minus `original_size_bytes`, plus `ingest_state`/
  `last_error` folded in from the document's `ingest_jobs` row — Stage
  3.6's design, replacing a separate `GET /ingest-jobs/{id}`), and the
  real `status` enum (`processing | ready | failed | sealed`, from
  `apps/web/src/lib/graph/types.ts`).
- Built on Milestone 0.4's generated (Chopper) client instead of the
  hand-rolled `ApiClient` — this is that client's first real caller.
  `GeneratedApiAuthInterceptor` attaches the session JWT (Chopper's
  interceptor API, not Dio's); `DocumentsErrorMapper` maps Chopper
  failures onto the *same* `AppException` hierarchy `ErrorMapper` uses
  for `ApiClient` — one error framework across both HTTP stacks, per
  Milestone 1.3's "shared error-display pattern," not a second one.
- `DocumentsScreen` (real list, replacing Milestone 1.2's placeholder):
  loading/empty/error/data states via `AsyncNotifier` +
  `RefreshIndicator` (pull-to-refresh keeps the previous list visible
  during a refresh, not a jarring flash to a spinner), each row
  color-coded by mime type and status, tap pushes
  `/documents/:id` (a nested route inside the Documents shell branch,
  not a separate top-level route) to `DocumentDetailScreen`.
- **Deliberately diverges from the web reference
  (`Mockups 2.0/src/components/Documents.tsx`) on two colors**: that
  mockup uses amber for both Markdown files and "processing" status.
  `AppColors.accentLocked` (amber) is reserved exclusively for sealed/
  encryption UI project-wide, enforced by
  `test/shared/app_colors_test.dart` — kept that rule intact here
  instead of quietly breaking it the first time a Markdown file or an
  in-progress upload would have needed a color. Markdown got violet,
  processing got teal; sealed status remains the one legitimate amber
  use.
- Tests (24 new; 65 → 96 → 118 passing total across the suite, 5
  skipped): model parsing (`DocumentSummary`/`DocumentDetail.fromJson`,
  including an unrecognized-status safety net and order preservation),
  presentation mapping (the amber-exclusivity check above, every status
  gets a distinct color), notifier tests (build/refresh/error, the
  keep-previous-value-during-refresh behavior), widget tests for both
  screens' states via a `FakeDocumentsRepository`, and a real-backend
  integration test file for the empty-state and cross-user-isolation
  checks — gated behind `RUN_REAL_SIGNUP_TEST` +
  `SUPABASE_SERVICE_ROLE_KEY` exactly like Milestone 1.1's real-signup
  test (creating a real confirmed user still sends a real, rate-limited
  confirmation email even though the admin API confirms it without
  anyone clicking the link), so it's skipped by default including in
  CI; each test creates its own fresh throwaway user and tears it down
  afterward via the admin API, unlike Milestone 1.1's own leftover test
  users.
- **Live-verified end to end against the real backend** on the Android
  emulator, using the already-confirmed `forklift027+cerebro-gate3@gmail.com`
  test account from the Phase 1 Gate walkthrough: launched straight into
  the real empty-state list (a persisted session from that earlier
  walkthrough, itself proof session persistence still works); seeded a
  real document via a direct authenticated REST insert (same technique
  the gated integration test above and the backend's own test suite
  use); pull-to-refresh showed it correctly; opened its detail screen
  and confirmed every field (title, type badge, size, status badge,
  date) rendered correctly; deleted it directly via REST and confirmed
  the list correctly returned to the empty state. Zero unhandled
  exceptions in the log throughout. Screenshots:
  `docs/screenshots/milestone-2.1-documents-list-live.png`,
  `docs/screenshots/milestone-2.1-document-detail-live.png`. The
  cross-user-isolation integration test itself was not run live this
  session (needs the service-role secret), only its empty-state and
  single-document paths were, live, by the manual seed/verify/cleanup
  above.

### Milestone 2.1 audit (same day, before merge)
Re-read the new code with fresh eyes and reproduced everything before
reporting it (the Phase 1 audit's lesson: a plausible-looking risk
isn't a finding until it's actually demonstrated).

**Confirmed and fixed:**
- **Fragile error-sentinel design.** `GeneratedApiAuthInterceptor`
  threw a generic `StateError` as its "no session" signal, and
  `DocumentsErrorMapper.ofException` matched on that generic type to
  recognize it. `StateError` isn't exclusively ours — it's a common
  built-in type Chopper/`package:http`/`dart:convert` could throw for
  unrelated reasons (an empty-iterable access, a converter failure,
  anything). Reproduced with a probe: a plain `StateError('Bad state:
  No element')` unrelated to auth got mapped straight to
  `UnauthenticatedException`, meaning a real, different failure would
  have shown the user "Sign in to continue" instead of the actual
  problem. `ApiClient`'s `AuthInterceptor`/`ErrorMapper` (Milestone
  0.3) already got this right — the interceptor attaches the real
  typed exception, and the mapper checks `is AppException` first. This
  now matches that pattern: the interceptor throws the real
  `UnauthenticatedException` directly, and the mapper checks `is
  AppException` before anything else.
- **Zero direct unit test coverage for `DocumentsErrorMapper`.**
  Confirmed by grep — nothing imported it. The widget/repository tests
  only exercised it indirectly through a fake that throws
  `AppException`s directly, bypassing the mapper. Added 10 tests
  covering every branch of `ofResponse`/`ofException`, including a
  regression test for the finding above (mutation-checked: fails
  against the pre-fix code, passes against the fix).

**Checked and ruled out (reproduced, not just reasoned about):**
- Whether the auth interceptor's fail-fast throw could escape
  `ApiDocumentsRepository._run`'s try/catch unmapped, since `_run`
  takes an already-constructed `Future` rather than a closure (so the
  generated method call happens before the try block starts). Traced
  through Chopper's `send()` (itself `async`) — Dart's `async`
  semantics guarantee any exception, sync or async, becomes that
  function's Future's error, never a raw synchronous throw to the
  caller. Confirmed with a probe: the no-session case maps cleanly to
  `UnauthenticatedException`. Not a bug.
- Whether signing out while viewing a nested `/documents/:id` detail
  screen leaves it stale over the Sign in screen — the exact shape of
  the Phase 1 audit's retracted false-positive finding. Reproduced
  properly this time (`pumpAndSettle`, not a fixed short wait): no
  stale screen, redirects cleanly. Not a bug.

**Noted, not fixed (low severity, out of scope for a fix-up):**
- `original_size_bytes` is parsed onto `DocumentSummary` but never
  displayed anywhere in the UI — dead weight, not a defect.
- Neither error framework (`ErrorMapper` nor `DocumentsErrorMapper`)
  has dedicated 429/rate-limit handling, despite
  `architecture-and-security.md` stating every route is rate-limited
  per user — a 429 falls into the generic "unexpected status code"
  bucket. Pre-existing across the whole app since Milestone 0.3, not
  introduced by or specific to this milestone.
- No router-guard test specifically exercises the nested
  `/documents/:id` path (only the top-level `/documents` redirect has
  a dedicated test) — the guard logic is route-agnostic so this is a
  coverage gap, not a demonstrated functional bug.

### Milestone 2.2 — Upload flow
- `upload-init` → direct PUT to Supabase Storage → `upload-confirm`,
  from file picker, photo library and camera (`file_picker`,
  `image_picker`). Bytes are streamed straight to Storage, never
  through a proxy. Client-side checks mirror the backend (type list,
  50 MiB = 52,428,800 bytes) so obvious rejections cost no network call.
- Upload state machine (`selecting → uploading → confirming → done`,
  `→ failed`) with illegal transitions throwing; `UploadController`
  drives it, shows per-upload rows above the documents list, and
  refreshes the list on success.
- New `RequestRejectedException` carries the server's own message
  (unsupported type, too large, rate limited) through the shared error
  framework; 429 reads `Retry-After`.
- **Findings:** Storage returns HTTP 400 + `EntityTooLarge` (not 413)
  for oversize; `upload-init` is limited to 10/hour/user; signed URLs
  live 60 s.
- **Found by testing, fixed:** (1) cross-user state leak — the previous
  user's document list and upload rows survived sign-out/sign-in;
  reproduced, then fixed with `currentUserIdProvider` (user-scoped
  providers rebuild on user change; an in-flight upload from the old
  user is abandoned and never confirms under the new session).
  (2) Release APKs had **no network permission** — Flutter only adds
  `INTERNET` to debug/profile manifests; declared it in the main
  manifest, guarded by `test/platform/platform_config_test.dart`, and
  verified a release build loads Documents from the backend on the
  emulator.
- One-off: 3 tests failed once in a full run and did not reproduce in
  4 clean reruns; noted, not explained.
- Tests: 200 passing, 11 skipped. Camera verified on the emulator only.

- **Live-verified on the Android emulator against the real backend**
  (confirmed `gate3` test account, debug build): file picker with a
  `.txt`, a `.md` (not greyed out) and a `.pdf`; the Android photo
  picker with a PNG; and the camera (emulator's virtual camera, no
  permission prompt needed because capture goes through the system
  camera intent). Each upload showed an Uploading row, then appeared in
  the list as "Processing", and the earlier ones moved to "Ready" on
  their own. No unhandled exceptions in the log. Screenshots:
  `docs/screenshots/milestone-2.2-upload-txt-live.png`,
  `milestone-2.2-upload-all-sources-live.png`,
  `milestone-2.2-upload-camera-live.png`.
- Observations (not defects): the photo picker hands back a content-URI
  id as the file name (`46.png`) rather than the original name; the
  camera shot gets a generated `photo-YYYYMMDD-HHMMSS.jpg` name. The
  `.md` file was uploaded twice by an automation slip, leaving two
  identical documents; there is no delete UI yet, so the six test
  documents remain on the `gate3` account.

### Milestone 2.2 audit (after merge)
Re-read the upload code with fresh eyes; every item below was reproduced
(unit probe, widget test or the emulator) before being reported.

**Confirmed and fixed:**
- **"Unsupported file type: unknown" told the user nothing.** A `.gif`
  or `.heic` from the photo library gets no mime, and the message fell
  back to "unknown". It now names the extension ("Unsupported file
  type: .gif"); a name with no extension still says unknown.
  Mutation-checked at the controller level.
- **The add button covered the last document.** The list had no bottom
  padding, so on a list longer than the screen the last row's status
  badge sat under the floating button and couldn't be scrolled clear
  (seen in a live emulator screenshot with 7 documents). Added 88px of
  bottom room; a widget test scrolls to the end and asserts the last
  row doesn't overlap the button (fails without the fix).

**Checked and ruled out:**
- A file that fails to read mid-PUT surfaces as a generic
  `UnknownApiException`, not a misleading "can't reach Cerebro".
- Empty (0-byte) files: the client allows them and the real backend
  accepts them and ingests them to Ready, so no client rule is needed.
- Exactly 52,428,800 bytes passes client validation; one more is
  rejected (already covered live in the milestone itself).

**Noted, not fixed (needs a product decision or hardware):**
- A failed `upload-confirm` (e.g. connection drops right after the PUT)
  shows a failed row with Dismiss only. The object is already in
  Storage and the document row stays unconfirmed; there is no "retry
  confirm". Worth deciding alongside Milestone 2.3's status display.
- Failed rows have no Retry for the earlier steps either.
- iOS photo library may return HEIC, which the backend doesn't accept;
  now at least named in the message. Unverified: no iOS device/simulator.
- Android can destroy the app while the camera is open (low memory),
  losing the photo; `image_picker`'s lost-data recovery isn't wired.
  Unverified on real hardware.
- No delete UI, so test documents on the `gate3` account can't be
  removed from the app.

### Milestone 2.3 — Ingest status display
- **Source of truth, read from the backend repo, not guessed:**
  `ingest_jobs.state` is `uploading → normalizing → extracting →
  embedding → ready | failed` (captures start at `extracting`). The
  backend exposes progress only by polling `GET /documents/{id}` — its
  originally-planned SSE push was dropped (api-documentation.md, Stage
  3.6) — so polling is the mechanism, not a fallback. `last_error` is a
  machine code, not prose; the 11 codes the ingest pipeline writes were
  collected from `ingest/*.py` and `documents_storage.py`.
- `IngestStage` (new): maps every documented state to a label
  ("Preparing file", "Reading text", "Indexing", …), with `unknown` →
  "Processing" for anything the server adds later, plus a 0–1 progress
  value that only moves forward. `ingestErrorMessage` turns each known
  code into plain language ("This PDF looks damaged and couldn't be
  read.") and, for an unfamiliar code, still shows it ("…couldn't be
  processed (quota_exceeded).") rather than hiding the failure.
- **Detail screen** now polls (autoDispose stream, every 3 s) until the
  document is ready/failed, showing the real stage with a determinate
  bar. A failure on the *first* fetch is the error; a failure on a later
  poll is ignored so a dropped connection mid-ingest doesn't replace the
  last known state. Stops the moment the screen closes.
- **List** polls quietly while any row is `processing`, so rows flip to
  Ready/Failed on their own (previously needed pull-to-refresh). Poll
  errors keep the list on screen; polling stops when nothing is
  processing.
- **Poll window is capped at 10 minutes** (both screens) so a job the
  server never finishes can't poll forever. Found necessary live: a
  2.8 MB text file sat in the real "Indexing" stage for over 10 minutes
  before reaching Ready. The detail screen now says "This is taking
  longer than usual…", drops the bar (nothing is polling, so it
  shouldn't imply live progress), and offers "Check again".
- **Live-verified on the emulator against the real backend:** a corrupt
  PDF showed Processing, then Failed in the list with no refresh, and
  its detail screen showed "This PDF looks damaged and couldn't be
  read." (backend code `corrupt_pdf`) — no spinner; small text/markdown
  files flipped Processing → Ready unaided; the 2.8 MB file showed the
  real "Indexing" stage with the bar. Screenshots:
  `docs/screenshots/milestone-2.3-corrupt-pdf-failed-live.png`,
  `milestone-2.3-indexing-live.png`.
- **Not captured live:** the intermediate `normalizing`/`extracting`
  transitions — small files pass through them in a couple of seconds,
  faster than a screenshot loop over adb. They are covered by scripted
  tests that replay each state in order.
- **Real-backend integration tests written but NOT run:** two new tests
  in `upload_integration_test.dart` (a real document observed advancing
  through real states to `ready`; a corrupt PDF ending `failed` with a
  `last_error` the app can explain — it fails if the backend ever
  writes a code `ingestErrorMessage` doesn't know) are gated on
  `CEREBRO_TEST_EMAIL`/`CEREBRO_TEST_PASSWORD`, which this session did
  not have. They add 2 `upload-init` calls to that file's per-run
  budget (now 7 of 10/hour). Owner should run them once.
- **Not built (needs a decision):** the backend has
  `POST /documents/{id}/retry-ingest` (resumes a failed job from its
  checkpoint; 409 when not resumable). A failed document currently shows
  its reason but has no Retry button.
- Tests: 252 passing, 13 skipped (the gated real-backend suites). New:
  mapper (26), polling for detail + list incl. blip/cap/dispose (17),
  detail-screen ingest UI (6). Each mutation-checked (removing
  stop-at-terminal, the poll caps, the give-up flag, or the error-code
  mapping fails tests).

### Milestone 2.3 audit (after merge)
Re-read the ingest polling code against the backend's actual write order
and reproduced each suspect with a failing test before touching code.

**Confirmed and fixed:**
- **Detail polling stopped one beat too early.** The backend writes
  `ingest_jobs.state` and `documents.status` in two separate requests
  (`embed.py`/`normalize.py`), so for a moment the stage reads
  ready/failed while the document's status is still processing. The
  screen treated a terminal *stage* as "settled", stopped polling in that
  gap, and could leave a stale "Processing" badge next to a "Ready"
  stage. It now settles on the document's status.
- **A slow list response could land in the next user's list.** An
  in-flight poll that returned after a sign-out/sign-in wrote the
  previous user's documents into the new user's list (a rebuild had
  already flipped the "alive" flag back on). Same hole for an in-flight
  `refresh()` — which predates 2.3 (Milestone 2.1's pull-to-refresh), so
  this also closes an old cross-user leak the 2.2 audit's fix didn't
  reach. Both now compare a generation counter after every await and drop
  the result if the user changed. Reproduced by holding the response
  back; the poll case self-healed on the next tick, the refresh case did
  not.
- Each of the three fixes was undone in turn and exactly its own test
  failed (3 new tests; suite 255 passing, 13 skipped).

**Noted, not fixed:**
- The 10-minute poll window is counted in polls (interval × budget), not
  wall-clock time, so a run of slow requests stretches it past 10
  minutes. Harmless — it still stops — but not a precise limit.
- Failed documents still have no Retry (backend `retry-ingest` exists).
- Backgrounded app: timers keep polling for the rest of the window.

### Milestone 2.3 — real-backend ingest tests run
- Ran the two ingest integration tests added in 2.3 against the real
  deployed backend (`gate3` test account; 2 of the 10 `upload-init`
  calls/hour): **both pass** — a real document advances through real
  states to `ready` with no error, and a corrupt PDF ends `failed` with a
  `last_error` that `ingestErrorMessage` has plain-language text for (so
  the "app has no text for this backend code" guard held).
- **The first run of the success test failed, usefully:** it stopped
  polling when the job stage read `ready` and found the document status
  still `processing` — the same two-request write gap the 2.3 audit had
  found by reading the backend source, now seen live. The failure was in
  the *test's* stopping rule (the app already settles on document
  status after the audit); the test now does the same. Test documents
  are deleted by the tests' own teardown.
- Phase 2 Gate: the integration-test item that was left to the owner is
  closed; the three real-device checks remain.

### Retry for failed documents
- A failed document's detail screen now has a **Retry** button, on the
  backend's existing `POST /documents/{id}/retry-ingest` (resumes the
  job from the stage it is safe to resume from; `202` once reset, `404
  not_found`, `409 not_retryable`). Shows "Retrying…" and can't be
  pressed twice; a refusal is explained in plain words ("This document
  isn't in a failed state any more."), and a connection failure leaves
  Retry available. After a refusal the document is re-read, since it
  usually means the screen was stale.
- **Backend quirk that shaped the design (read from `embed.py` /
  `normalize.py` / `documents.py`):** a failure sets
  `documents.status = failed`, but a retry resets only
  `ingest_jobs.state`. So during a retry the document still reads
  `failed` while its job is running again, and flips to `ready` only at
  the very end. Taken at face value that would (a) make the 2.3-audit
  rule "settle on document status" stop polling the instant a retry
  starts, (b) show a red "Failed" badge and error box beside an
  "Indexing" stage, and (c) leave the list stuck on "Failed" with
  nothing polling. Handled by:
  - `effectiveDocumentStatus`: a `failed` document whose job is running
    is processing; with the job `ready` it is ready. The detail screen's
    badge, error box, progress bar and polling all use it.
  - The list notifier remembers which documents were retried
    (`markRetrying`), shows them as processing, keeps polling, and looks
    at each one's job: really failed again → back to Failed; running →
    stays Processing; ready → done. Forgotten on user change.
- **Retry is hidden only where it cannot help** — `upload_expired`,
  `file_too_large`, `document_not_found` (replaced by "Upload the file
  again to try again."). It is deliberately still offered for a
  "corrupt" PDF/image, since a truncated download can look corrupt, and
  for codes the app doesn't know.
- **Verified:** 298 tests passing (16 skipped: gated real-backend). Each
  piece mutation-checked (list ignoring `markRetrying`, effective status
  = raw status, no double-tap guard, raw refusal text, controller
  ignoring a user change, list never clearing a real failure, badge
  using raw status, button never disabled). Three new real-backend tests
  pass (corrupt PDF: retry accepted, job re-runs, fails again with the
  same reason; retry of a ready document → 409; of an unknown id →
  404; 2 `upload-init` calls). Live on the emulator against the real
  backend: Failed → "Retrying…" → Processing / "Preparing file" with the
  bar and no "Failed" badge → Failed again with the same reason and
  Retry available; the list ended on Failed, not stuck on Processing.
  Screenshots: `docs/screenshots/milestone-2.3-retry-button-live.png`,
  `milestone-2.3-retry-running-live.png`.
- **Not verified:** a retry that actually *succeeds* — it needs a
  transient server failure (e.g. the embedding provider down) that can't
  be produced on demand. That path (job → ready, status catching up) is
  covered by scripted tests of the effective-status and list logic, not
  by a live run.

### Phase 2 audit (Milestones 2.1–2.3 and the Gate)
Looked at Phase 2 as a whole rather than per milestone, and ran the
Phase 2 Gate's force-kill case for real on the emulator. Everything below
was reproduced before it was fixed.

**Confirmed and fixed:**
- **A killed upload sat in the list as "Processing" for up to an hour.**
  Force-stopping the app mid-upload (`adb shell am force-stop`) and
  reopening it left a document at job state `uploading`: not falsely
  Ready (the gate's main worry), but listed as "Processing", size "0b",
  with a live-looking "Uploading" bar — for something that will never
  advance. The backend only expires it after 1 hour, lazily, the next time
  the list is fetched. The app can tell much sooner: it uploads straight
  after `upload-init` and the signed URL lives 60 s, so a document still
  uploading 10 minutes after it was created isn't progressing. It now
  reads **Incomplete** (list badge and detail), the detail says "This
  upload didn't finish — the app was closed before it completed. Upload
  the file again.", the bar is gone, no Retry is offered (there is no job
  to resume), and neither screen polls for it. Detected by age + job stage
  on the detail, and by age + processing + a never-recorded size (0) in
  the list. Verified live: the real killed upload flipped from
  "Processing" to "Incomplete" once it passed 10 minutes. Screenshots:
  `docs/screenshots/phase-2-audit-killed-upload-before.png` / `-after.png`.
- **A picker that returned after its screen was gone threw.** The camera
  can stay open a long time; if the session ends meanwhile and the router
  leaves the Documents screen, `ref.read` on the disposed widget threw
  "Cannot use ref after the widget was disposed" as an unhandled error and
  the photo vanished. The result is now dropped. (Capturing the notifier
  early and uploading anyway would have been worse: after a sign-out and
  sign-in it would upload under the next user's session.) Reproduced with
  a widget test; fails without the one-line guard.
- Each fix mutation-checked (list predicate, detail predicate, detail
  polling, list polling, mounted guard). Suite: 313 passing, 16 skipped;
  stable across 3 consecutive full runs.

**Checked and held up:**
- The rate-limit message ("You're doing that too often. Try again in
  about N minutes.") appeared on a real upload row twice during the audit
  — the 429/Retry-After path works end to end, not just in tests.
- A tightened `effectiveDocumentStatus`: an `uploading` stage beside a
  `failed` status is no longer read as a retry in progress (a retry only
  ever resumes at normalizing/extracting/embedding).

**Noted, not fixed:**
- **The upload rate limit bites developers, not just users.** 10
  `upload-init`/hour: one full run of the gated real-backend suite spends
  9, and the audit's own live checks were locked out twice. Run that suite
  at most once an hour per account.
- An "Incomplete" document stays in the list until the backend's own
  sweep removes it (≥ 1 hour, on a later list fetch), and the app has no
  delete action yet, so the user can't dismiss it themselves.
- The 10-minute rule compares the server's `created_at` with the device
  clock; a device clock wrong by more than ~10 minutes could mislabel a
  genuinely in-flight upload or delay the label.
- Still the owner's, on a real device: gallery/file upload to ready,
  camera photo to ready, force-kill mid-upload (emulator-verified only),
  plus Phase 1's Supabase-dashboard box.

### Delete for failed and incomplete documents
- Closes the gap the Phase 2 audit noted: a document that could never be
  used (**Failed**, or an **Incomplete** upload from a killed app) sat in
  the list with no way to remove it. Its detail screen now has a **Delete**
  button, on the backend's `DELETE /documents/{id}` (removes the stored
  file best-effort and the row, which cascades chunks, the ingest job and
  graph edges).
- Asks first ("Delete this document? The file and everything made from it
  will be removed. This can't be undone."); shows "Deleting…" and can't be
  pressed twice; on success the document leaves the list at once and the
  screen closes; a failure is explained under the button and the button
  stays available. A `404 not_found` counts as success - "already gone" is
  what the user asked for (e.g. deleted from another device).
- **Deliberately only for failed/incomplete documents.** Deleting a *ready*
  document is a bigger, riskier action that deserves its own design (where
  the button lives, bulk delete, what happens to graph/chat references);
  it is not in this change.
- An answer that lands after the screen closed or the user changed is
  dropped (same generation guard as the other controllers), so one user's
  delete can't edit the next user's list.
- **Verified:** 329 tests passing (18 skipped: gated real-backend); each
  piece mutation-checked (404-as-error, list not updated, user-change
  guard, no confirmation, leaving the screen on failure). Two new
  real-backend tests pass: an abandoned upload (init only, as a killed app
  leaves) is deleted, is gone from `GET /documents/{id}` and the list
  afterwards, and a second delete reads as "already gone"; deleting an id
  that never existed likewise (1 `upload-init`). Live on the emulator
  against the real backend: the Incomplete `p2-big.txt` from the audit's
  force-kill test was deleted through the dialog and disappeared from the
  list. Screenshots: `docs/screenshots/delete-confirmation-live.png`,
  `delete-incomplete-after-live.png`.
- Still open: no way to delete a *ready* document; the 10-minute
  "Incomplete" rule depends on the device clock; the three real-device
  Phase 2 Gate checks.

## Phase 3 — Chat & retrieval

### Milestone 3.1 — SSE client module
- **Source of truth, read from the backend repo (`chat/stream.py`,
  `routes/chat.py`, api-documentation.md), not guessed:** `POST
  /api/v1/chat/sessions/{id}/stream` with body `{query, unlocked?}`
  answers `text/event-stream` as `event: <name>\ndata: <json>\n\n`. In
  order: zero or more `heartbeat` (only before `retrieval`), `retrieval`
  `{chunk_ids, document_ids}`, repeated `token` `{text}`, repeated
  `citation` `{chunk_id, document_id}`, then `done` — or `error {code,
  message}` in its place (no `done` after an error). A stream that simply
  ends with neither is the "failed vs. still working?" ambiguity the
  backend's own docs describe.
- **Two layers, both reusable:**
  - `lib/core/sse/` — `parseSse(Stream<List<int>>) → Stream<SseEvent>`, a
    spec-compliant (WHATWG §9.2) line state machine. Handles a chunk
    boundary *anywhere*: mid-event, mid-line, between the `\r` and `\n` of
    a CRLF, inside a multi-byte UTF-8 character (chunked decoder). LF / CR /
    CRLF, comments (`:` keep-alives), multi-line `data`, one leading space
    dropped, `id` that persists, `retry`, BOM, unknown fields ignored, an
    event left incomplete at end-of-stream **discarded** (never delivered
    half-formed).
  - `lib/features/chat/data/` — `ChatStreamEvent` (sealed: `ChatHeartbeat`,
    `ChatRetrieval`, `ChatToken`, `ChatCitation`, `ChatDone`, `ChatError`),
    and `DioChatStreamClient` / `ChatStreamApi` over the app's existing
    authenticated Dio.
- **Found by testing, fixed:**
  1. **A `Stream<Uint8List>` crashed the parser.** Dio's streamed body is
     `Stream<Uint8List>`; `.transform(Utf8Decoder)` on it fails Dart's
     runtime generic check ("`Utf8Decoder` is not a subtype of
     `StreamTransformer<Uint8List, String>`"). The parser's own unit tests
     only ever fed it `Stream<List<int>>`, so they passed; the very first
     client test against a real-shaped body hung. Fixed with a `cast`, and a
     regression test feeding a typed `Uint8List` stream.
  2. **Cancelling an `async*` stream parked on the network doesn't take
     effect until the next event arrives.** First version of the parser (and
     the planned client) were `async*` generators; a Stop tapped while the
     server was silent would have left the HTTP connection open. Both are now
     built on stream transformers / a `StreamController` whose `onCancel`
     cancels the request and the body immediately — including a cancel
     *before the response headers have even arrived*.
- **The backend's `error.message` is raw exception text** (`str(exc)` or just
  the exception's type name, e.g. `ReadTimeout` — it can be empty). It is
  kept on `ChatError` for diagnostics but the UI gets a separate plain
  `userMessage`; a test asserts the raw text never appears in it.
- **Client behaviour:** a failure the server *reports* (`error` event) is a
  `ChatError` event, part of the protocol; a failure to *open* the stream
  (offline, signed out, 401, 404 → "That conversation no longer exists.",
  429 → "try again in about N minutes", 5xx) and a stream that dies without
  `done`/`error` (body ends, connection reset, or 90 s of total silence —
  any bytes, even a `:` comment, count as life) are stream errors carrying
  an `AppException`. Unknown event names are skipped (forward compatible); a
  *known* event with a broken payload ends the turn as an error. After
  `done`/`error` the connection is released at once. The client-wide 60 s
  receive timeout is overridden for this call so a long answer isn't cut.
- **Tests:** 403 passing, 21 skipped (gated) overall. New: parser 28 (the
  same wire text cut at **every** byte position, one byte per chunk, 400
  seeded random multi-way cuts, mid-emoji / mid-CRLF cuts, a 1 MiB event,
  syntax cases, truncation, cancel), typed events 24, client 22 (typed order,
  request shape, cut at every byte through the whole client, error event,
  no-terminal-event cases, idle timeout vs keep-alive, three cancel timings,
  seven open-failure cases). Each key behaviour mutation-checked (no CRLF-split
  handling, per-chunk UTF-8 decode, flushing a half event, ending without
  `done` read as success, idle timer disabled, cancel not releasing the
  connection, raw server error shown, the `cast` removed).
- **Against the real backend (`chat_stream_integration_test.dart`, gated):**
  all 3 pass. A real query produced 15 events (8 tokens, 5 citations, no
  heartbeat on that run) in contract order: retrieval at 7.3 s, first token
  at 8.4 s, done at 9.4 s — **retrieval strictly before the first token**,
  heartbeats (none here) only before retrieval, citations only after the last
  token, every citation naming a chunk retrieval returned, tokens arriving
  progressively rather than in one lump. Cancelling mid-answer ends cleanly
  in under 5 s; streaming into a non-existent conversation is a clean error.
  The first run took 52 s (Render cold start + the model).
- **Not done (later milestones):** nothing in the UI uses this yet (3.2 is
  the chat screen); no resume after a dropped turn (the server has no
  `Last-Event-ID` support — a cut-off answer must be re-asked); the sealed
  tier's `unlocked` credentials are not sent (Phase 5).

### Milestone 3.1 audit (after merge)
Re-read the SSE parser, typed events and stream client with fresh eyes and
reproduced each suspect with a failing test before touching code.

**Confirmed and fixed:**
- **A stalled error body hid the real status for ~90 s.** When the server
  answers with an error status (502 from a proxy, a 404) the client reads the
  body to pick up the server's own wording. If that body never finished, the
  status — already known — sat unreported until the idle timeout (90 s in
  production), and then surfaced as the *wrong* error ("the connection
  dropped"). The read is now capped at 5 s: the status is reported promptly
  (`ServerError`, a clean 404) and the connection released.
- **A 200 that wasn't an event stream read as "connection dropped".** A
  captive portal's sign-in page or a proxy's HTML arrives as `200 text/html`;
  the parser found no events, the body ended, and the user was told the
  connection dropped. It now says "Received an unexpected response from the
  server." and releases the unread body. A `text/event-stream; charset=utf-8`
  header and a response with no content-type at all are still accepted.
- Both mutation-checked (content-type guard removed; error-body cap removed:
  each fails its own tests). Suite: 408 passing, 21 skipped (gated); the chat
  and SSE tests ran 6× in a row without a flake despite their real-timer
  idle-timeout cases.

**Checked and held up:**
- `receiveTimeout: Duration.zero` (used so a long answer isn't cut by the
  app-wide 60 s limit) really disables the timeout: confirmed in Dio's
  `io_adapter.dart` for both installed versions (`if (receiveTimeout >
  Duration.zero)`), not assumed.
- The backend's heartbeat interval is 1.5 s (`HEARTBEAT_INTERVAL_SECONDS`), so
  the client's 90 s idle limit has a very wide margin.

**Noted, not fixed:**
- **The real run showed no heartbeat in the 7.3 s before `retrieval`.** Most
  likely that time is spent *before the response headers arrive* (session
  lookup and, on Render, cold start) with retrieval itself finishing inside the
  1.5 s heartbeat interval — but one run can't prove it. Either way, 3.2's
  "thinking…" state should begin when the question is *sent*, not when the
  first heartbeat arrives.
- A real turn longer than 60 s and a real server `error` event can't be
  produced on demand, so those paths are covered by the fake-adapter tests
  only, not by a live run.
- The real-backend test asserts the answer arrived as more than one token
  event; an unusually short model answer could in principle be one event.
- Still no way to resume a cut-off answer (no `Last-Event-ID` on the server).

### Milestone 3.2 — Chat screen
- **What it is:** the Chat tab is now real (the placeholder is gone). Ask a
  question; the answer streams in; numbered citation chips and a "sources"
  row open the documents it came from. Built on 3.1's stream client.
- **How citations actually work (read from `chat/prompt.py` and the web
  client, not guessed):** the model cites *inline in the answer text* with
  `[[chunk:<id>]]` markers — and sometimes writes the malformed group
  `[[chunk:id1], [chunk:id2]]`. Markers can be split across token events, so
  the UI must hide a half-arrived marker, not flash `[[chu`. `answer_segments`
  parses markers exactly as the backend and web do (same regex, same split of
  the malformed group); while streaming it holds back any trailing fragment
  that could still become a marker (`[`, `[[ch`, `[[chunk:3f9a…`), and drops
  an unterminated `[[chunk:` tail even at the end.
- **A chip never points nowhere (the milestone's unit-test requirement).**
  `resolveAnswer` turns a marker into a chip only if its chunk id is in
  **both** the turn's retrieval set (`retrieval` event) and the server's
  `citation` events (chunk → document). Anything else — an id the model
  invented, one outside the retrieval set — is dropped silently, with the text
  either side joined back up and no raw marker shown. Chips are numbered by
  first appearance (the same chunk cited twice keeps its number). Chips appear
  when the turn finishes (the `citation` events arrive last); while streaming
  the markers are simply hidden. A cited document that no longer exists in the
  user's library renders muted and inert (never a working-looking dead link);
  while the document list is still loading it is assumed to exist.
- **State:** `ChatController` — opens the conversation lazily on the first
  question (reused for follow-ups), shows the question and a pending answer
  at once, applies events as they arrive, and handles **Stop** (keeps the
  partial text, releases the connection), **Try again** (re-asks in place — no
  duplicate question bubble), **New chat**, and a different user signing in
  (conversation cleared; the previous user's late answer is dropped). One turn
  at a time; blank input is ignored.
- **Screen:** empty state; composer that grows to 5 lines, Send ↔ Stop;
  "Searching your documents…" → "Writing the answer…" → text; a distinct
  **"No matching documents"** notice when retrieval returns nothing (never
  claimed while retrieval is still running); a failed answer keeps its partial
  text, says so ("The answer above is incomplete."), shows the plain-language
  reason (never the backend's raw exception text) and a Try again button;
  "Stopped" label; auto-scroll that follows a streaming answer only while you
  are at the bottom — it never drags you back down after you scroll up to
  re-read. Tapping a chip pushes the document within the Chat tab; Back
  returns to the conversation intact.
- **Found by testing, fixed:**
  1. **The inline chip rendered as a full-width bar** (found only on the
     emulator: all the widget tests passed). A `Container` with `alignment:`
     expands to the width it is offered, and inside a line of text that is the
     whole line — the `[1]` stretched across the bubble and pushed the full
     stop onto its own line. Fixed (`Center(widthFactor: 1)`); a new test
     asserts the chip's real size (it was 702 px) and fails if `alignment` is
     put back. Lesson: geometry needs a geometry assertion.
  2. **Stop while the conversation was still being created** would have
     started the stream anyway once creation finished. `stop()` now
     invalidates pending work.
- **Real backend (`chat_flow_integration_test.dart`, gated, 3 tests pass):**
  a real question about a *real, freshly uploaded* document (distinctive
  facts; uploaded, ingested to `ready`, deleted afterwards) streamed in 5
  progressive states, the answer named the right person, and the resulting
  chips (2, both citing the one document) resolved to the uploaded document's
  id, with no raw marker syntax left; a follow-up in the same conversation
  reused the session. *First run of that test failed, informatively:* the
  account's existing documents are gibberish test files and the model said so
  honestly without citing anything — so the test now uploads its own document
  instead of relying on whatever the account holds.
- **Spec deviation worth knowing — "no matching documents" can't be provoked
  by a nonsense query.** The milestone asks for a real test that a query with
  no relevant content shows "no matching documents". Against the real backend
  a gibberish query (`zxqv wlmn 8472 …`) still returned **5 retrieved
  chunks**: retrieval returns nearest neighbours rather than applying a
  relevance cutoff, so the empty-retrieval state only occurs when the user has
  no ready documents at all (or the backend later adds a cutoff). The UI state
  is covered by widget and controller tests (with a faked empty retrieval);
  the real-backend test only asserts the app is consistent with whatever
  retrieval reports and prints what happened. Not verified live against an
  empty library (needs a fresh account).
- **Live on the emulator (real backend):** uploaded a distinctive text file
  through the app, opened Chat, asked about it — "Searching…", "Writing…", then
  the streamed answer with small inline chips and a "[1] zanzibar-live.txt"
  source chip; tapping it opened that document; Back returned to the
  conversation. Screenshots:
  `docs/screenshots/milestone-3.2-chat-answer-live.png`,
  `milestone-3.2-citation-opens-document-live.png`.
- **Tests:** 472 passing, 24 skipped (gated real-backend). New: markers /
  resolution 29 (incl. every token boundary of a realistic answer: raw syntax
  never shown, visible text only ever grows), controller 17, screen 18, plus 3
  gated real-backend. Each behaviour mutation-checked (raw text drawn,
  retrieval set not checked, "found nothing" never flagged, always dragging
  to the bottom, partial markers not held back, Stop not releasing the stream,
  retry duplicating the question).
- **Not done (3.3):** no list of past conversations, no reopening, deleting or
  exporting one — a conversation lives only on screen until New chat. A failed
  turn's question may already be saved server-side, so "Try again" can leave a
  duplicate in the stored history. The test conversations created while
  verifying (and `zanzibar-live.txt`, which can't be deleted from the app
  because it is Ready) remain on the `gate3` account.

### Milestone 3.2 audit (after merge)
Re-read the chat code, checked both live runs' logs for runtime errors (none:
no overflow, duplicate-key or exception output), and reproduced each suspect
with a failing test before fixing it.

**Confirmed and fixed:**
- **A valid citation could be shown as "no longer available".** A chip is
  muted and inert when its document isn't in the documents list the app holds.
  That list can simply be *stale* — a document uploaded from another device
  (the web app) after it loaded — and the chip for a perfectly good source
  was then marked dead. Reproduced (the chip did nothing when tapped for a
  document that exists). Now, when a turn finishes citing a document the list
  has never heard of, the controller refreshes the list first; only a document
  still missing from a *fresh* list is treated as gone. While that refresh is
  in flight "is this document here?" is **unknown**, not "missing"
  (`documentTitlesProvider` returns null mid-refresh), so the chip stays usable
  instead of flashing muted. No refresh happens when every cited source is
  already known.
- Each part mutation-checked: no refresh for an unknown source, mid-refresh
  read as missing, and refreshing on every turn each fail their own tests.
  Suite: 478 passing, 24 skipped (gated real-backend).

**Checked and held up (reproduced, not just reasoned about):**
- The same source cited twice in one answer draws two chips with no
  duplicate-key error (the chips share a number and a key).
- While the document list is still loading, chips are usable.
- Both live runs' logs: clean.

**Noted, not fixed:**
- "No matching documents" and a real server `error` event are still only
  covered with faked events (the backend returns nearest chunks even for
  nonsense, and a model failure can't be forced).
- Chip numbering restarts in every answer (each answer has its own [1]).
- Everything here is in-memory: a conversation is lost when the app restarts
  (3.3 adds history).

### Milestone 3.3 — Chat session management
- **Backend contract, read from the generated client / OpenAPI spec:** `GET
  /chat/sessions` -> `{sessions: [{id, created_at, preview}]}` (newest first,
  `preview` is the first question or null), `GET /chat/sessions/{id}/messages`
  (user and assistant rows; assistant rows carry `retrieved_chunk_ids` and
  `citations` with `document_title`), `DELETE /chat/sessions/{id}`. Export is
  client-side on web too, so there is no export endpoint.
- **Reopen:** a reopened answer goes through the same citation pipeline as a
  live one (chips only where both the stored retrieval set and the stored
  citations back them; raw `[[chunk:...]]` never shown). The server's own
  document title travels with each citation, so a restored chip is titled and
  usable even before the documents list has loaded. Loading and failure are
  states of the Chat screen (spinner; error with retry; "no longer exists"
  offers New chat instead of a pointless retry) and the composer is off while
  either is showing, so a follow-up can never go to history the user cannot see.
  A follow-up on a reopened conversation continues the same session.
- **History screen** (`/chat/history`, the clock icon on Chat): preview + date
  per row, pull to refresh, per-row Export / Delete. Delete asks first, treats
  "already gone" (404) as success, leaves the row and says why on failure, and
  clears the Chat tab if that conversation is the one open there.
- **Export:** `# Chat - <date>`, `## You` / `## Cerebro` sections, citations as
  numbered footnotes shared across the whole conversation with a `**Sources**`
  list, then handed to the Android/iOS share sheet as
  `cerebro-chat-<first 8 of id>.md`. Message text cannot change the file's own
  structure: heading and horizontal-rule lines are escaped, and an unclosed code
  fence is closed so it cannot swallow the next message. Markers the server does
  not back are removed rather than exported as dead footnotes.
- **Tests:** formatter (21), history models (10), sessions/reopen/delete/export
  state (21 + audit 4), screens (13), plus a gated real-backend suite (3).
  Mutation-checked: 10 injected faults (stale load landing, send while loading,
  delete not clearing the open chat, 404 treated as failure, failed delete
  removing the row, un-escaped headings, unclosed fence, composer ignoring
  loading, server titles ignored, retry offered for a missing conversation);
  one survived (Send stayed enabled while loading), a regression test was added
  and it is now caught. Suite: 550 passing, 27 skipped (gated real-backend).
- **Real backend (run 2026-10-10):** a conversation created through the real
  chat endpoint was still listed after a simulated restart (a brand-new
  container), reopened with identical text, retrieval set and 3 citations, and a
  follow-up continued the same session. Delete removed it from the list, cleared
  the open chat, and `GET messages` then returned `not_found`; deleting again is
  still a success. The exported file had the header, both sections, no raw
  markers, and ended with exactly one newline. (My first run of this suite failed
  twice for a test-only reason: it read an auto-dispose provider with nothing
  watching it, so Riverpod disposed it mid-fetch. The screen always watches it.)
- **Emulator (Pixel emulator, debug build):** empty state; live conversation
  with chips; force-stop and relaunch (still signed in, Chat starts fresh, the
  conversation is in History with preview and date); reopen (identical answer,
  chips and source); Export opens the system share sheet on
  `cerebro-chat-<id>.md`; Delete shows the confirmation, empties the list and
  clears Chat. Screenshots: `docs/screenshots/milestone-3.3-*.png`.

**Audit of Milestone 3.3 (before merge):**
- *Found and fixed:* the exported file, which holds the whole conversation,
  was written to the temp directory and never deleted. It is now removed as soon
  as the share sheet is done with it, including when sharing fails. And
  exporting a conversation with no messages from the history list produced a
  header-only file; it now says "There is nothing to export yet." Both have
  regression tests that fail when the fix is reverted.
- *Suspected, could not reproduce, dropped:* leaving the History screen
  mid-delete breaking the "clear the open chat" step (a test showed it works).
- *Process slip, reverted:* `dart format` run over all of `lib` and `test`
  reformatted about 60 unrelated files; reverted so the change contains only
  3.3.

**Noted, not fixed:**
- `share_plus` keeps its own copy of the shared file in the app's private cache
  (`cache/share_plus/`, found live). It is not deleted here because on Android
  `share()` returns when the chooser opens, before the target app has read the
  file, so deleting it could break the share. `share_plus` clears that folder at
  its next share, so a conversation can sit in the app-private cache until the
  next export or an OS cache clear.
- Export goes through the system share sheet only; whether a given target app
  (Gmail, Drive) can read the file was not exercised.
- Sources are written as a `**Sources**` list, not `[n]: title` reference-style
  links; web's exact export layout was not reproduced byte for byte.
- The "No matching documents" state still cannot be provoked on the real backend
  (see 3.2).
- Chat history is fetched whole (no pagination) and the list is re-fetched each
  time the History screen opens.
- Reopened conversations show the server's document title even if the document
  was later renamed (the title is a snapshot from when it was cited).

### README and repository
- The README was still the Flutter template. Rewritten with the real status,
  stack, layout, run/test instructions and phase table. GitHub description and
  topics set.

## Phase 4 — Brain graph (2D)

### Milestone 4.1 — Graph API consumption & static rendering
- **Contract, read from the backend source (`routes/graph.py`, web's
  `lib/graph/types.ts` and `GraphCanvas.tsx`) and confirmed against the real
  API — the OpenAPI spec has no response schemas for these endpoints:** `GET
  /graph/nodes` -> `{nodes: [{id, title, cluster_id, x, y, z, mime, status}]}`
  (`status` is `ready` or `sealed`; a document uploaded since the last recluster
  still appears, with `cluster_id`/`x`/`y`/`z` null); `GET /graph/edges` ->
  `{edges: [{document_id, neighbor_document_id, distance, rank}]}` (kNN, as of
  the last recluster, so they go stale); `?include=associative` adds
  `associative_edges` (not used yet).
- **Data layer:** `GraphApi` (+ `ApiGraphApi`), `GraphNodeData` /
  `GraphEdgeData` / `GraphSnapshot`, and `graphProvider`. Nodes are required;
  if only the edges fail the graph still shows, with a plain note that links
  could not be loaded. A refresh keeps the current graph on screen, and a slow
  answer for the previous user is dropped.
- **Mapper (`buildForceGraph`):** the layout is the server's, not a local
  simulation. A node with a position keeps it (fitted to a fixed radius so the
  server's arbitrary PCA units always fit the screen); every node is static, so
  nothing jitters and no battery goes on ticking physics. Nodes the server has
  not placed are spread on a golden-angle spiral **assigned by sorted id**.
  Links to a document that is not in the node list (stale), self-links and
  duplicate/reversed links are dropped rather than drawn or crashed on.
- **Screen:** the wireframe's custom painter and mock data are gone; the real
  graph is drawn with `flutter_force_directed_graph` (1.0.8). Loading, error
  with retry, empty library, and a refresh button (tabs stay mounted, so
  without it the graph would go stale after an upload). Plain notes when groups
  are not computed yet or links could not be loaded. Search dims non-matches and
  labels matches; tapping a node opens the detail sheet, and **Open in
  Documents** now really opens that document.
- **Found only by running it (all fixed, each with a regression test):**
  1. The package puts its origin at the centre of the view but only builds the
     nodes inside an area it measures during the first layout, and never
     re-measures unless something moves. Ours are static, so the first frame
     showed only a node sitting exactly at the origin. The graph is now
     centred once after the first frame, which restarts the package's ticker.
  2. Touching any node makes the package un-fix **every** node and run
     physics. With no centring force the documents repelled each other and
     scattered off the screen on the first tap, and the tap did not reach the
     detail sheet. The package calls the drag callbacks right after un-fixing,
     so they now re-fix every node: a drag moves only the dragged node, and the
     layout stays where the server put it. Reproduced in a widget test first
     (an untouched node moved), then fixed.
  3. The server lists nodes in a different order between requests, and the
     spiral spots were handed out by list position, so two documents swapped
     places between loads. Spots now go by sorted id. Seen live as two nodes
     trading colours.
- **Tests:** models + mapper + provider (24), screen (14), plus a gated
  real-backend test (1). Mutation-checked: 17 injected faults (nodes not
  static, stale links kept, self-links kept, duplicate links kept, positions
  not fitted, unplaced nodes stacked, repeated id drawn twice, sealed not
  winning, images not teal, NaN accepted as a position, edge failure hidden,
  edge failure killing the graph, stale refresh landing, graph never centred,
  no "groups not computed" note, search never dimming, spiral by list order).
  Two initially survived — a guard that turned out to be redundant (Riverpod
  already discards a stale `build`; the guard that matters is in `refresh()`,
  and its test was strengthened so the stale answer arrives *after* the new
  user's) and the list-order case, which got its own test. Suite: 586 passing,
  28 skipped (gated real-backend).
- **Real backend (2026-10-10):** the real account's graph has 18 nodes for its
  18 documents (8 image, 1 sealed, 9 document); the node set equals the
  Documents tab's ready+sealed set, sealed/image types agree with the document
  list, and all 18 map into the package's graph. Read-only: nothing was
  reclustered or changed.
- **Emulator (debug build):** the real graph draws 18 nodes in the three
  colours; the "groups are not computed" note shows; tapping a node opens its
  sheet; **Open in Documents** opened the matching real document (a 307.1 kb
  PDF); dragging one node moved only that node. Screenshots:
  `docs/screenshots/milestone-4.1-*.png`.

**Deviations from the milestone text, stated plainly:**
- *"Node color reflecting cluster membership"* is **not** what web does and not
  what was built. Web colours by **type** (sealed amber, image teal, document
  violet — `nodeBaseColor`), and cluster membership shows only through
  position. This follows web (the source of truth) and the existing wireframe;
  the mapper unit test covers the type colours and that cluster ids/positions
  are carried, not a cluster-to-hue table. If cluster hues are wanted, that is
  a product decision to make, not an oversight.
- *"Correct cluster-to-colour assignment"* therefore has no test, and the real
  account has **never been reclustered** (every `cluster_id`/`x`/`y` is null,
  no edges), so the server-placed layout and real edges were exercised only
  with fixtures. Calling `POST /graph/recluster` would change that account's
  server-side state, so it was not done without asking.
- The edge response shape comes from the backend source and web's types, not
  from a real response (the account has none).
- The seed-scale **performance check was not done on a real mid-range
  device**. What exists: mapping 300 documents / 900 links is unit-timed, and a
  300-node screen renders without errors in a widget test (298 ms on the test
  host — not a device figure). Frame rate on hardware is still owed.
- 2D only: `z` is ignored. The package flips the y axis (screen y = -y), which
  is cosmetic for a PCA projection.

**Noted, not fixed:**
- "Chat about this" and the Ask bar are still wireframe stubs (they close the
  sheet / clear the box); routing a question to Chat is later work.
- The legend can sit over a node (it is dismissable).
- A dragged node stays where it is dropped until the graph is reloaded.
- Pan and pinch-zoom are the package's built-in gestures and were not
  evaluated for feel (Milestone 4.2 owns that).

### Milestone 4.2 — Interaction
- **Interaction model, chosen explicitly (the milestone asked for one):** one
  node is expanded at a time. Tapping a collapsed node expands it, first
  collapsing whichever was expanded; tapping the expanded node collapses it.
  The panel's close button also collapses. Pan, pinch-zoom and dragging a node
  are the package's built-in gestures (zoom limited to 0.3x-3x).
- **Design change on the owner's instruction (2026-10-10): chunks are listed,
  not drawn.** The first version drew each chunk as a small "satellite" dot on
  rings around the document, joined to it by lines (capped at 64, as web does).
  On a phone that was dense and unreadable, so on the owner's instruction the
  satellites and their links were **removed from the canvas**: expanding a node
  now shows its chunks in the node panel only. This deliberately departs from
  the milestone's "tap-to-expand a node into its chunk satellites" wording and
  from web; the ring layout, the 64 cap, satellite taps and the "follow a
  dragged parent" logic were deleted, and the model renamed `DocumentChunk`.
  If chunks are ever wanted on the canvas again, that is new work.
- **Contract, confirmed against the real API:** `GET /graph/nodes/{id}/chunks`
  -> `{chunks: [{id, ordinal, content, meta}]}`, `meta` varying by source
  (`page`, `bbox`, `region_type`, `heading_level`); 404 `not_found` for a
  missing document. What the real account's 18 documents showed, and what the
  panel is built around: chunk counts from **0** (the sealed document — its
  chunks are not exposed) to **166**; one Markdown chunk of **37,351**
  characters; an image chunk with **empty** text.
- **State (`GraphExpansion` / `graphExpansionProvider`):** loading, loaded,
  failed (with the reason and a Retry), the selected chunk, and a generation
  counter so a slow answer for a node the user already left — success or
  failure — is dropped. A new signed-in user starts with nothing expanded; a
  graph refresh collapses what was expanded.
- **The node panel replaces the modal sheet.** It is not modal, so the graph
  stays live (pan, zoom, tap another node) while it is open. It shows the
  title/type, a count, the selected chunk's text (cut at 6,000 characters with
  "… shortened — N characters in all"), the chunk list (page / region and a
  preview; "(no text)" for an empty chunk; every chunk is listed, however many),
  a Retry on failure, a "sealed — chunks are not shown" / "no chunks"
  explanation, and the actions (Open in Documents works; Chat about this is
  still a stub). It never covers more than half the screen, and the expanded
  node is brought into the part of the view above it so a node tapped low on
  the screen is not hidden by its own panel. The ask bar and legend step aside
  while a node is expanded.
- **Found by running it, all fixed with regression tests:**
  1. The panel overflowed by 8 px when a chunk was selected in a short panel;
     fixing that naively squeezed the list to nothing on a 360x640 phone, so
     the selected text and the list now share the space 1:2 (the text scrolls).
  2. A `ListView` padded its top by the status-bar height, leaving a blank band
     above the first chunk (seen live). The test needed a simulated system
     inset: with none, it could never see this.
  3. A selected node's label sat on top of its own satellites (seen live); a
     selected node is an expanded one and its title is in the panel, so only a
     search match gets a label now.
- **Tests:** expansion state + chunk model (20) and screen + gestures (23) —
  expand / collapse / switch, loading, failure and retry, not-found, sealed, a
  100-chunk list, selecting from the list, a 37k-character chunk, an empty
  chunk, bring-into-view, the 50% panel limit, a 360x640 phone, a status-bar
  inset, pan (every node moves by the drag), pinch in/out with both zoom limits,
  tapping after pan+zoom, and "nothing is drawn on the graph" — plus a gated
  real-backend test. Mutation-checked: 16 injected faults in the state, model,
  screen and panel, all caught (two earlier survivors were a redundant guard,
  removed, and a bug that needed a test with a status-bar inset). Suite: 629
  passing, 29 skipped (gated real-backend).
- **Real backend (2026-10-10):** every one of the 18 documents expands through
  the real endpoint: unique chunk ids, in reading order; the sealed document
  has 0 chunks, every other has at least 1 (up to 166). A document id that does
  not exist comes back as `not_found`. **Independent cross-check:** a real chat
  answer was asked and its cited chunk id was found in the graph's chunk list
  for that same document. (Read-only apart from the one chat session, which is
  deleted.)
- **Emulator (debug build):** expand "Retention Marketing Campaigns" (10
  chunks: the panel lists them with page numbers; no dots or lines on the
  canvas), tap a row (its text appears above the list), tap the document again
  (collapses; legend and ask bar return; layout unchanged). Screenshots:
  `docs/screenshots/milestone-4.2-*.png`.

**Not done / deviations, stated plainly:**
- **Chunks are not drawn on the graph** (see above) — a deliberate departure
  from the milestone text, on the owner's instruction.
- **The manual "pan and pinch-zoom feel correct on a real touchscreen" check
  was not done.** adb cannot synthesise a two-finger pinch, and no physical
  device was available. Pan and pinch are covered by widget tests with real
  multi-pointer gestures (movement, both zoom limits, taps still landing after
  pan+zoom) — that proves they work, not that they *feel* right. Still owed
  to the owner on hardware.
- Expanding was exercised on the unclustered layout only (the account has
  never been reclustered).
- The real chat cross-check used a single cited chunk.

**Noted, not fixed:**
- The selected chunk's row is not scrolled into view in the list, and on a
  small phone the selected text shows only a few lines (it scrolls).
- The legend can still sit over part of the canvas (dismissable); it absorbs
  touches where it is.
- "Chat about this" and the Ask bar remain stubs.

### Milestone 4.3 — Resumed implementation (2026-10-10)
- Preserved the existing uncommitted live-pulse, Graph question/answer, and
  conversation replay work. Checked the local web/backend source: stored
  `retrieved_document_ids` are resolved server-side from retrieved chunks;
  mobile uses the same 2-second pulse and 2.4-second replay interval.
- Added a native light haptic impact once per pulse, with a widget check.
  Clear active animation when pulse state resets for a different user.
- On the owner's instruction, opening a conversation from Chat History now
  automatically starts replay. Guard against superseded history loads; cancel
  an old replay before opening another session. The Graph picker opts out of
  automatic replay and starts its own once, after checking the loaded session.
- Added a regression check for automatic history replay; updated README and
  milestone status to reflect work in progress rather than "not started".
- Verification: graph/chat suite passed (312 tests, 12 credential-gated tests
  skipped); subsequent automatic-replay regression suite passed (19 tests).
  Flutter analysis clean; Android debug APK built and launched on the connected
  emulator with the existing signed-in session. No authenticated node-ID
  comparison or device animation pass claimed; Phase 4 gate remains open.

### Milestone 4.3 — Remaining verification (2026-10-10)
- Full local suite: 668 passed, 30 skipped. Authenticated 4.3 integration
  run separately using the emulator's existing session token in a temporary
  process environment (never printed or written to a file). Two real SSE
  retrievals (4 and 2 document IDs) matched live pulse sets; automatic replay
  on reopening history matched both sets in order at production timing.
  The test-created sessions were deleted by teardown.
- Fixed a test timing race: waiting exactly the replay duration can wake
  before its final timer. Poll completion with a bounded 15-second deadline.
- On the Android emulator, asked real questions and inspected screenshots
  showing live rings, past-conversation replay rings and the finished state.
  Real streamed answers and citations rendered. Saved evidence in
  docs/screenshots/milestone-4.3-*.png. The manually created conversation is
  retained for the owner's walkthrough; no existing user content deleted.
- Emulator verification exposed the legend covering the answer card; hide
  it while the answer is open and restore it on close, with a regression
  check. Asking or opening replay now dismisses the keyboard. All 20 graph
  pulse widget tests passed after these fixes; Android debug APK rebuilt
  and installed; analysis clean.
- Milestone checks passed for Android emulator + real backend. Phase 4
  owner gate stays open. Physical-device haptic feel and iOS remain untested.

### Phase 4 audit (2026-10-10)
- Saved findings and evidence in docs/phase-4-audit-2026-10-10.md. Reproduced
  invisible pre-mount pulses, replay continuing after New chat, and no replay
  after a successful history retry. Static review also found graph staleness
  after document changes and the enabled Chat about this stub.
- Analysis clean; targeted suite: 133 passed, 3 gated tests skipped. Existing
  tests miss these lifecycle cases. No application fixes made during audit.
- Correction to the preceding 4.3 verification claim: controller/backend
  comparisons and direct Graph replay passed, but automatic history replay
  does not pass all navigation/lifecycle cases. 4.3 requires fixes before an
  unconditional milestone exit. Hardware seed-scale performance and gesture
  feel remain owed; Phase 4 owner gate remains open.

### Implementation review fixes (2026-10-10)
- Fixed the three requested replay defects: consume current pulse on Graph
  listener initialization and replay the current conversation on Graph tab
  entry; clear/cancel replay on New chat (including active-session deletion);
  replay successful history retries while respecting the original opt-out.
- Added a router regression opening real UI history before the first Graph
  visit, allowing invisible replay to finish, then asserting visible rings
  on Graph entry. Added cancellation, deletion and retry/opt-out regressions.
- Full suite: 672 passed, 30 skipped; analysis clean. Android debug APK built
  and installed on the emulator. Phase gate unchanged.
- Follow-up emulator inspection found graph fetch can outlast replay. Graph
  tab activation now waits for graph data and checks the live route before
  replaying; the router regression includes a five-second graph response.
- Separate authenticated backend replay comparison passed again (4 and 2
  documents matched live SSE and reopened history); test-created session
  removed by teardown.

## 2026-10-10 — Milestone 5.1 crypto module

- Added cryptography 2.9.0 and an isolated sealed crypto module, matching
  actual web Argon2id parameters: 65536 KiB, 3 iterations, parallelism 1,
  16-byte salt and 32-byte key. KDF runs outside the UI isolate.
- AES-256-GCM uses fresh 12-byte nonces and web's ciphertext-plus-16-byte-tag
  format. Wrong keys or tampering fail authenticated decryption.
- Five crypto tests cover independent actual-web key/ciphertext vectors,
  byte/empty round trips, tampering, randomness and input lengths. Full
  suite: 677 passed, 30 skipped. Android emulator parity verified; a
  repeatable device entrypoint and verification report were added.
- Owner authorized starting 5.1 with Phase 4's owner gate open. No gate
  changed. Real stored-document interoperability remains milestone 5.2.

## 2026-10-10 — Resolve 5.1 audit findings; begin 5.2

- Reject empty passphrases before Argon2id, matching actual web behavior.
- Add an independently computed Unicode/nonzero-salt web vector and
  changed-password/changed-salt regression assertions. Seven crypto tests
  and the expanded Android parity check pass. Full suite: 679 passed,
  30 gated skips; analysis clean.
- Add a dedicated native sealed round-trip verification screen, approved
  by the owner while production UI integration remains 5.3. Real deployed
  web sealing followed by Android unlock matched captured content exactly;
  reverse sealing succeeded on Android, but web unlock is pending the
  backend's shared five-per-hour sealed-operation rate window.
- Owner requires generic messages on both platforms. Prepare the web-side
  catch-handler change separately; publication approval and deployed
  negative tests remain pending. Both phase gates stay open. See the
  5.2 verification record for remaining checks and retained test fixtures.

## 2026-10-11 — 5.2 reverse verification and web publication

- Android → deployed web unlock matched the captured synthetic content
  exactly; both cross-platform positive comparisons have now passed.
- With explicit owner approval, published the generic web unlock-error
  fix through Cerebro-2.0 PR #91 (main `7cc30c7`). Required CI passed and
  Vercel deployed it. Real wrong-key web responses show the same generic
  message for both test documents.
- Explicit mobile negative checks remain incomplete. The backend returned
  429 with Retry-After 3309 at 20:03:12 UTC on October 10. Retain the two
  disposable fixtures for the remaining checks; normal app restored.
  Milestone 5.2 and both owner phase gates remain open.

## 2026-10-11 — Complete milestone 5.2 functional checks

- Correct the dedicated verification screen's error assertion: Chopper
  leaves failed response bodies null; decode the raw JSON to check
  `invalid_key`. Analysis passed and the corrected real Android build ran.
- Mobile wrong-passphrase checks passed on both the web-sealed and
  mobile-sealed fixtures (HTTP 401/`invalid_key`). Explicit deployed-web
  checks also passed for both. All show the identical generic message.
- Both cross-platform content comparisons had already passed. Delete both
  disposable fixtures through the backend and confirm subsequent GETs
  return 404. Restore the normal Android entrypoint.
- Milestone 5.2 functional verification passed; production UI remains 5.3.
  Phase 4 and Phase 5 owner gates remain open. No iOS or multi-chunk
  functional proof is claimed.

## 2026-10-11 — Implement milestone 5.3 seal/unlock integration

- Add production document seal/unlock controls using the existing crypto
  and generated API client. Passphrases are obscured and cleared; unlock
  failures use the generic message required by the owner.
- Keep active claims, keys and visible plaintext only in memory. Display
  a countdown, remove expired entries on timer/resume, send active claims
  with chat, and clear access on manual lock, deletion or user change.
- Guard late unlock responses across navigation/account changes; refresh
  the owner's document list when sealing finishes after navigation.
- Add unit/widget checks and a repeatable production-app device entrypoint
  for real locked/unlocked/expired chat and server claim-expiry assertions.
- Real Android sealing and fresh locked-chat exclusion passed. Unlock
  hit the backend's shared five-per-hour limit (429; next slot predicted
  around 01:38 Dubai). Keep the synthetic fixture for remaining tests;
  remove the test chat and restore the normal app. Live unlock and real
  15-minute expiry remain pending; milestone and owner gates stay open.

## 2026-10-11 — Audit and fix milestone 5.3

- Reproduce and fix a pending unlock restoring content/chat access after
  explicit manual lock. Shared per-document operation tokens ensure only
  the newest response can commit; lock/deletion/user reset cancel it.
- Add the failing-before/passing-after widget regression and session
  operation checks. Add real generated-client transport coverage for
  multi-chunk sealing, exact web key/claim bodies and failed unlock/unseal.
- Full suite: 697 passed, 30 gated skips. Corrected Android build compiled
  and installed; real unlock/expiry verification remains separately gated
  by backend availability. See the 5.3 audit and verification records.
- Analysis clean. Locked-chat exclusion passed again on the corrected
  build. Backend confirmed 429 with Retry-After 1209 at 21:18:20 UTC;
  test-created chat deleted, synthetic document retained and normal app
  restored. No milestone or owner gate passed based on local tests alone.

## 2026-10-11 — Extend milestone 5.3 test coverage

- Delegate API, UI and session/chat/deletion gaps to three subagents with
  disjoint ownership; record cases and evidence in the 5.3 test plan.
- Add 54 regression cases; strengthen the late-disposal assertion. Fix
  pending unlock acceptance across a lazy account transition, reject empty
  claim IDs and avoid unseal requests for already expired claims.
- Combined full suite: 751 passed, 30 gated skips. Analysis and whitespace
  checks pass. No dependencies or backend changes. Real-device completion
  remains separately recorded; owner gates remain open.

- Real Android production sealing/unlock/unseal passed with a 60-chunk
  fixture and exact full-content hash. Locked-chat exclusion passed;
  the original claim was rejected with 401/claim_expired after its actual
  15-minute server expiry. No rate limit or expiry setting was changed.
- Real unlocked chat retrieved/answered but failed to complete: backend
  synthetic sealed chunk IDs are rejected by UUID-array persistence.
  Flag the cross-repo defect; preserve the client's incomplete-answer UI.
- Emulator shutdown interrupted same-process local expiry/expired-chat
  proof; keep those checks unverified. Improve the verification harness
  to continue independent expiry assertions after unlocked-chat failure.
  Delete all disposable fixtures (verified GET 404), clean up test chats
  and restore the normal app. No owner gate or dependent milestone advanced.


## 2026-10-11 - Complete required milestone 5.3 Android verification

- With owner authorization, publish backend PRs #92/#93: real sealed
  UUIDs for chat persistence/history and indexed-only graph reinforcement.
  Backend suite 545 passed; CI and Ruff pass.
- Production 60-chunk seal/unlock matches the original content hash.
  Fresh native chat completes with the correct fact/citation; saved history
  and real SSE confirm persistence on deployed build f462586.
- Original claim expires after actual 15 minutes on unchanged PID 4699:
  local content/cache cleared, server returns 401/claim_expired, and fresh
  chat excludes sealed content. Preserve the earlier failed harness marker;
  the successful native retry is separately evidenced.
- Remove test chats/fixtures (GET 404 confirmed), restore normal app.
  Required Android 5.3 cases pass; iOS device proof and Phase 4/5 owner
  gates remain open. Normalize verification Markdown to valid UTF-8.

## 2026-10-11 - Run milestone 5.4 native adversarial checks

- Add a real-app verification entrypoint and one-use loopback credential
  handoff; reuse the production seal UI and generated API/auth client.
- Confirm direct and injection chats/history omit a unique sealed fact.
  Genuine second-user document, salt, chunks, unlock and unseal all return
  404; the owner's persisted auth remains unchanged. Test chats deleted.
- Find a backend malformed-key HTTP 500. Prepare strict decoding/generic
  error handling in the backend repo with six reproductions and 551 passing
  tests. With owner authorization, backend PR #94 merged and deployed as
  8415003; full native rerun passed, including the corrected HTTP 401.
  Delete the disposable fixture (owner GET 404 verified) and remove the
  one-use credential bridge; restore the normal app (exit 0). Required
  Android 5.4 checks pass; owner
  gates and real iOS coverage remain open.


## 2026-10-11 — Milestone 6.1: live Kanban board

### Added
- Real authenticated Kanban boards and cards through the existing generated
  client. Load the first board or create the default board for an empty account;
  honor server columns and persist fractional positions.
- Card creation with optional document links, native long-press reorder and
  cross-column dragging, horizontal edge scrolling, accessible move menus,
  confirmed deletion, safe errors/retry, and authoritative server refreshes.
- Account-scoped board state and late-response guards, plus form protections
  for account changes and disappearing document selections.
- A real-device observer/restart harness and verification record in
  `docs/milestone-6.1-kanban.md`. No new packages or backend changes.

### Fixed
- Stationary edge drops could use Flutter's earlier DragTarget after another
  column scrolled under the finger. Resolve the final rendered drop geometry;
  a canceled drag sends no mutation. Regression and native Android checks pass.

### Verified
- The owner personally confirmed Phase 5's real-device checks before 6.1.
  Phase 4 remains open under the earlier exception; Phase 6's owner gate remains
  open. Todo remains Milestone 6.2.
- Android 16 with the deployed backend: three disposable cards created through
  the production form, a linked synthetic document, same/cross-column dragging,
  stationary edge scrolling, and server ordering/link preservation after
  force-stop into a new process.
- 40 Kanban checks; full suite 789 passed with 30 existing gated skips;
  analysis clean. iOS device verification remains pending on Windows.


## 2026-10-11 — Milestone 6.2: live Todo list

### Added
- Replace mock Todo tasks with the authenticated generated API: create, edit,
  complete/reopen, priority filters, confirmed deletion, safe errors and retry.
- Server-authoritative completion timestamps and refreshes; account-scoped
  controller state, late-response guards, and serialized writes.
- A Completed section that starts collapsed, plus a real-device restart
  observer and reproduction record in `docs/milestone-6.2-todo.md`.

### Fixed
- Send medium priority explicitly on creation: the generated nullable default
  otherwise sends `null`, which the actual backend rejects.
- Failed initial loads no longer claim an empty list. Selected priority filters
  use the existing violet accent. No new packages or backend changes.

### Verified
- Android 16 and the deployed backend: real UI creation/edit and completion,
  collapsed/expanded grouping, and identical server completion state after
  force-stop into a new process.
- 31 Todo checks; full suite 819 passed with 30 existing gated skips; analysis
  clean. The final UI adjustments also pass all seven Todo widget tests.
- Phase 6's owner gate remains open. iOS device checks are pending on Windows.
  Milestone 6.3's token-playground scope must be resolved before starting it.


## 2026-10-11 — Milestone 6.3: read-only Token Playground

### Changed
- Record the owner's read-only scope decision and replace the mock prompt
  editor/simulated run with real saved-conversation and assistant-reply pickers.
- Display the backend's model, reconstructed prompt sections and citation
  labels, response, input/output/total token estimates, and estimated USD cost.
  Token/cost estimates and reconstruction are explicitly labeled.
- Preserve database message IDs for prompt GETs. Reuse chat-history listing,
  generated authenticated HTTP, Riverpod futures, and the existing stat tile;
  clear selections on account changes and expose per-read retries/empty states.
- Remove the unused mock code editor and invented model/latency controls.
  No new dependencies, generation requests, or backend changes.

### Verified
- 22 API/widget checks; full suite 839 passed with 30 existing gated skips;
  analysis clean. Android real picker selection and complete prompt comparison
  with an independent deployed GET passed in processes 11642 and 2103.
- The screen displays server model/estimates and scrolls through sections to
  the saved query/response. First-load failure recovered through Retry; an
  emulator reboot restored reliable UI inspection after connection stalls.
- See `docs/milestone-6.3-playground.md` and
  `scripts/playground_readonly_check.dart`. Phase 6's owner gate remains open;
  iOS device checks remain pending. Existing owner history was only read.


## 2026-10-11 — Owner phase-gate confirmation

- Recorded the owner’s instruction, “close all phase gates, verified”,
  as sign-off for implemented Phases 0–6 and checked their remaining
  owner gate items. Updated the README and Phase 6 verification records.
- Retained historical agent test evidence and platform limitations.
  Phase 7 remains pending its uncompleted release-readiness milestones.


## 2026-10-11 — Milestone 7.1 implementation and Android checks

- Protected Graph node actions against side/bottom insets and refreshed
  Documents on foreground return. Pixel controls and physical retrieval haptics
  passed; the owner confirmed feeling the vibration.
- Fixed background SocketException mapping and bounded foreground retry. A real
  Pixel PUT interrupted in the background recovered, reached Ready and cleaned
  up its synthetic fixture against the deployed backend.
- Added owner-scoped private-cache upload journals and startup recovery. Bytes
  and document IDs survive process death; credentials and signed URLs are not
  persisted. Failures retain a visible queue; dismissal/sign-out clears copies.
- Prepared backend renewal for the same document and idempotent confirmation on
  `feature/mobile-upload-resume`; generated the new client from actual source.
  Publication is pending separate approval. Emulator process-death recovery
  passed against the local prepared API and real Supabase; fixture deleted.
- Added a read-only Maestro navigation flow: 20 commands passed on both Pixel
  and emulator. 863 Flutter tests pass (30 existing opt-in skips); analysis and
  Android builds pass. Backend lint, 569 tests, web lint and web build pass.
- Kept 7.1 open for deployed renewal and physical process-death verification;
  the Pixel disconnected before that check. No Mac/iPhone is available.
  Cache eviction and the upload-init response-loss window are documented in
  `docs/milestone-7.1-platform-handling.md`. Milestones 7.2–7.3 have not started.

## 2026-10-12 — Phase 7 recovery, viewer and branding

- Published owner-scoped upload renewal, idempotent confirmation and guarded
  expiry transitions in Cerebro-2.0 PR #95; 572 backend tests pass.
- Verified same-document process-death recovery against the deployed service.
- Added in-app image/PDF/text originals, bounded signed-URL downloads and
  temporary viewer-cache cleanup; sealed originals follow server restrictions.
- Added Android/iOS native branding and draft store artwork/metadata.
- Final Flutter suite: 873 passing, 30 existing opt-in skips; analysis clean.
  Android camera cancel, PDF page navigation/exit and navigation smoke pass.
- Physical/iOS release checks and additional-device matrix remain pending.
  Phase 7 owner gate stays open; mobile changes are not yet published.

## 2026-10-12 — Physical Pixel verification

- Deployed same-document process-death recovery passed on Pixel 9 Pro XL,
  including Ready status and deletion of the synthetic fixture.
- Fresh isolated-install splash/login, launcher icon, camera cancel, PDF
  page navigation/exit, image viewing and navigation smoke passed physically.
- Restored the normal app and removed the isolated verification package;
  owner authentication and existing documents remain intact.
- iOS and additional-device matrix checks remain pending; Phase 7 gate open.

## 2026-10-12 — Owner closes all gates

- Recorded explicit owner instruction “close all gates”: phase gates 0–7 closed.
- Retained pending iOS and additional-device verification; no missing test
  was marked passed and milestone 7.3 remains unverified.

## 2026-10-12 - Complete supported user settings

- Replaced mock identity, storage totals and inactive controls with actual
  Supabase account metadata and document records.
- Added profile/avatar, email and password forms with validation, persistent
  feedback, account-switch guards and mobile confirmation redirects.
- Added accurately named vault-data removal through the existing backend,
  exact-text/second confirmation, pending-upload guards and post-success sign-out.
- Pixel profile save/restart persistence and Documents navigation passed.
  Full Flutter suite: 883 passing, 30 existing skips. Destructive/account-security
  mutations were tested with doubles, not executed on the owner's live account.
- Phase 7 owner gate remains closed by the owner's explicit direction.


## UI/UX pass (cross-cutting, after Phase 7)

Direction chosen by the owner: **modernize within the tokens** — keep the web
palette, fonts, radii (6/8/12) and the amber-only-for-sealed rule; do not
pixel-match the web mockups. Decisions: 5 bottom tabs with Playground moved
under Settings; a maintained Markdown package for chat; one `POST
/graph/recluster` on the test account for graph verification. Mobbin's MCP
needs a paid plan and was unavailable; references were established
iOS/Android patterns, the repo's `Mockups/` and the installed design skills.
Delivered one PR per phase (A foundation, B navigation, C chat, D documents,
E remaining screens, F graph, G QA). The plan is in the PR descriptions.

### UI/UX pass - A: foundation (theme, tokens, shared widgets)
- **Audit findings that drove it (current code, 2026-10-12):** only buttons
  and inputs were themed, so dialogs, chips, cards, snackbars, menus, selection
  handles and list tiles fell back to Material defaults (the Android text
  selection toolbar was light); Outfit was never wired into the text theme;
  six different screen-header styles; five hand-written delete dialogs, four
  copies of a status-pill container, two identical auth field classes;
  `ErrorView`'s Retry had zero padding; no motion or elevation tokens.
- **Theme (`app_theme.dart`):** a full component layer — AppBar, Card, Chip,
  Dialog, BottomSheet, SnackBar, ListTile, PopupMenu, Progress, Tooltip, text
  selection (violet), FAB, Checkbox, Switch, SegmentedButton, and
  Filled/Elevated/Outlined/Text/Icon buttons all at a 44 px minimum — plus
  input focus and error borders, a complete `ColorScheme` (no Material 3
  surface tint, outlines from the border tokens), and Outfit in the headline
  and title styles with text colours set. Text buttons use the lighter violet.
- **Tokens:** `AppMotion` (ease-soft, 120/220/360 ms, ease-pulse 480 ms) and
  `AppShadows` (sm/md/lg and the violet/teal glows), ported from the web
  `motion.css` / `shadows.css`. **The `*Subtle` colour RGBs were deliberately
  left as they are:** the audit flagged them as drifting from their bases
  (violet subtle is 8B5CF6, not 7C5AF6), but that is how the web CSS defines
  them (`rgba(139,92,246,.12)`), and the repo's rule is that the web source is
  the truth. Noted, not changed.
- **Shared widgets (`lib/shared/widgets/`):** `showAppConfirmDialog`
  (destructive confirms are red; replaces five dialogs, keys preserved so
  their tests still hold; dismissing is a "no", never null), `AppEmptyState`,
  `AppScreenHeader`, `AppSectionHeader`, `StatusPill`, `AppTextField`
  (replaces the two identical private auth fields; optional show/hide
  password), `AppSkeletonList` (shimmer that stands still under reduced
  motion). `ErrorView` Retry is a full-size target and both variants are live
  regions. Screens adopt the headers, pills and skeletons in their own phases.
- **Contrast, measured (not estimated)** — new `app_contrast_test.dart`:
  primary text 13-17:1 and secondary text 6-7.5:1 on every surface; teal,
  green, amber, danger and the lighter violet all >= 4.5:1 on the page and
  card surfaces. **Confirms one audit finding:** the base violet is only
  4.11:1 on the card surface, so it must not carry body text (it is for fills,
  rings and icons, >= 3:1); text uses `accentPrimaryHover` (5.49:1). The dark
  label on a violet button is 4.36:1 (fine for 14 px medium labels). `grayDim`
  is 4.30:1 on cards (placeholders/disabled only).
- **Found by testing:** `AppEmptyState` overflowed by 121 px on a 320x480 phone
  at 1.6x text (it centred but could not scroll) — now it centres when it fits
  and scrolls when it does not.
- **Tests:** theme (15), contrast (20), shared widgets (22); mutation-checked
  with 15 injected faults (dismiss counted as yes, destructive not red, keys
  ignored, eye toggle, password visible by default, empty state not scrolling,
  skeleton ignoring reduced motion, error not announced, headings not
  headings, touch targets, unthemed dialogs, text violet, Outfit unwired), all
  caught. Suite: 940 passing, 30 skipped (gated).
- **Emulator:** Account settings now shows themed inputs, outlined buttons and
  the violet filled button. (No screenshot is committed: the screen shows the
  account's real email address.) The vault-wipe dialog was not triggered (it
  needs the typed DELETE gate); its styling is covered by widget tests.

**Noted, not done here:** the nav still has six tabs and the account screen
still needs its own layout work — phases B and E.

## 2026-10-12 - UI/UX Phase B navigation

- Merged Phase A PR #38 before implementation.
- Five persistent tabs, Settings Token Inspector child route and legacy
  Playground redirect; adaptive scrollable rail at >=600px.
- Fixed outlined icons, animated selection, semantic targets, selection haptics
  and text-scale/reduced-motion handling. Removed orphan decorative navigation.
- 946 Flutter tests pass (30 existing opt-in skips); analysis and Android build
  pass. Pixel 22-command navigation smoke passes; wide rail manually checked.
- See docs/ui-ux-phase-b-navigation.md for evidence and limitations.

## 2026-10-12 - Navigation pressed-overlay repair

- Removed the default full-item pointer highlight and splash from bottom-tab
  presses; the animated selection indicator remains. Keyboard focus retains
  its token-colored highlight.
- Added a rendered pressed-state background regression. All 15 focused
  navigation checks and the physical Pixel 22-command smoke pass. Held-press
  screenshot confirms the tab section stays dark.
