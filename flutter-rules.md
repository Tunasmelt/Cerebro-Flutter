# Cerebro Mobile — Flutter Rules

Flutter/Dart-specific conventions. General architecture lives in
`architecture-and-spec.md`; project-wide non-negotiables live in
`CLAUDE.md`. This file is the one most likely to go stale as Flutter
itself evolves — treat anything version-specific below as a starting
point to verify, not a frozen fact.

---

## State management

Pick one and use it everywhere — the worst outcome here is two patterns
coexisting because different screens were built at different times.
Given the app's shape (server-authoritative data, no complex local
client state beyond in-flight forms), `Riverpod` is the reasonable
default: testable without a widget tree, no BuildContext plumbing for
async server state, and it plays well with a generated API client's
Future/Stream-based methods. If the agent building this has a strong
existing preference, that's a legitimate reason to deviate — just pick
one before the second screen is built, not after the third disagrees
with the first two.

## Project structure

```
lib/
  core/           auth session, API client instance, error types,
                  the sealed-tier crypto module
  features/
    auth/
    documents/
    chat/
    graph/
    sealed/
    kanban/
    todo/
    playground/
  shared/         design tokens, shared widgets
```

One feature = one folder with its own `data/`, `domain` (if needed),
`presentation` split. Don't let `core/` become a dumping ground —
anything feature-specific belongs in that feature's folder even if it
feels small.

## Design tokens

Port the palette and type scale from `ui-design-prompts.md`'s Design
System section directly — same violet/teal/amber semantic meaning
(amber reserved exclusively for sealed/locked state, no exceptions),
same monospace-for-numbers rule. Don't reinvent the visual language for
mobile; a user moving between web and mobile should recognize it as the
same product, not a reskin.

Mobile-specific additions the web tokens don't need:
- Safe-area handling for notches/home indicators on every full-bleed
  screen (the graph view especially, since it wants to use the whole
  screen).
- Touch target minimums (44×44 logical pixels, platform convention) —
  the web design's small citation chips and node-click targets need a
  mobile-specific minimum size, not a direct pixel-for-pixel port.
- Haptic feedback on the retrieval-pulse moment — a mobile-native
  enhancement web can't offer, worth deliberately adding rather than
  treating haptics as decoration.

## Networking

- One HTTP client instance (`dio` or the generated client's own
  transport), not one instantiated per call.
- Every request attaches the Supabase session JWT via an interceptor,
  not manually at each call site — a single point of failure is safer
  than N call sites that can each independently forget it.
- Token refresh is `supabase_flutter`'s job; don't hand-rewrite refresh
  logic.
- SSE parsing (chat streaming, retrieval events) needs its own tested
  module — see architecture-and-spec.md §5. Test it against a real
  chunked response, not a mocked single-shot JSON body; SSE bugs live in
  the chunking behavior, not the payload shape.

## Error handling

- Never show a raw exception or stack trace in the UI — same rule as
  web. Map backend error codes (`sealed_locked`, etc.) to specific,
  plain-language messages; don't fall through to a generic "something
  went wrong" for errors the backend already classified.
- Network-unreachable and server-error-response are different states
  with different UI — don't collapse "no internet" and "server said no"
  into the same error widget.

## Platform-specific gotchas worth knowing up front

- **iOS**: `cryptography_flutter`'s native acceleration path differs
  between Android and Apple platforms — confirm both are actually
  exercised in testing, not just one and assumed for the other.
- **Android**: background execution limits mean a long-running upload
  or ingest-status poll can be killed if the app backgrounds — confirm
  the upload flow tolerates being resumed rather than restarted from
  scratch if the OS kills the process mid-upload.
- **Both**: biometric-gated re-entry to an unlocked sealed session
  (Face ID / fingerprint to re-confirm within the 15-minute window) is
  a natural mobile-native enhancement — worth considering once the base
  sealed-tier parity is proven, not before.

## Testing

- Widget tests for every screen's core interaction, not just golden
  (pixel) tests — a screen that renders correctly but doesn't respond
  to a tap correctly passes a golden test and fails the actual product.
- Integration test for the full upload flow against a real (test)
  Supabase project — same "prove it live" discipline as the backend's
  own stage gates, not a mocked-storage unit test standing in for it.
- The sealed-tier cross-platform round-trip test (§4 of the
  architecture doc) is not optional and not covered by any other test
  in this list — write it explicitly.
