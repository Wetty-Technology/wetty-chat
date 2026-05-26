# Saved Messages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build personal saved-message snapshots across the Rust backend and React PWA, with group-scoped and global saved-message views.

**Architecture:** Add a user-owned `saved_messages` table that snapshots message display data and immutable attachment references at save time. Expose owner-scoped backend APIs for idempotent save, unsave, and paginated listing, then add PWA APIs, routes, saved-card UI, group info/settings entry points, and a long-press Save action.

**Tech Stack:** Rust, Axum, Diesel/PostgreSQL, serde JSONB, Ionic React, Redux Toolkit, Vite, Vitest, Lingui.

---

## File Structure

Backend:

- Create migration with `diesel migration generate add_saved_messages`; edit its generated `up.sql` and `down.sql`.
- Modify `backend/src/schema/primary.rs`: add `saved_messages` table, joinables, and allow-list entry after running Diesel schema generation or updating schema consistently with existing generated style.
- Modify `backend/src/schema.rs`: re-export `saved_messages`.
- Modify `backend/src/models.rs`: add `SavedMessage` and `NewSavedMessage`.
- Create `backend/src/dto/saved_messages.rs`: saved-message response DTOs and list response.
- Modify `backend/src/dto/mod.rs`: export `saved_messages`.
- Create `backend/src/services/saved_messages.rs`: snapshot structs, eligibility helpers, cursor helpers, snapshot builder, persistence/list/delete helpers.
- Modify `backend/src/services/mod.rs`: export `saved_messages`.
- Create `backend/src/handlers/saved_messages.rs`: global saved-message routes.
- Create `backend/src/handlers/chats/saved_messages.rs`: chat-scoped saved-message list route.
- Modify `backend/src/handlers/mod.rs`: export and mount `/saved-messages`.
- Modify `backend/src/handlers/chats/mod.rs`: mount `/chats/:chat_id/saved-messages`.

PWA:

- Create `wetty-chat-mobile/src/api/savedMessages.ts`: DTOs and HTTP helpers.
- Create `wetty-chat-mobile/src/utils/savedMessages.ts`: route target builder and preview helpers.
- Create `wetty-chat-mobile/src/utils/savedMessages.test.ts`: target builder tests.
- Create `wetty-chat-mobile/src/components/chat/saved/SavedMessageList.tsx`.
- Create `wetty-chat-mobile/src/components/chat/saved/SavedMessageList.module.scss`.
- Create `wetty-chat-mobile/src/pages/saved-messages.tsx`: global saved page wrapper.
- Create `wetty-chat-mobile/src/pages/chat-thread/group-info/saved-messages.tsx`: group-scoped page wrapper.
- Modify `wetty-chat-mobile/src/pages/chat-thread/group-info/index.ts`: export the new group-saved page/core.
- Modify `wetty-chat-mobile/src/pages/chat-thread/group-info/group-info.tsx`: add an entry point that routes to `/chats/chat/:id/group-info/saved-messages`.
- Modify `wetty-chat-mobile/src/pages/settings.tsx`: add global saved entry.
- Modify `wetty-chat-mobile/src/layouts/MobileLayout.tsx`: add mobile routes for `/settings/saved-messages` and `/chats/chat/:id/group-info/saved-messages`.
- Modify `wetty-chat-mobile/src/layouts/DesktopSplitLayout.tsx`: add desktop modal routing for both saved pages.
- Modify `wetty-chat-mobile/src/pages/chat-thread/chat-thread.tsx`: add idempotent Save action.
- Run `npm run lingui:extract` after user-visible strings are added.

## Task 1: Backend Migration And Schema

**Files:**
- Create: the `up.sql` file in the migration directory produced by `diesel migration generate add_saved_messages`
- Create: the `down.sql` file in the migration directory produced by `diesel migration generate add_saved_messages`
- Modify: `backend/src/schema/primary.rs`
- Modify: `backend/src/schema.rs`
- Modify: `backend/src/models.rs`

- [ ] **Step 1: Generate the migration**

Run from `backend/`:

```bash
diesel migration generate add_saved_messages
```

Expected: Diesel prints the created migration directory. Use that exact directory for Steps 2 and 3.

- [ ] **Step 2: Fill `up.sql`**

Use this SQL in the generated `up.sql`:

```sql
CREATE TABLE saved_messages (
    id BIGINT PRIMARY KEY,
    uid INTEGER NOT NULL,
    original_chat_id BIGINT NOT NULL REFERENCES groups(id),
    original_thread_root_id BIGINT NULL REFERENCES messages(id),
    original_message_id BIGINT NOT NULL REFERENCES messages(id),
    original_reply_to_message_id BIGINT NULL REFERENCES messages(id),
    original_sender_uid INTEGER NOT NULL,
    original_created_at TIMESTAMPTZ NOT NULL,
    saved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    snapshot_message TEXT NULL,
    snapshot_message_type message_type NOT NULL,
    snapshot_attachments JSONB NOT NULL DEFAULT '[]'::jsonb,
    snapshot_sticker JSONB NULL,
    snapshot_mentions JSONB NOT NULL DEFAULT '[]'::jsonb,
    snapshot_sender JSONB NOT NULL,
    snapshot_chat JSONB NOT NULL,
    UNIQUE (uid, original_message_id)
);

CREATE INDEX idx_saved_messages_uid_id
    ON saved_messages (uid, id DESC);

CREATE INDEX idx_saved_messages_uid_chat_id
    ON saved_messages (uid, original_chat_id, id DESC);
```

- [ ] **Step 3: Fill `down.sql`**

Use this SQL in the generated `down.sql`:

```sql
DROP INDEX IF EXISTS idx_saved_messages_uid_chat_id;
DROP INDEX IF EXISTS idx_saved_messages_uid_id;
DROP TABLE IF EXISTS saved_messages;
```

- [ ] **Step 4: Update Diesel schema**

Run from `backend/` after applying or using Diesel print schema in the local workflow:

```bash
diesel migration run
diesel print-schema --schema public > src/schema/primary.rs
```

Expected: `primary.rs` contains a `saved_messages` table using `Jsonb`, joinables to `groups` and `messages`, and includes `saved_messages` in `allow_tables_to_appear_in_same_query!`.

- [ ] **Step 5: Preserve manual schema module conventions**

Ensure `backend/src/schema.rs` re-exports `saved_messages`:

```rust
pub use primary::{
    activity_daily_metrics, attachments, clients, group_membership, groups, invites, media,
    message_reactions, messages, pinned_messages, policies, policy_assignments, policy_permissions,
    push_subscriptions, saved_messages, service_tokens, sql_types, sticker_pack_stickers,
    sticker_packs, stickers, thread_meta, thread_subscriptions, user_extra,
    user_favorite_stickers, user_sticker_pack_subscriptions, usergroup_extra,
};
```

- [ ] **Step 6: Add models**

Append near `PinnedMessage` in `backend/src/models.rs`:

```rust
#[derive(Debug, Clone, Queryable, Selectable, Serialize)]
#[diesel(table_name = schema::saved_messages)]
pub struct SavedMessage {
    pub id: i64,
    pub uid: i32,
    pub original_chat_id: i64,
    pub original_thread_root_id: Option<i64>,
    pub original_message_id: i64,
    pub original_reply_to_message_id: Option<i64>,
    pub original_sender_uid: i32,
    pub original_created_at: DateTime<Utc>,
    pub saved_at: DateTime<Utc>,
    pub snapshot_message: Option<String>,
    pub snapshot_message_type: MessageType,
    pub snapshot_attachments: serde_json::Value,
    pub snapshot_sticker: Option<serde_json::Value>,
    pub snapshot_mentions: serde_json::Value,
    pub snapshot_sender: serde_json::Value,
    pub snapshot_chat: serde_json::Value,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = schema::saved_messages)]
pub struct NewSavedMessage {
    pub id: i64,
    pub uid: i32,
    pub original_chat_id: i64,
    pub original_thread_root_id: Option<i64>,
    pub original_message_id: i64,
    pub original_reply_to_message_id: Option<i64>,
    pub original_sender_uid: i32,
    pub original_created_at: DateTime<Utc>,
    pub saved_at: DateTime<Utc>,
    pub snapshot_message: Option<String>,
    pub snapshot_message_type: MessageType,
    pub snapshot_attachments: serde_json::Value,
    pub snapshot_sticker: Option<serde_json::Value>,
    pub snapshot_mentions: serde_json::Value,
    pub snapshot_sender: serde_json::Value,
    pub snapshot_chat: serde_json::Value,
}
```

- [ ] **Step 7: Verify schema compiles**

Run:

```bash
cargo fmt
cargo test models::tests::message_type_serializes_as_snake_case
```

Expected: formatting succeeds and the targeted model test passes.

- [ ] **Step 8: Commit backend schema foundation**

```bash
git add backend/migrations backend/src/schema.rs backend/src/schema/primary.rs backend/src/models.rs
git commit -m "feat: add saved messages schema"
```

## Task 2: Backend DTOs And Pure Helpers

**Files:**
- Create: `backend/src/dto/saved_messages.rs`
- Modify: `backend/src/dto/mod.rs`
- Create: `backend/src/services/saved_messages.rs`
- Modify: `backend/src/services/mod.rs`

- [ ] **Step 1: Add DTO module**

Create `backend/src/dto/saved_messages.rs`:

```rust
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use crate::{dto::messages::MentionInfo, models::MessageType};

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct SavedAttachmentSnapshot {
    #[serde(with = "crate::serde_i64_string")]
    #[schema(value_type = String)]
    pub id: i64,
    pub external_reference: String,
    pub url: String,
    pub kind: String,
    pub size: i64,
    pub file_name: String,
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub order: i16,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct SavedStickerSnapshot {
    #[serde(with = "crate::serde_i64_string")]
    #[schema(value_type = String)]
    pub id: i64,
    pub emoji: String,
    pub name: Option<String>,
    pub media_url: String,
    pub media_content_type: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct SavedSenderSnapshot {
    pub uid: i32,
    pub name: Option<String>,
    pub avatar_url: Option<String>,
    pub gender: i16,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct SavedChatSnapshot {
    #[serde(with = "crate::serde_i64_string")]
    #[schema(value_type = String)]
    pub id: i64,
    pub name: Option<String>,
    pub avatar_url: Option<String>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct SavedMessageResponse {
    #[serde(with = "crate::serde_i64_string")]
    #[schema(value_type = String)]
    pub id: i64,
    #[serde(with = "crate::serde_i64_string")]
    #[schema(value_type = String)]
    pub original_chat_id: i64,
    #[serde(with = "crate::serde_i64_string::opt")]
    #[schema(value_type = Option<String>)]
    pub original_thread_root_id: Option<i64>,
    #[serde(with = "crate::serde_i64_string")]
    #[schema(value_type = String)]
    pub original_message_id: i64,
    #[serde(with = "crate::serde_i64_string::opt")]
    #[schema(value_type = Option<String>)]
    pub original_reply_to_message_id: Option<i64>,
    pub original_sender_uid: i32,
    pub original_created_at: DateTime<Utc>,
    pub saved_at: DateTime<Utc>,
    pub message: Option<String>,
    pub message_type: MessageType,
    pub attachments: Vec<SavedAttachmentSnapshot>,
    pub sticker: Option<SavedStickerSnapshot>,
    pub mentions: Vec<MentionInfo>,
    pub sender: SavedSenderSnapshot,
    pub chat: SavedChatSnapshot,
    pub can_locate_context: bool,
}

#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ListSavedMessagesResponse {
    pub saved_messages: Vec<SavedMessageResponse>,
    #[serde(with = "crate::serde_i64_string::opt")]
    #[schema(value_type = Option<String>)]
    pub next_cursor: Option<i64>,
}
```

- [ ] **Step 2: Export DTO module**

Add to `backend/src/dto/mod.rs`:

```rust
pub mod saved_messages;
```

- [ ] **Step 3: Add service module skeleton and tests**

Create `backend/src/services/saved_messages.rs` with pure helpers first:

```rust
use crate::{errors::AppError, models::{Message, MessageType}};

pub const DEFAULT_SAVED_MESSAGES_LIMIT: i64 = 30;
pub const MAX_SAVED_MESSAGES_LIMIT: i64 = 100;

pub fn ensure_message_can_be_saved(message: &Message) -> Result<(), AppError> {
    if message.deleted_at.is_some() {
        return Err(AppError::BadRequest("Cannot save deleted message"));
    }
    if !message.is_published {
        return Err(AppError::BadRequest("Cannot save unpublished message"));
    }
    if matches!(message.message_type, MessageType::System) {
        return Err(AppError::BadRequest("Cannot save system messages"));
    }
    Ok(())
}

pub fn saved_messages_limit(limit: Option<i64>) -> i64 {
    crate::utils::pagination::validate_limit(
        Some(limit.unwrap_or(DEFAULT_SAVED_MESSAGES_LIMIT)),
        MAX_SAVED_MESSAGES_LIMIT,
    )
}

#[cfg(test)]
mod tests {
    use super::{ensure_message_can_be_saved, saved_messages_limit};
    use crate::models::{Message, MessageType, TranscodeStatus};
    use chrono::Utc;

    fn message_with_type(message_type: MessageType) -> Message {
        Message {
            id: 1,
            message: Some("hello".to_string()),
            message_type,
            reply_to_id: None,
            reply_root_id: None,
            client_generated_id: "cg".to_string(),
            sender_uid: 10,
            chat_id: 20,
            created_at: Utc::now(),
            updated_at: None,
            deleted_at: None,
            has_attachments: false,
            has_thread: false,
            has_reactions: false,
            sticker_id: None,
            is_published: true,
            transcode_status: TranscodeStatus::None,
        }
    }

    #[test]
    fn rejects_system_messages() {
        let message = message_with_type(MessageType::System);
        assert!(ensure_message_can_be_saved(&message).is_err());
    }

    #[test]
    fn rejects_deleted_messages() {
        let mut message = message_with_type(MessageType::Text);
        message.deleted_at = Some(Utc::now());
        assert!(ensure_message_can_be_saved(&message).is_err());
    }

    #[test]
    fn accepts_user_content_messages() {
        assert!(ensure_message_can_be_saved(&message_with_type(MessageType::Text)).is_ok());
        assert!(ensure_message_can_be_saved(&message_with_type(MessageType::Audio)).is_ok());
        assert!(ensure_message_can_be_saved(&message_with_type(MessageType::Sticker)).is_ok());
        assert!(ensure_message_can_be_saved(&message_with_type(MessageType::Invite)).is_ok());
    }

    #[test]
    fn clamps_saved_message_limit() {
        assert_eq!(saved_messages_limit(None), 30);
        assert_eq!(saved_messages_limit(Some(500)), 100);
    }
}
```

- [ ] **Step 4: Export service module**

Add to `backend/src/services/mod.rs`:

```rust
pub mod saved_messages;
```

- [ ] **Step 5: Run targeted tests**

Run:

```bash
cargo test services::saved_messages
```

Expected: the new pure helper tests pass.

- [ ] **Step 6: Commit DTO/helper foundation**

```bash
git add backend/src/dto/mod.rs backend/src/dto/saved_messages.rs backend/src/services/mod.rs backend/src/services/saved_messages.rs
git commit -m "feat: add saved message DTOs"
```

## Task 3: Backend Snapshot Persistence And Listing

**Files:**
- Modify: `backend/src/services/saved_messages.rs`

- [ ] **Step 1: Add snapshot conversion functions**

Extend `backend/src/services/saved_messages.rs` with Diesel imports and functions that:

- Load the source `Message` by ID.
- Call `ensure_message_can_be_saved`.
- Load attachments ordered by `(order, id)`.
- Load sender profile/avatar through existing user helpers.
- Load group name/avatar through `groups` and `media`.
- Load sticker/media when `sticker_id` is present.
- Resolve mentions from `@[uid:N]` tokens with `handlers::chats::extract_mention_uids`.
- Serialize snapshot structs into `serde_json::Value`.
- Convert `SavedMessage` rows back to `SavedMessageResponse`.

Core signatures:

```rust
pub async fn save_message_snapshot(
    conn: &mut PgConnection,
    state: &AppState,
    uid: i32,
    message_id: i64,
) -> Result<SavedMessageResponse, AppError>;

pub fn delete_saved_message_by_original(
    conn: &mut PgConnection,
    uid: i32,
    message_id: i64,
) -> Result<(), AppError>;

pub fn delete_saved_message_by_id(
    conn: &mut PgConnection,
    uid: i32,
    saved_message_id: i64,
) -> Result<(), AppError>;

pub fn list_saved_messages(
    conn: &mut PgConnection,
    state: &AppState,
    uid: i32,
    chat_id: Option<i64>,
    before: Option<i64>,
    limit: Option<i64>,
) -> Result<ListSavedMessagesResponse, AppError>;
```

Use `ids::next_message_id(state.id_gen.as_ref()).await` for saved row IDs. Use `ON CONFLICT (uid, original_message_id) DO UPDATE SET original_message_id = excluded.original_message_id RETURNING *` or a select-after-conflict pattern so idempotent save returns the existing row.

- [ ] **Step 2: Add `canLocateContext` batching**

For list responses, load all `original_chat_id` values and query `group_membership` for `(chat_id, uid)`. Set `can_locate_context` true only for chats where a membership row exists.

Use one query per page:

```rust
let accessible_chat_ids: HashSet<i64> = group_membership::table
    .filter(group_membership::uid.eq(uid))
    .filter(group_membership::chat_id.eq_any(&chat_ids))
    .select(group_membership::chat_id)
    .load::<i64>(conn)?
    .into_iter()
    .collect();
```

- [ ] **Step 3: Keep cursor deterministic**

List rows by saved row ID descending:

```rust
let mut query = saved_messages::table
    .filter(saved_messages::uid.eq(uid))
    .into_boxed();
if let Some(chat_id) = chat_id {
    query = query.filter(saved_messages::original_chat_id.eq(chat_id));
}
if let Some(before) = before {
    query = query.filter(saved_messages::id.lt(before));
}
let rows = query
    .order(saved_messages::id.desc())
    .limit(limit + 1)
    .select(SavedMessage::as_select())
    .load::<SavedMessage>(conn)?;
```

Return `next_cursor` as the last returned saved row ID when `rows.len() > limit`.

- [ ] **Step 4: Add service tests for pure response conversion**

Add tests in the module for:

- `saved_messages_limit`.
- JSON deserialize failure returns `AppError::Internal` or a controlled internal error.
- Cursor helper returns `None` when there are no extra rows and `Some(last_id)` when there are extra rows.

- [ ] **Step 5: Run targeted backend tests**

Run:

```bash
cargo test services::saved_messages
```

Expected: all service tests pass.

- [ ] **Step 6: Commit saved-message service**

```bash
git add backend/src/services/saved_messages.rs
git commit -m "feat: snapshot saved messages"
```

## Task 4: Backend Handlers And Routes

**Files:**
- Create: `backend/src/handlers/saved_messages.rs`
- Create: `backend/src/handlers/chats/saved_messages.rs`
- Modify: `backend/src/handlers/mod.rs`
- Modify: `backend/src/handlers/chats/mod.rs`

- [ ] **Step 1: Add global saved-message handler**

Create `backend/src/handlers/saved_messages.rs`:

```rust
use axum::{extract::{Path, Query, State}, http::StatusCode, Json};
use serde::Deserialize;
use utoipa_axum::router::OpenApiRouter;

use crate::{
    dto::saved_messages::{ListSavedMessagesResponse, SavedMessageResponse},
    errors::AppError,
    extractors::DbConn,
    services::saved_messages as saved_svc,
    utils::auth::CurrentUid,
    AppState,
};

#[derive(Deserialize)]
struct MessageIdPath {
    #[serde(deserialize_with = "crate::serde_i64_string::deserialize")]
    message_id: i64,
}

#[derive(Deserialize)]
struct SavedMessageIdPath {
    #[serde(deserialize_with = "crate::serde_i64_string::deserialize")]
    saved_message_id: i64,
}

#[derive(Deserialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ListSavedMessagesQuery {
    #[serde(default)]
    limit: Option<i64>,
    #[serde(default, deserialize_with = "crate::serde_i64_string::opt::deserialize")]
    #[schema(value_type = Option<String>)]
    before: Option<i64>,
}

async fn put_saved_message(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(MessageIdPath { message_id }): Path<MessageIdPath>,
    mut conn: DbConn,
) -> Result<Json<SavedMessageResponse>, AppError> {
    let response = saved_svc::save_message_snapshot(&mut conn, &state, uid, message_id).await?;
    Ok(Json(response))
}

async fn delete_saved_message_by_original(
    CurrentUid(uid): CurrentUid,
    Path(MessageIdPath { message_id }): Path<MessageIdPath>,
    mut conn: DbConn,
) -> Result<StatusCode, AppError> {
    saved_svc::delete_saved_message_by_original(&mut conn, uid, message_id)?;
    Ok(StatusCode::NO_CONTENT)
}

async fn delete_saved_message_by_id(
    CurrentUid(uid): CurrentUid,
    Path(SavedMessageIdPath { saved_message_id }): Path<SavedMessageIdPath>,
    mut conn: DbConn,
) -> Result<StatusCode, AppError> {
    saved_svc::delete_saved_message_by_id(&mut conn, uid, saved_message_id)?;
    Ok(StatusCode::NO_CONTENT)
}

async fn list_saved_messages(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    mut conn: DbConn,
    Query(query): Query<ListSavedMessagesQuery>,
) -> Result<Json<ListSavedMessagesResponse>, AppError> {
    let response = saved_svc::list_saved_messages(&mut conn, &state, uid, None, query.before, query.limit)?;
    Ok(Json(response))
}

pub fn router() -> OpenApiRouter<AppState> {
    OpenApiRouter::new()
        .routes(utoipa_axum::routes!(list_saved_messages))
        .routes(utoipa_axum::routes!(put_saved_message))
        .routes(utoipa_axum::routes!(delete_saved_message_by_original))
        .routes(utoipa_axum::routes!(delete_saved_message_by_id))
}
```

Add `#[utoipa::path]` annotations to each handler before compiling:

- `PUT /saved-messages/{message_id}` returns `SavedMessageResponse`.
- `DELETE /saved-messages/by-message/{message_id}` returns `204`.
- `DELETE /saved-messages/{saved_message_id}` returns `204`.
- `GET /saved-messages` returns `ListSavedMessagesResponse`.
- `GET /chats/{chat_id}/saved-messages` returns `ListSavedMessagesResponse`.

Use `tag = "saved_messages"` for the global endpoints and `tag = "chats"` for the chat-scoped endpoint. Include the same `uid_header` and `bearer_jwt` security tuple used by existing chat routes.

- [ ] **Step 2: Add chat-scoped handler**

Create `backend/src/handlers/chats/saved_messages.rs`:

```rust
use axum::{extract::{Path, Query, State}, Json};
use serde::Deserialize;
use utoipa_axum::router::OpenApiRouter;

use crate::{
    dto::saved_messages::ListSavedMessagesResponse,
    errors::AppError,
    extractors::DbConn,
    handlers::chats::ChatIdPath,
    services::saved_messages as saved_svc,
    utils::auth::CurrentUid,
    AppState,
};

#[derive(Deserialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ListChatSavedMessagesQuery {
    #[serde(default)]
    limit: Option<i64>,
    #[serde(default, deserialize_with = "crate::serde_i64_string::opt::deserialize")]
    #[schema(value_type = Option<String>)]
    before: Option<i64>,
}

async fn list_chat_saved_messages(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(ChatIdPath { chat_id }): Path<ChatIdPath>,
    mut conn: DbConn,
    Query(query): Query<ListChatSavedMessagesQuery>,
) -> Result<Json<ListSavedMessagesResponse>, AppError> {
    let response = saved_svc::list_saved_messages(&mut conn, &state, uid, Some(chat_id), query.before, query.limit)?;
    Ok(Json(response))
}

pub fn router() -> OpenApiRouter<AppState> {
    OpenApiRouter::new().routes(utoipa_axum::routes!(list_chat_saved_messages))
}
```

- [ ] **Step 3: Mount routes**

In `backend/src/handlers/mod.rs`:

```rust
pub mod saved_messages;
```

And mount:

```rust
.nest("/saved-messages", saved_messages::router())
```

In `backend/src/handlers/chats/mod.rs`:

```rust
mod saved_messages;
```

And inside the chat nested router:

```rust
.nest("/saved-messages", self::saved_messages::router())
```

- [ ] **Step 4: Run backend compile/tests**

Run:

```bash
cargo fmt
cargo test saved_messages
cargo test handlers::chats::messages::tests::search_limit_defaults_to_twenty
```

Expected: formatting succeeds and targeted tests pass.

- [ ] **Step 5: Commit backend APIs**

```bash
git add backend/src/handlers backend/src/services/saved_messages.rs backend/src/dto
git commit -m "feat: expose saved message APIs"
```

## Task 5: PWA API And Navigation Helpers

**Files:**
- Create: `wetty-chat-mobile/src/api/savedMessages.ts`
- Create: `wetty-chat-mobile/src/utils/savedMessages.ts`
- Create: `wetty-chat-mobile/src/utils/savedMessages.test.ts`

- [ ] **Step 1: Add API types and calls**

Create `wetty-chat-mobile/src/api/savedMessages.ts`:

```ts
import type { AxiosResponse } from 'axios';
import type { MentionInfo, MessageResponse } from './messages';
import apiClient from './client';

export interface SavedAttachmentSnapshot {
  id: string;
  externalReference: string;
  url: string;
  kind: string;
  size: number;
  fileName: string;
  width?: number | null;
  height?: number | null;
  order: number;
}

export interface SavedStickerSnapshot {
  id: string;
  emoji: string;
  name?: string | null;
  mediaUrl: string;
  mediaContentType: string;
}

export interface SavedSenderSnapshot {
  uid: number;
  name: string | null;
  avatarUrl?: string | null;
  gender: number;
}

export interface SavedChatSnapshot {
  id: string;
  name: string | null;
  avatarUrl?: string | null;
}

export interface SavedMessageResponse {
  id: string;
  originalChatId: string;
  originalThreadRootId: string | null;
  originalMessageId: string;
  originalReplyToMessageId: string | null;
  originalSenderUid: number;
  originalCreatedAt: string;
  savedAt: string;
  message: string | null;
  messageType: MessageResponse['messageType'];
  attachments: SavedAttachmentSnapshot[];
  sticker?: SavedStickerSnapshot | null;
  mentions: MentionInfo[];
  sender: SavedSenderSnapshot;
  chat: SavedChatSnapshot;
  canLocateContext: boolean;
}

export interface ListSavedMessagesResponse {
  savedMessages: SavedMessageResponse[];
  nextCursor: string | null;
}

export function saveMessage(messageId: string): Promise<AxiosResponse<SavedMessageResponse>> {
  return apiClient.put(`/saved-messages/${messageId}`);
}

export function deleteSavedMessage(savedMessageId: string): Promise<AxiosResponse<void>> {
  return apiClient.delete(`/saved-messages/${savedMessageId}`);
}

export function deleteSavedMessageByOriginal(messageId: string): Promise<AxiosResponse<void>> {
  return apiClient.delete(`/saved-messages/by-message/${messageId}`);
}

export function listSavedMessages(params?: {
  limit?: number;
  before?: string | null;
}): Promise<AxiosResponse<ListSavedMessagesResponse>> {
  return apiClient.get('/saved-messages', { params: compactListParams(params) });
}

export function listChatSavedMessages(
  chatId: string,
  params?: { limit?: number; before?: string | null },
): Promise<AxiosResponse<ListSavedMessagesResponse>> {
  return apiClient.get(`/chats/${chatId}/saved-messages`, { params: compactListParams(params) });
}

function compactListParams(params?: { limit?: number; before?: string | null }): Record<string, string | number> {
  const query: Record<string, string | number> = {};
  if (params?.limit != null) query.limit = params.limit;
  if (params?.before) query.before = params.before;
  return query;
}
```

- [ ] **Step 2: Add route helper**

Create `wetty-chat-mobile/src/utils/savedMessages.ts`:

```ts
import type { SavedMessageResponse } from '@/api/savedMessages';

export interface SavedMessageTarget {
  pathname: string;
  hash: string;
}

export function buildSavedMessageTarget(saved: Pick<SavedMessageResponse, 'originalChatId' | 'originalMessageId' | 'originalThreadRootId'>): SavedMessageTarget {
  const chatId = encodeURIComponent(saved.originalChatId);
  const messageId = encodeURIComponent(saved.originalMessageId);

  if (saved.originalThreadRootId) {
    return {
      pathname: `/chats/chat/${chatId}/thread/${encodeURIComponent(saved.originalThreadRootId)}`,
      hash: `#msg=${messageId}`,
    };
  }

  return {
    pathname: `/chats/chat/${chatId}`,
    hash: `#msg=${messageId}`,
  };
}
```

- [ ] **Step 3: Add helper tests**

Create `wetty-chat-mobile/src/utils/savedMessages.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { buildSavedMessageTarget } from './savedMessages';

describe('buildSavedMessageTarget', () => {
  it('targets the main chat for top-level saved messages', () => {
    expect(
      buildSavedMessageTarget({
        originalChatId: '10',
        originalMessageId: '200',
        originalThreadRootId: null,
      }),
    ).toEqual({
      pathname: '/chats/chat/10',
      hash: '#msg=200',
    });
  });

  it('targets the thread route for saved thread replies', () => {
    expect(
      buildSavedMessageTarget({
        originalChatId: '10',
        originalMessageId: '201',
        originalThreadRootId: '150',
      }),
    ).toEqual({
      pathname: '/chats/chat/10/thread/150',
      hash: '#msg=201',
    });
  });
});
```

- [ ] **Step 4: Run frontend helper tests**

Run from `wetty-chat-mobile/`:

```bash
npm test -- --run src/utils/savedMessages.test.ts
```

Expected: new helper tests pass.

- [ ] **Step 5: Commit PWA API foundation**

```bash
git add wetty-chat-mobile/src/api/savedMessages.ts wetty-chat-mobile/src/utils/savedMessages.ts wetty-chat-mobile/src/utils/savedMessages.test.ts
git commit -m "feat: add saved message client API"
```

## Task 6: PWA Saved Message List UI

**Files:**
- Create: `wetty-chat-mobile/src/components/chat/saved/SavedMessageList.tsx`
- Create: `wetty-chat-mobile/src/components/chat/saved/SavedMessageList.module.scss`
- Create: `wetty-chat-mobile/src/pages/saved-messages.tsx`
- Create: `wetty-chat-mobile/src/pages/chat-thread/group-info/saved-messages.tsx`
- Modify: `wetty-chat-mobile/src/pages/chat-thread/group-info/index.ts`

- [ ] **Step 1: Create reusable list component**

Implement `SavedMessageList` with props:

```ts
interface SavedMessageListProps {
  chatId?: string;
  onOpenMessage: (saved: SavedMessageResponse) => void;
}
```

Behavior:

- Calls `listChatSavedMessages(chatId)` when `chatId` is present, otherwise `listSavedMessages()`.
- Renders loading spinner, empty state, error state, cards, and `Load More`.
- Uses `deleteSavedMessage(saved.id)` for card-level unsave and removes the row locally.
- Shows disabled locate text when `saved.canLocateContext` is false.
- Renders text, attachments summary, sticker summary, sender, chat label, original timestamp, and saved timestamp.

- [ ] **Step 2: Use Ionic-like card/list styling**

Use module SCSS classes:

```scss
.layout {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 12px 0 24px;
}

.state {
  align-items: center;
  color: var(--ion-color-medium);
  display: flex;
  justify-content: center;
  min-height: 160px;
  padding: 24px;
  text-align: center;
}

.card {
  background: var(--ion-item-background, #fff);
  border-radius: 12px;
  margin: 0 12px;
  padding: 12px;
}

.meta {
  align-items: center;
  color: var(--ion-color-medium);
  display: flex;
  font-size: 12px;
  gap: 8px;
  margin-bottom: 8px;
}

.message {
  color: var(--ion-text-color);
  font-size: 14px;
  line-height: 1.4;
  white-space: pre-wrap;
}

.attachments {
  color: var(--ion-color-medium);
  font-size: 12px;
  margin-top: 8px;
}

.actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 10px;
}
```

- [ ] **Step 3: Add global saved page**

Create `wetty-chat-mobile/src/pages/saved-messages.tsx` exporting `SavedMessagesCore` and default route page. It renders an Ionic page with title `Saved Messages`, `BackButton`, and `SavedMessageList`.

- [ ] **Step 4: Add group saved page**

Create `wetty-chat-mobile/src/pages/chat-thread/group-info/saved-messages.tsx` exporting `GroupSavedMessagesCore` and route page. It uses `useParams<{ id: string }>()`, title `Saved Messages`, and passes `chatId`.

- [ ] **Step 5: Export group saved page**

Update `wetty-chat-mobile/src/pages/chat-thread/group-info/index.ts`:

```ts
export { default, GroupInfoPage } from './group-info';
export { GroupSettingsCore, GroupSettingsPage } from './group-settings';
export { GroupSavedMessagesCore, GroupSavedMessagesPage } from './saved-messages';
```

- [ ] **Step 6: Run typecheck on new files**

Run:

```bash
npm run typecheck
```

Expected: no TypeScript errors.

- [ ] **Step 7: Commit list UI**

```bash
git add wetty-chat-mobile/src/components/chat/saved wetty-chat-mobile/src/pages/saved-messages.tsx wetty-chat-mobile/src/pages/chat-thread/group-info/saved-messages.tsx wetty-chat-mobile/src/pages/chat-thread/group-info/index.ts
git commit -m "feat: add saved message list UI"
```

## Task 7: PWA Routing, Entry Points, And Save Action

**Files:**
- Modify: `wetty-chat-mobile/src/layouts/MobileLayout.tsx`
- Modify: `wetty-chat-mobile/src/layouts/DesktopSplitLayout.tsx`
- Modify: `wetty-chat-mobile/src/pages/settings.tsx`
- Modify: `wetty-chat-mobile/src/pages/chat-thread/group-info/group-info.tsx`
- Modify: `wetty-chat-mobile/src/pages/chat-thread/chat-thread.tsx`

- [ ] **Step 1: Add mobile routes**

In `MobileLayout.tsx`, import the new pages and add exact routes before `/settings` and `/chats/chat/:id/group-info`:

```tsx
import SavedMessagesPage from '@/pages/saved-messages';
import { GroupSavedMessagesPage } from '@/pages/chat-thread/group-info';
```

```tsx
<Route path="/chats/chat/:id/group-info/saved-messages" exact component={GroupSavedMessagesPage} />
<Route path="/settings/saved-messages" exact component={SavedMessagesPage} />
```

- [ ] **Step 2: Add desktop route matches**

In `DesktopSplitLayout.tsx`, add:

```ts
groupSavedMessagesMatch: { id: string } | null;
savedMessages: boolean;
```

Match:

```ts
const groupSavedMessagesRaw = matchPath<{ id: string }>(pathname, {
  path: '/chats/chat/:id/group-info/saved-messages',
  exact: true,
});
const savedMessages = !!matchPath(pathname, {
  path: '/settings/saved-messages',
  exact: true,
});
```

Include `groupSavedMessagesRaw?.params.id` in `activeChatId` fallback and include `savedMessages` in `globalSettings`.

- [ ] **Step 3: Render desktop modals**

In the group info modal selection, render `GroupSavedMessagesCore` when `groupSavedMessagesMatch` is present and back to group info:

```tsx
<GroupSavedMessagesCore
  chatId={chatId}
  backAction={{ type: 'callback', onBack: () => history.push(`/chats/chat/${chatId}/group-info`) }}
/>
```

In the global settings modal, render `SavedMessagesCore` when `currentRoute.savedMessages` is true and back to `/settings`.

- [ ] **Step 4: Add Settings entry**

In `settings.tsx`, add `onOpenSavedMessages?: () => void` prop and a handler that pushes `/settings/saved-messages`. Add an Ionic list row under General:

```tsx
<IonItem button detail={true} onClick={handleOpenSavedMessages}>
  <IonIcon aria-hidden="true" icon={bookmarkOutline} slot="start" color="medium" />
  <IonLabel>
    <Trans>Saved Messages</Trans>
  </IonLabel>
</IonItem>
```

- [ ] **Step 5: Add Group Info entry**

In `group-info.tsx`, import `bookmarkOutline` and add a group settings action or list row:

```tsx
<GroupSettingsActionButton icon={bookmarkOutline} onClick={onOpenSavedMessages}>
  <Trans>Saved</Trans>
</GroupSettingsActionButton>
```

Route to `/chats/chat/${chatId}/group-info/saved-messages`.

- [ ] **Step 6: Add long-press Save action**

In `chat-thread.tsx`, import:

```ts
import { bookmarkOutline } from 'ionicons/icons';
import { saveMessage, deleteSavedMessageByOriginal } from '@/api/savedMessages';
```

For non-deleted, non-system confirmed messages, add:

```ts
actions.push({
  key: 'save',
  label: t`Save`,
  icon: bookmarkOutline,
  handler: () => {
    saveMessage(msg.id)
      .then(() => showToast(t`Message saved`, 1800))
      .catch((e: Error) => showToast(e.message || t`Failed to save message`));
  },
});
```

Do not add bubble badges or status lookups in V1. Saved-list views unsave from the card using the saved row ID.

- [ ] **Step 7: Extract Lingui strings**

Run:

```bash
npm run lingui:extract
```

Expected: catalogs update with `Saved Messages`, `Saved`, `Save`, `Message saved`, `Failed to save message`, `No saved messages`, `No access to original chat`, `Locate Context`, and `Unsave`.

- [ ] **Step 8: Run PWA verification**

Run:

```bash
npm run verify
npm test -- --run src/utils/savedMessages.test.ts
```

Expected: lint, typecheck, and helper tests pass.

- [ ] **Step 9: Commit PWA wiring**

```bash
git add wetty-chat-mobile/src wetty-chat-mobile/locales
git commit -m "feat: wire saved messages in PWA"
```

## Task 8: Full Verification And Review

**Files:**
- All files changed by prior tasks.

- [ ] **Step 1: Backend verification**

Run from `backend/`:

```bash
cargo fmt
cargo test
cargo clippy
```

Expected: all backend tests pass and clippy has no warnings.

- [ ] **Step 2: Frontend verification**

Run from `wetty-chat-mobile/`:

```bash
npm run verify
npm test -- --run src/utils/savedMessages.test.ts
```

Expected: verify and tests pass.

- [ ] **Step 3: Manual smoke test with local backend/PWA**

Start the backend and PWA according to the existing local workflow. Verify:

- Save a text message from the long-press menu.
- Save the same message twice and confirm no duplicate card appears.
- Save a message with an attachment and confirm the saved card renders attachment metadata.
- Open Group Info, then Saved Messages, and locate the saved message.
- Open Settings, then Saved Messages, and see the same saved message.
- Delete or edit the original and confirm the saved card still shows the original snapshot.
- Remove membership and confirm saved card remains visible while Locate Context is disabled.

- [ ] **Step 4: Final staged diff review**

Run:

```bash
git status --short
git diff --check
git diff --stat
```

Expected: no whitespace errors; changed files match the feature scope.

- [ ] **Step 5: Final commit if prior tasks were not committed separately**

If the implementation was batched instead of task-committed:

```bash
git add backend wetty-chat-mobile docs/superpowers
git commit -m "feat: add saved messages"
```
