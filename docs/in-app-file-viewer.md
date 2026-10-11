# In-app original-file viewer

Open a document and choose **View file**. Supported upload formats are PDF,
JPEG, PNG, WebP, plain text and Markdown. Images support pan/zoom; PDFs support
page navigation and zoom with a page counter. Text/Markdown display as
selectable source text. The viewer stays inside Cerebro.

The actual backend contract is `GET /api/v1/documents/{id}/original`, returning
`{url}`. The generated client supplies normal SDK authentication only to the
API. A separate Dio client fetches the HTTPS signed URL without forwarding
JWT headers; stream accumulation stops above 50 MiB. Transport failures never
expose the signed URL. Retry asks the API for a fresh URL.

Sealed documents have no View file action, and the viewer independently refuses
them. The backend rejects original download with 423 even during an unlock
session; this feature preserves that contract. Original files are not exposed
through a client-side unlock workaround. Providers rebuild on account changes,
and signing out removes visible content immediately.

Original bytes are held in memory. Android/iOS PDF rendering needs a private
cache file descriptor: the app removes its temporary copy immediately after
opening. Startup removes viewer-only folders left by a crash while preserving
pending uploads. Image cache entries are evicted on exit; PDF exit clears
rendered-page image caches and closes its document. No download is shared or
saved to the user's filesystem by this action.

PDF renderer: [pdfx](https://pub.dev/packages/pdfx) 2.11.0, published 52 days
before review, maintained publisher, Android/iOS support, MIT license verified
in the downloaded source. The initially attempted pdfrx dependency was removed:
its compatible version required Windows symlink privileges. The pdfx texture
view froze on emulator exit; the shipped standard page view passed navigation.

Validation: original PNG and PDF were visibly rendered from the deployed backend
on Android emulator. Standard PDF page navigation/return and Markdown open/return
passed Maestro. Widget/provider tests cover selectable text, sealed rejection,
sign-out, signed-out URL refusal, insecure URL refusal and sanitized errors.
Crash-cache cleanup is tested with actual files. Full suite: 873 passing,
30 existing opt-in skips. iOS/native physical viewer verification remains pending.
