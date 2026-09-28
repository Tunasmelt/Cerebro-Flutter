# Changelog — Cerebro Mobile

Format: date, what changed, why. Append, don't rewrite history — if a
decision gets reversed later, the reversal is a new entry, not an edit
to the old one.

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
