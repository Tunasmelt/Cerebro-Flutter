# UI/UX F3 — Graph accessibility and states

F2 passed its graph interaction checks before F3 began. F3's exit test requires
the Android build on an emulator or device with a real authenticated graph
response, followed by opening a document and its real chunks through List view.
The same build must show the loading skeleton, empty-state Documents action,
node accessibility labels, a static retrieval highlight when reduced motion is
enabled, and a side panel in landscape or at width 840 and above.

Implemented on `ui/f3-graph-accessibility`:

- Each graph dot exposes its title and node type as a tappable accessibility
  item. List view exposes those nodes as sorted, searchable document rows and
  opens the existing node panel. The graph canvas is removed from the
  accessibility tree while List view is active.
- Reduced-motion retrievals hold a static highlight for the pulse duration.
- The graph uses the shared loading skeleton and an empty state that leads to
  Documents for uploading.
- Landscape and wide screens use a side panel; portrait phones retain the
  draggable sheet.

The backend `GET /graph/nodes` response contains title, MIME type, status,
cluster and position, but **no chunk count** (`services/api/app/graph/storage.py`).
Node labels therefore say title and type. Adding “N chunks” would require a
backend response field; client-side per-node chunk requests would make a large
graph issue hundreds of extra calls. This source gap remains open for a
cross-repo change, outside this mobile stage.

Validation on 2026-10-13:

- `flutter analyze`: clean. Full suite: 1,044 passed, 30 existing opt-in skips.
- Graph widget checks passed for List view, landscape panel, loading and empty
  states, and static reduced-motion pulse.
- Built and installed a debug APK on Android 16 emulator `emulator-5554`.
  After a fresh launch, the saved session recovered. Graph loaded the 26 live
  documents, List view showed the sorted documents, and selecting
  `2507.18910v1.pdf` loaded its 1,000 chunks from the backend. Landscape
  opened the side panel with the real chunk list.
- A landscape check found controls initially behind the side panel and the
  selected-node offset toward it. Both were corrected, then the rebuilt app
  was reinstalled and checked in landscape: search, List view and refresh stay
  visible beside the panel, and the selected node is placed in the graph area.
- The empty state and reduced-motion pulse passed widget checks; the test
  account has documents and the emulator's reduced-motion setting was not
  toggled, so these two states have not been witnessed in a live backend run.
- F3 remains open because the required per-node chunk count is absent from
  `GET /graph/nodes`. The backend needs to provide it before labels can include
  “N chunks” without excessive client requests.
- Owner phase gate: unchanged.
