# User settings implementation and verification

Updated 2026-10-12. Phase 7's gate remains closed by explicit owner direction;
its unverified iOS/device-matrix items have not been marked passed.

## Contract and scope

Reviewed Cerebro-2.0's actual settings page, account proxy and FastAPI account
route before implementation. Mobile now uses Supabase Auth user metadata
(`display_name`, `avatar_url`) and updateUser for profile/email/password changes,
the existing document-list client for account storage and sealed-document links,
and the generated DELETE /api/v1/account client for vault-data removal.
The endpoint leaves the authentication account intact, so the UI calls the
action Delete vault data and explains its actual behavior.

Removed the mock identity, fabricated counts/storage/version and inactive
retrieval/graph/app-lock/notification controls unsupported by the existing web
product. Appearance accurately reports the current dark theme. Data sources
navigates to Documents. Backend connectivity and sign-out remain functional.
No package or backend change was needed.

Exit checks: real account/document data loads; profile changes can be saved
through Supabase and survive restart; forms validate input, contain safe failure
messages and do not reveal stale account data. Destructive testing must use
disposable accounts, never the owner's vault.

## Safety and validation

Avatar URLs accept http(s) links up to 2000 characters, matching web's limit;
display names are bounded to 200 characters. Passwords require at least eight
characters and matching confirmation; secrets clear after success. Email changes
use the existing mobile confirmation deep link and explicitly require email
confirmation. Busy forms cannot submit twice. Account changes hide old fields
and suppress late results; mutation dispatch checks the current SDK identity.
Feedback stays visible outside the scrollable form.

Vault removal requires exact DELETE text plus a second confirmation. Pending
uploads block deletion; restored-upload initialization is awaited and checked
again before dispatch. Only a successful backend wipe is followed by sign-out.
Failure retains the session and retry control.

## Evidence

- Full Flutter suite: 883 passing, 30 existing opt-in skips.
- Settings tests cover profile validation/save/failure, email confirmation,
  password mismatch/secret clearing, duplicate submission, account switching,
  wipe cancellation/success/failure, existing connection states and sign-out.
- Physical Pixel 9 Pro XL: normal installed build displays real profile and
  document storage data. Saving the existing profile through production
  Supabase succeeded; name/avatar/email matched after process restart.
  Data sources navigation returned to Documents.
- Android debug build and analysis pass.

Email/password changes and vault removal were not executed against the owner's
live account. Their success/failure paths use test doubles; disposable-account
live checks remain unverified. No iOS device/build evidence is added here.
Owner session and existing documents were preserved; no user values, tokens,
passwords or signed URLs are included in this verification record.
