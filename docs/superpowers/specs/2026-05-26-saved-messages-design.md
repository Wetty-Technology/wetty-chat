# Saved Messages Design

## Goal

Add a personal saved-message feature for the Rust backend and PWA. A user can save a visible message, view saved snapshots from the original group info page or from global Settings, and jump back to the original context when they still have access.

## Product Decisions

- Saved messages are personal to the saver, not group-wide.
- Saving is idempotent. Saving the same original message again returns the existing saved snapshot.
- Saved snapshots remain visible to the saver even if the original message is edited, deleted, recalled, or the saver later leaves or is removed from the group.
- `Locate Context` remains access-controlled by current membership in the original chat. If the saver no longer has access, the saved card remains readable but context navigation is unavailable.
- V1 supports paginated newest-first lists only. Saved-message search, tags, folders, and notes are out of scope.
- V1 saves non-deleted, published, non-system messages. Text, text with attachments, audio, sticker, invite, and file-like content are saveable.
- Attachments and media are treated as immutable. The saved snapshot stores attachment metadata and storage references, not duplicated media blobs.
- Reply previews are not snapshotted in V1. The saved row may store `original_reply_to_message_id` for metadata, but the card does not need to render a copied quote.
- The message bubble does not need an inline saved indicator in V1. The long-press menu can show `Save`, and where saved state is already loaded it may show `Unsave`.

## Current System Context

The backend stores chat messages in `messages`, with text, message type, sender UID, chat ID, reply IDs, timestamps, soft delete state, attachment flags, thread flags, publish state, and transcode state. Attachments are separate rows linked by `message_id`; message DTO hydration builds public URLs and sender, attachment, sticker, mention, reply, reaction, and thread metadata.

The PWA already has a central long-press message action menu in the chat thread. Group info uses an Ionic settings-style layout with in-page modes such as message search. Global Settings is also an Ionic settings-style page. Message context navigation already uses `#msg=<messageId>` and existing around-window loading.

## Backend Data Model

Create a new `saved_messages` table owned by user UID.

Columns:

- `id BIGINT PRIMARY KEY`
- `uid INTEGER NOT NULL`
- `original_chat_id BIGINT NOT NULL`
- `original_thread_root_id BIGINT NULL`
- `original_message_id BIGINT NOT NULL`
- `original_reply_to_message_id BIGINT NULL`
- `original_sender_uid INTEGER NOT NULL`
- `original_created_at TIMESTAMPTZ NOT NULL`
- `saved_at TIMESTAMPTZ NOT NULL`
- `snapshot_message TEXT NULL`
- `snapshot_message_type message_type NOT NULL`
- `snapshot_attachments JSONB NOT NULL DEFAULT '[]'`
- `snapshot_sticker JSONB NULL`
- `snapshot_mentions JSONB NOT NULL DEFAULT '[]'`
- `snapshot_sender JSONB NOT NULL`
- `snapshot_chat JSONB NOT NULL`

Constraints and indexes:

- `UNIQUE (uid, original_message_id)` for idempotency.
- Index `(uid, id DESC)` for the global saved list.
- Index `(uid, original_chat_id, id DESC)` for group-scoped saved list.

The table intentionally denormalizes source location and display data. It avoids hot-path joins on message list queries and keeps snapshots readable when live message rows later change.

## Snapshot Shape

The saved DTO is distinct from `MessageResponse`; saved snapshots do not inherit live deletion behavior that hides text.

Response fields:

- `id`
- `originalChatId`
- `originalThreadRootId`
- `originalMessageId`
- `originalReplyToMessageId`
- `originalSenderUid`
- `originalCreatedAt`
- `savedAt`
- `message`
- `messageType`
- `attachments`
- `sticker`
- `mentions`
- `sender`
- `chat`
- `canLocateContext`

`attachments` store ordered metadata:

- `id`
- `externalReference`
- `url`, built from `externalReference` in responses
- `kind`
- `size`
- `fileName`
- `width`
- `height`
- `order`

`sender`, `chat`, and `mentions` are lightweight display snapshots. They are enough to render a saved card even without current group access.

## Backend API

Add a saved-message handler module and DTO module.

Endpoints:

- `PUT /saved-messages/:message_id`
  - Saves a currently visible message for the current user.
  - Loads the original message by ID, rejects missing, deleted, unpublished, or system messages.
  - Checks current membership in the message's chat before saving.
  - Builds a snapshot from the original message plus attachment/sticker/mention/chat/sender display metadata.
  - Inserts the row or returns the existing row for `(uid, original_message_id)`.

- `DELETE /saved-messages/by-message/:message_id`
  - Removes the current user's saved row for that original message if present.
  - Returns `204` whether a row existed or not.

- `DELETE /saved-messages/:saved_message_id`
  - Removes the current user's saved row by saved row ID.
  - Useful from saved-list cards.

- `GET /saved-messages?limit=&before=`
  - Lists the current user's saved snapshots, newest first.
  - Uses saved row `id` as the cursor; `before=<saved_message_id>` fetches older saved rows.

- `GET /chats/:chat_id/saved-messages?limit=&before=`
  - Lists the current user's saved snapshots for one chat, including messages saved from that chat's threads.
  - Does not require current membership to show saved snapshots if the rows belong to the user, but response `canLocateContext` must be false if membership is missing.

Status lookup for arbitrary message windows is out of scope for V1. The menu uses idempotent save, and saved-list views know the saved row they can unsave.

## Authorization

Saving requires current membership in the original chat because the user must be able to see the message at save time.

Listing saved messages is owner-only by `uid`. It does not require current membership in every original chat, because saved snapshots are personal archival data.

Locating context requires current membership in the original chat. The backend computes `canLocateContext` for list responses so the UI can disable the action without an avoidable failed request.

## PWA UX

Message long-press menu:

- Add `Save` for eligible messages.
- If saved state is known locally, show `Unsave` instead.
- Do not add a saved badge to message bubbles in V1.
- The save action calls the idempotent save endpoint and shows a small toast on success/failure.

Group Info:

- Add a `Saved Messages` entry/action near Search and Media & Files.
- It opens a group-scoped saved-message view for the current chat and its threads.
- The view uses snapshot cards with sender, saved time, original message time, preserved content, attachments/sticker preview, and actions.

Settings:

- Add a global `Saved Messages` entry.
- It opens the same saved-message view without a chat filter.

Saved-message card actions:

- `Locate Context`: navigates to `/chats/chat/:chatId#msg=:messageId` or `/chats/chat/:chatId/thread/:threadRootId#msg=:messageId` when `canLocateContext` is true.
- `Unsave`: deletes the saved row and removes it from the list.

Empty/loading/error states follow existing Ionic settings/list patterns.

## Navigation

Saved list context navigation reuses the existing message-search/permalink target logic:

- If `originalThreadRootId` is present, navigate to the thread route with `#msg=<originalMessageId>`.
- Otherwise navigate to the main chat route with `#msg=<originalMessageId>`.
- The existing chat thread around-window loader handles fetching the target and scrolling to it.

If `canLocateContext` is false, the card shows disabled context action text: `No access to original chat`.

## Testing

Backend tests cover:

- Snapshot creation for a text message.
- Snapshot creation with attachment metadata.
- Idempotent save returns the existing row.
- Save rejects deleted, unpublished, missing, and system messages.
- Save requires current membership.
- Global list returns only the current user's rows in newest-first order.
- Group list filters by original chat and includes thread messages.
- Listing remains possible after membership is removed but `canLocateContext` becomes false.
- Delete by message and delete by saved row are scoped to current user.

PWA tests cover:

- API parameter/DTO helpers for saved messages.
- Saved-message target route construction for main-chat and thread messages.
- Saved-message list rendering for content, attachment preview, disabled locate state, loading, empty, and error states.
- Group info and Settings expose saved-message entry points.

Manual verification covers:

- Save a message from the long-press menu.
- Save the same message twice.
- View saved messages from Group Info.
- View all saved messages from Settings.
- Edit/delete the original message and confirm saved snapshot remains unchanged.
- Leave/remove membership and confirm the snapshot remains visible while locate is unavailable.

## Out Of Scope

- Full-text search within saved messages.
- Tags, folders, user notes, favorites, or pinning saved rows.
- Duplicating media blobs.
- Inline saved badges on chat bubbles.
- Snapshotting reply preview content.
- Flutter implementation.
