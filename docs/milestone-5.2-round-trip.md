# Milestone 5.2 — cross-platform verification passed

Started 2026-10-10, after resolving both 5.1 audit findings. Owner approved
a dedicated device verification screen, keeping production UI integration
in 5.3, and explicitly requires generic failures on both platforms.
Completed functional verification on 2026-10-11. Phase 4 and Phase 5
owner gates remain open.

## What has actually passed

- Seven 5.1 crypto tests pass, including empty-password rejection,
  Unicode/whitespace with nonzero salt, and independent changes to salt
  and password. Full Flutter suite: 679 passed, 30 gated skips.
- Android 16 emulator independently verified the original web vectors,
  the Unicode/nonzero-salt vector, and empty-password rejection.
- Two disposable text documents were uploaded through the real signed-URL
  flow and ingested by the deployed service. Their original chunks were
  captured before sealing. Each had one chunk, including café,
  Arabic text, emoji, punctuation and whitespace; no multi-chunk functional
  proof is claimed by this run.
- **Web → mobile passed:** the actual deployed Documents page at
  `https://cerebro-web-ten.vercel.app/` sealed the first document. The
  Android verification screen derived its key from the stored salt,
  obtained a real unlock claim, and fetched unsealed content. Sorted
  `(ordinal, content)` JSON matched the original baseline exactly.
- **Mobile negatives passed on both documents:** wrong passphrases returned
  HTTP 401 with explicit `invalid_key`, at 00:38:29 and 00:39:17 Asia/Dubai
  on October 11. Both showed `Couldn't unlock this document. Try again.`
- **Mobile → web passed:** Android sealed the second real document
  with one document salt/key and fresh chunk nonce. The deployed web app
  subsequently unlocked it; its returned chunk matched the captured
  baseline exactly.
- **Web negatives passed on both documents:** deployed web returned HTTP
  401 with explicit `invalid_key` and the identical generic message.
  This covers wrong input on the sealing platform and the opposite
  platform for each document.
- The corrected verification entrypoint compiled and ran on Android;
  `flutter analyze` passed. Chopper keeps failed responses outside `body`;
  the negative assertion now decodes the raw response JSON. Both checks
  emitted `MILESTONE_5_2_WRONG_PASSPHRASE_REJECTION_PASS`.
- Both disposable documents were deleted through the real backend. Each
  DELETE returned its expected ID and `deleted: true`; subsequent GETs
  returned 404. The normal Android app entrypoint was restored.

Evidence:

- [Web sealed](screenshots/milestone-5.2-web-sealed.png)
- [Mobile exact comparison](screenshots/milestone-5.2-mobile-unlocked.png)
- [Mobile sealed](screenshots/milestone-5.2-mobile-sealed.png)
- [Web exact comparison](screenshots/milestone-5.2-web-unlocked.png)
- [Web generic failure, mobile-sealed document](screenshots/milestone-5.2-web-generic-mobile-to-web.png)
- [Web invalid-key rejection, web-sealed document](screenshots/milestone-5.2-web-wrong-web-to-mobile.png)
- [Web invalid-key rejection, mobile-sealed document](screenshots/milestone-5.2-web-wrong-mobile-to-web.png)
- [Mobile invalid-key rejection, web-sealed document](screenshots/milestone-5.2-mobile-wrong-web-to-mobile.png)
- [Mobile invalid-key rejection, mobile-sealed document](screenshots/milestone-5.2-mobile-wrong-mobile-to-web.png)
- [Deployed web rate-limit message](screenshots/milestone-5.2-web-rate-limited.png)

## Rate-limit history and verification correction

Actual backend `services/api/app/core/rate_limit.py` shares a limit of
**5 requests per user per hour** across `/seal`, `/unlock`, and `/unseal`.
Both successful directions alone require six requests. This run spent
five: web seal, mobile unlock, mobile unseal, mobile wrong-key attempt,
mobile seal. Subsequent requests returned 429. No limit was bypassed or
backend behavior changed.

The backend returned `Retry-After: 3310` at 2026-10-10 19:27:21 UTC.
That header originally predicted a slot around 2026-10-11 00:23
Asia/Dubai. Requests were accepted earlier; the reason was not verified.
The reverse positive and web negatives then completed. The mobile
negative check again emitted `MILESTONE_5_2_VERIFICATION_INCOMPLETE`.
A follow-up backend request at **2026-10-10 20:03:12 UTC** returned 429
with `Retry-After: 3309`, predicting a slot around **2026-10-11 00:58:21
Asia/Dubai**. Further slots expire separately. Do not repeatedly retry
while limited. At that point the mobile negatives remained unverified.
On the follow-up run, the service accepted requests around 00:38
Asia/Dubai; the reason for the earlier availability was not verified.
Both corrected mobile checks and the explicit web mobile-sealed check
passed. No backend limit or deployment configuration was changed.

The earlier mobile assertion read `unlock.body`, which Chopper leaves
null for failed responses. This was a verification-harness defect that
could also report incomplete for a valid 401. Reading the raw JSON now
allows checking `invalid_key`; logs expose only HTTP status and outcome,
never passwords, keys or tokens. Earlier generic UI observations alone
were not counted as negative passes.

The deployed web previously exposed backend messages (observed during this
run: `Too many requests for seal_unseal`), and its previous source displayed
`Incorrect passphrase` for an invalid key. The owner requires generic
messages, so a separate fix was implemented in `Tunasmelt/Cerebro-2.0`, branch
`fix/generic-sealed-unlock-errors`, in
`apps/web/src/app/documents/page.tsx`. Its catch handler now always shows
`Couldn't unlock this document. Try again.`
Lint, 13 crypto tests, and the production web build pass. A browser test
against that local production build with simulated `invalid_key` confirms
generic presentation. This is a presentation test, not a real-backend
negative pass. After explicit owner publication approval, the fix was
committed as `ad89c49`, merged through
[PR #91](https://github.com/Tunasmelt/Cerebro-2.0/pull/91) into main as
`7cc30c7`, and deployed by Vercel. Required API and web CI checks passed.
The actual deployed UI then displayed the generic message for real
wrong-key responses, as recorded above.
The local-only presentation evidence is
[generic message with simulated wrong key](screenshots/milestone-5.2-web-local-generic-web-to-mobile.png).

## Repeatable device check

```
flutter run -d emulator-5554 -t scripts/sealed_round_trip_check.dart
```

Sign in through the normal app first. Use only disposable ready documents.
Enter a document ID and choose **Read baseline** before sealing. The screen
keeps the expected chunks in memory and ties them to that ID. Changing the
ID requires another baseline; restarting the screen loses its baseline.

For web → mobile, seal on deployed web, then enter the same passphrase on
the device and choose **Unlock and compare**. For mobile → web, choose
**Seal on mobile**, unlock on deployed web, and compare returned chunk
ordinals/content with the previously captured baseline.

**Verify wrong passphrase rejection** does not require a baseline. It
counts as passing only for HTTP 401 with `invalid_key`, emits
`MILESTONE_5_2_WRONG_PASSPHRASE_REJECTION_PASS`, and displays a generic
message. Authentication errors, 429s, or other failures emit
`MILESTONE_5_2_VERIFICATION_INCOMPLETE`; the generic UI alone is not proof.
No passphrases or keys are logged or persisted by the screen.

The two test documents were deleted after verification. Their original
synthetic baselines and IDs remain in ignored `dev-logs/m52-fixtures.json`
as local evidence; these IDs cannot be reused. Create fresh disposable
documents for a repeat run and delete them afterward.
Restore the normal entrypoint with:
```
flutter run -d emulator-5554 -t lib/main.dart
```

All stated 5.2 functional checks passed against Android and the deployed
web/backend. Production mobile UI integration remains 5.3. This run does
not establish iOS or multi-chunk functional coverage and does not close
either owner phase gate.
