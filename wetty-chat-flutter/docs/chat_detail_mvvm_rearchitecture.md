# Chat Detail MVVM Re-architecture

## Summary
Rebuild chat detail as a generic `ConversationTimeline` stack shared by chats and threads. The architecture should split cleanly into:

- `ConversationScope` plus repository/store for normalized conversation data
- `ConversationTimelineViewModel` for windowing, loading, anchor, unread, highlight, and live-edge state
- `ConversationComposerViewModel` for draft, reply/edit mode, attachments, and optimistic mutations
- `ConversationTimelineView` as a reusable virtualized viewport that renders timeline entries, not chat-specific widgets

Use an in-memory session cache only for v1. Network remains the source of truth. Re-entering a warm conversation should restore the previous window, anchor, and draft, then perform a lightweight refresh.

Unread launch must be anchored by a required unread message ID. `unreadCount` remains badge-only metadata from chat list and must never drive unread positioning because the backend caps it at `100` and the UI renders `99+`.

Keep `LaunchRequest.latest`, `LaunchRequest.unread(unreadMessageId)`, and `LaunchRequest.message(messageId, highlight)` as separate public intents. Internally, `unread` and `message` must share one anchored-load path. The only intended behavior difference is unread-marker insertion and highlight behavior.

## Existing Backend Constraints
Use the current backend contract as-is:

- `GET /chats/:chatId/messages?before=...`
- `GET /chats/:chatId/messages?after=...`
- `GET /chats/:chatId/messages?around=...`
- `GET /chats/:chatId/messages?threadId=:threadRootId`
- `POST /chats/:chatId/messages`
- `POST /chats/:chatId/threads/:threadRootId/messages`
- `PATCH /chats/:chatId/messages/:messageId`
- `DELETE /chats/:chatId/messages/:messageId`
- `POST /chats/:chatId/read`

Important current backend semantics:

- Delete is soft delete. Timeline rows should become tombstones, not disappear.
- `client_generated_id` already exists and must be used for optimistic reconciliation.
- `around` loads are real and should be the basis for anchored history loads.
- Chat list returns `lastReadMessageId`; `unreadCount` is badge-only metadata and is capped.

## Public Interfaces

### Conversation scope
Introduce a generic scope:

- `ConversationScope.chat(chatId)`
- `ConversationScope.thread(chatId, threadRootId)`

### Launch API
Public launch intents should be:

- `LaunchRequest.latest`
- `LaunchRequest.unread(unreadMessageId)`
- `LaunchRequest.message(messageId, {bool highlight = true})`

Rules:

- `LaunchRequest.unread(...)` always requires a concrete unread message ID.
- If no unread anchor exists, caller must use `LaunchRequest.latest`.
- `unreadCount` should never be used to derive window position.

### Shared internal anchored-load spec
`LaunchRequest.unread(...)` and `LaunchRequest.message(...)` should compile down to one internal anchored-load spec with flags similar to:

- `anchorMessageId`
- `insertUnreadMarker`
- `highlightTarget`
- `preferredAlignment`
- `returnMode`

Mapping:

- `unread(unreadMessageId)` => anchored load with `insertUnreadMarker = true`, `highlightTarget = false`
- `message(messageId, highlight: true)` => anchored load with `insertUnreadMarker = false`, `highlightTarget = true`
- `message(messageId, highlight: false)` => anchored load with `insertUnreadMarker = false`, `highlightTarget = false`

## Core Data Model

### Message entity
Create a normalized `ConversationMessage` model that carries:

- server ID
- optional local temp ID or key
- `clientGeneratedId`
- conversation scope linkage
- sender info
- text and rich payload fields
- attachments
- reply metadata
- thread metadata
- edited/deleted flags
- delivery state: `sending | sent | failed | editing | deleting`

### Timeline entry
Create a sealed `TimelineEntry` hierarchy:

- `message`
- `dateSeparator`
- `unreadMarker`
- `historyGapOlder`
- `historyGapNewer`
- `loadingOlder`
- `loadingNewer`

Meta rows are derived from message windows. They are not stored as messages.

## Repository and Store

### Repository responsibilities
Create a per-scope `ConversationRepository` as the source of truth for one chat or thread.

It should own:

- normalized message map keyed by server ID
- secondary lookup by `clientGeneratedId`
- loaded ID ranges or slices
- latest known cursors or load capabilities for older/newer history
- optimistic mutation registry
- last known active window and anchor
- one merge pipeline shared by HTTP and websocket deltas

### Store behavior
The store should:

- retain loaded messages for the conversation during the app session
- expose only a bounded active render window
- keep active window size around `100` message entries
- extend in page sizes around `30-50`
- cap rendered timeline at roughly `250-400` entries including meta rows
- trim away from the current anchor when over cap
- preserve enough context around the anchor when trimming

### Window modes
The VM may use internal modes like:

- `liveLatest`
- `anchoredTarget`
- `historyBrowsing`

The UI should not depend on chat-specific window mode assumptions.

## Loading Flows

### Initial latest load
- Fetch newest page for the scope.
- Build normalized store and derived timeline entries.
- Enter `liveLatest`.
- Scroll to bottom/live edge.
- If the scope is warm in memory, restore cached window immediately, then refresh latest in the background.

### Initial anchored load
This flow is shared by unread launch and message jump.

- Call `loadAround(anchorMessageId)`.
- Build active window centered around the anchor.
- Enter anchored mode.
- Apply anchor-specific decorations after the shared window is built.

Anchor-specific decorations:

- unread launch: insert one `unreadMarker` immediately before the anchor message
- message jump: apply temporary highlight if requested

Fallback:

- If the target message is unavailable, show a non-blocking “message unavailable” state and fall back to latest.

### Infinite older load
- Trigger when viewport reaches the older boundary.
- Request older page anchored by oldest visible server message ID.
- Merge without duplicates.
- Preserve visual position after prepend.
- If render cap is exceeded, trim from the newer side unless that would break required live-edge context.

### Infinite newer load while browsing history
- Trigger when viewport reaches the newer boundary while not at live edge.
- Request newer page anchored by newest visible server message ID.
- Merge without shifting the visible anchor.
- If the newer edge reaches live latest, transition back to `liveLatest`.

### Return to live edge
- Rebuild window around latest page.
- Clear anchor-specific state.
- Clear highlight.
- Clear unread marker state.
- Resume auto-append behavior.

## Live Update and Optimistic Mutation Flows

### Live created message
- Merge through the same repository path used by HTTP send success.
- If user is at live edge, append into active window and keep bottom anchored unless the user is actively dragging.
- If user is browsing history, merge into normalized cache, increment a `pendingLiveCount`, and show a jump-to-latest affordance.

### Live updated message
- Patch normalized entity in place.
- Rebuild only affected timeline rows.
- Preserve row position and current anchor.

### Live deleted message
- Convert the message into a tombstone row.
- Do not remove the row from the active timeline.
- Keep row identity stable to avoid scroll drift.

### Optimistic send
- Insert a pending message immediately with temp local identity, `clientGeneratedId`, and `sending` state.
- On POST success, reconcile by `clientGeneratedId`, replace temp identity with server ID, and mark as `sent`.
- On websocket echo before HTTP response, run the same reconcile path.
- On failure, keep the bubble with `failed` state and provide retry/discard actions.

### Optimistic edit
- Mark the message locally as `editing`.
- Retain previous snapshot for rollback.
- On success, replace with server entity.
- On failure, restore previous snapshot and surface inline failure state.

### Optimistic delete
- Mark the message locally as `deleting`.
- On success or websocket delete, convert it to tombstone.
- On failure, restore previous state.

## View Layer

### Timeline widget
Create a reusable `ConversationTimelineView` that accepts:

- `List<TimelineEntry>`
- viewport state
- callbacks for `loadOlder`, `loadNewer`, `onVisibleRangeChanged`, `onJumpToLatest`
- builders for message rows, meta rows, and loading/gap rows

Behavior:

- natural domain ordering should be oldest to newest
- support indexed jump after the VM recenters around a target
- preserve anchor after prepend or append in history mode
- support unread marker and temporary highlight
- stay generic and not know chat bubble details

### Bubble/content rendering
Move content-specific rendering behind message content widgets or a registry:

- text
- image
- video
- mixed attachment
- sticker
- special card

Threads should reuse the same timeline widget and store logic, differing only by scope and configuration.

## Provider Shape
Target provider structure:

- `conversationRepositoryProvider(scope)`
- `conversationTimelineViewModelProvider((scope, launchRequest))`
- `conversationComposerViewModelProvider(scope)`

Responsibilities:

- repository: data, cache, merge logic
- timeline VM: viewport, anchor, unread/highlight, live-edge state
- composer VM: draft, reply/edit/attachment state, optimistic mutation orchestration
- page widget: controller wiring and composition only

## Implementation Task List

1. Add new generic chat-detail domain models for conversation scope, launch request, timeline entry, delivery state, and timeline screen state.
2. Add a generic conversation API service layer that can load latest, older, newer, around-target, and send/edit/delete/read for chats and threads.
3. Replace the current message repository/store design with a normalized session-scoped conversation repository and bounded active window model.
4. Implement a shared anchored-load path used by both `LaunchRequest.unread(...)` and `LaunchRequest.message(...)`.
5. Implement websocket merge logic through a single repository delta path for create, update, and delete events.
6. Implement optimistic send, edit, and delete flows with reconciliation by both server ID and `clientGeneratedId`.
7. Split current `chat_detail_view_model.dart` responsibilities into a timeline VM and a composer VM.
8. Build a reusable `ConversationTimelineView` that owns list rendering mechanics, anchor preservation, jump-to-latest affordance, and visible-range callbacks.
9. Adapt the existing chat detail screen to compose the new timeline VM, composer VM, and generic timeline widget.
10. Ensure thread-detail reuse happens through `ConversationScope.thread(...)` rather than a separate state architecture.
11. Update chat-list to pass the correct unread launch data path based on concrete unread anchor IDs rather than count-driven logic.
12. Add or update tests for repository paging, anchored load behavior, unread marker insertion, optimistic reconciliation, tombstone behavior, and widget-level anchor preservation.

## Testing Expectations
Add tests for:

- latest page load
- shared anchored load around a target message
- unread launch uses shared anchored path plus unread-marker insertion
- message launch uses shared anchored path plus optional highlight
- older/newer merge without duplication
- render-window trimming preserves anchor
- optimistic send success/failure and reconciliation
- optimistic edit rollback
- optimistic delete to tombstone
- live create/update/delete while at live edge and while browsing history
- widget anchor preservation after prepend and append

## Explicit Assumptions
- v1 uses in-memory session cache only; no persistent offline transcript cache.
- Deleted messages remain visible as tombstones.
- `unreadCount` is badge-only and capped server-side.
- `LaunchRequest.unread(...)` always requires a concrete unread anchor message ID.
- `unread(...)` and `message(...)` remain separate public intents but must use one internal anchored-load implementation.
- Reactions, pins, and `threadUpdate` are not required for the first rewrite, but the repository delta pipeline should remain extensible enough to support them later.
- Keep using `scrollable_positioned_list` initially. The replacement seam is the reusable timeline widget, not the entire architecture.
