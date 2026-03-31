use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    Json, Router,
};
use chrono::{DateTime, Utc};
use diesel::prelude::*;
use diesel::sql_query;
use serde::Serialize;
use std::collections::HashMap;

use crate::{
    handlers::chats::MessageResponse,
    handlers::members::check_membership,
    models::{Attachment, Message, MessageType},
    schema::{attachments, messages, stickers},
    services::{
        media::build_public_object_url,
        threads as thread_svc,
        user::{lookup_user_avatars, lookup_user_profiles},
    },
    utils::auth::CurrentUid,
    AppState,
};

// Re-use the attach_metadata function from chats
use crate::handlers::chats::attach_metadata;

#[derive(serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ListThreadsQuery {
    #[serde(default)]
    limit: Option<i64>,
    #[serde(default)]
    before: Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ThreadParticipant {
    pub uid: i32,
    pub name: Option<String>,
    pub avatar_url: Option<String>,
}

#[derive(Debug, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ThreadReplyPreview {
    pub sender: ThreadParticipant,
    pub message: Option<String>,
    pub message_type: MessageType,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sticker_emoji: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub first_attachment_kind: Option<String>,
    pub is_deleted: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ThreadListItem {
    #[serde(with = "crate::serde_i64_string")]
    pub chat_id: i64,
    pub chat_name: String,
    pub chat_avatar: Option<String>,
    pub thread_root_message: MessageResponse,
    pub participants: Vec<ThreadParticipant>,
    pub last_reply: Option<ThreadReplyPreview>,
    pub reply_count: i64,
    pub last_reply_at: DateTime<Utc>,
    pub unread_count: i64,
    pub subscribed_at: DateTime<Utc>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ListThreadsResponse {
    pub threads: Vec<ThreadListItem>,
    pub next_cursor: Option<String>,
}

// Raw row types for batch queries
#[derive(QueryableByName)]
struct ParticipantRow {
    #[diesel(sql_type = diesel::sql_types::BigInt)]
    reply_root_id: i64,
    #[diesel(sql_type = diesel::sql_types::Integer)]
    sender_uid: i32,
}

#[derive(QueryableByName)]
struct LatestReplyRow {
    #[diesel(sql_type = diesel::sql_types::BigInt)]
    reply_root_id: i64,
    #[diesel(sql_type = diesel::sql_types::BigInt)]
    id: i64,
    #[diesel(sql_type = diesel::sql_types::Nullable<diesel::sql_types::Text>)]
    message: Option<String>,
    #[diesel(sql_type = crate::schema::sql_types::MessageType)]
    message_type: MessageType,
    #[diesel(sql_type = diesel::sql_types::Integer)]
    sender_uid: i32,
    #[diesel(sql_type = diesel::sql_types::Nullable<diesel::sql_types::BigInt>)]
    sticker_id: Option<i64>,
    #[diesel(sql_type = diesel::sql_types::Bool)]
    has_attachments: bool,
}

/// GET /threads — List threads the user is subscribed to.
async fn get_threads(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Query(query): Query<ListThreadsQuery>,
) -> Result<Json<ListThreadsResponse>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    let limit = query.limit.unwrap_or(20).min(50);
    let rows = thread_svc::get_user_threads(conn, uid, limit + 1, query.before).map_err(|e| {
        tracing::error!("get_user_threads: {:?}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, "Failed to load threads")
    })?;

    let has_more = rows.len() as i64 > limit;
    let rows: Vec<_> = rows.into_iter().take(limit as usize).collect();

    let root_ids: Vec<i64> = rows.iter().map(|r| r.thread_root_id).collect();

    if root_ids.is_empty() {
        return Ok(Json(ListThreadsResponse {
            threads: vec![],
            next_cursor: None,
        }));
    }

    // 1. Load root messages and enrich with metadata
    let root_messages: Vec<Message> = messages::table
        .filter(messages::id.eq_any(&root_ids))
        .select(Message::as_select())
        .load(conn)
        .map_err(|e| {
            tracing::error!("load thread root messages: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to load thread messages",
            )
        })?;

    let enriched = attach_metadata(conn, root_messages, &state, uid).await;
    let mut msg_map: HashMap<i64, MessageResponse> =
        enriched.into_iter().map(|m| (m.id, m)).collect();

    // 2. Batch query: distinct participants per thread (replies + root message author)
    let participant_rows: Vec<ParticipantRow> = sql_query(
        "SELECT DISTINCT reply_root_id, sender_uid FROM (
            SELECT m.reply_root_id, m.sender_uid
            FROM messages m
            WHERE m.reply_root_id = ANY($1)
              AND m.deleted_at IS NULL
            UNION ALL
            SELECT root.id AS reply_root_id, root.sender_uid
            FROM messages root
            WHERE root.id = ANY($1)
              AND root.deleted_at IS NULL
         ) combined
         ORDER BY reply_root_id, sender_uid",
    )
    .bind::<diesel::sql_types::Array<diesel::sql_types::BigInt>, _>(&root_ids)
    .load(conn)
    .unwrap_or_default();

    // 3. Batch query: latest reply per thread
    let latest_reply_rows: Vec<LatestReplyRow> = sql_query(
        "SELECT DISTINCT ON (m.reply_root_id)
            m.reply_root_id, m.id, m.message, m.message_type,
            m.sender_uid, m.sticker_id, m.has_attachments
         FROM messages m
         WHERE m.reply_root_id = ANY($1)
           AND m.deleted_at IS NULL
         ORDER BY m.reply_root_id, m.id DESC",
    )
    .bind::<diesel::sql_types::Array<diesel::sql_types::BigInt>, _>(&root_ids)
    .load(conn)
    .unwrap_or_default();

    // 4. Collect all UIDs that need profile/avatar lookup
    let mut all_uids: Vec<i32> = participant_rows.iter().map(|r| r.sender_uid).collect();
    for row in &latest_reply_rows {
        all_uids.push(row.sender_uid);
    }
    all_uids.sort_unstable();
    all_uids.dedup();

    let user_profiles = lookup_user_profiles(conn, &all_uids).unwrap_or_default();
    let user_avatars = lookup_user_avatars(&state, &all_uids);

    let make_participant = |uid: i32| -> ThreadParticipant {
        let profile = user_profiles.get(&uid);
        ThreadParticipant {
            uid,
            name: profile.and_then(|p| p.username.clone()),
            avatar_url: user_avatars.get(&uid).cloned().flatten(),
        }
    };

    // 5. Build participants map: thread_root_id -> Vec<ThreadParticipant>
    let mut participants_map: HashMap<i64, Vec<ThreadParticipant>> = HashMap::new();
    for row in &participant_rows {
        participants_map
            .entry(row.reply_root_id)
            .or_default()
            .push(make_participant(row.sender_uid));
    }

    // 6. Build latest reply map, load sticker emoji and first attachment kind
    let sticker_ids: Vec<i64> = latest_reply_rows
        .iter()
        .filter_map(|r| r.sticker_id)
        .collect();
    let sticker_emoji_map: HashMap<i64, String> = if sticker_ids.is_empty() {
        HashMap::new()
    } else {
        stickers::table
            .filter(stickers::id.eq_any(&sticker_ids))
            .select((stickers::id, stickers::emoji))
            .load::<(i64, String)>(conn)
            .unwrap_or_default()
            .into_iter()
            .collect()
    };

    let reply_msg_ids: Vec<i64> = latest_reply_rows
        .iter()
        .filter(|r| r.has_attachments)
        .map(|r| r.id)
        .collect();
    let first_attachment_map: HashMap<i64, String> = if reply_msg_ids.is_empty() {
        HashMap::new()
    } else {
        // Load first attachment kind per message
        let atts: Vec<Attachment> = attachments::table
            .filter(attachments::message_id.eq_any(&reply_msg_ids))
            .select(Attachment::as_select())
            .load(conn)
            .unwrap_or_default();
        let mut map: HashMap<i64, String> = HashMap::new();
        for att in atts {
            if let Some(msg_id) = att.message_id {
                map.entry(msg_id).or_insert(att.kind);
            }
        }
        map
    };

    let mut latest_reply_map: HashMap<i64, ThreadReplyPreview> = HashMap::new();
    for row in latest_reply_rows {
        latest_reply_map.insert(
            row.reply_root_id,
            ThreadReplyPreview {
                sender: make_participant(row.sender_uid),
                message: row.message,
                message_type: row.message_type,
                sticker_emoji: row
                    .sticker_id
                    .and_then(|sid| sticker_emoji_map.get(&sid).cloned()),
                first_attachment_kind: if row.has_attachments {
                    first_attachment_map.get(&row.id).cloned()
                } else {
                    None
                },
                is_deleted: false,
            },
        );
    }

    // 7. Assemble final response
    let next_cursor = if has_more {
        rows.last().map(|r| r.last_reply_at.to_rfc3339())
    } else {
        None
    };

    let threads: Vec<ThreadListItem> = rows
        .into_iter()
        .filter_map(|row| {
            let root_msg = msg_map.remove(&row.thread_root_id)?;
            Some(ThreadListItem {
                chat_id: row.chat_id,
                chat_name: row.chat_name,
                chat_avatar: row
                    .chat_avatar_key
                    .as_deref()
                    .map(|key| build_public_object_url(&state, key)),
                thread_root_message: root_msg,
                participants: participants_map
                    .remove(&row.thread_root_id)
                    .unwrap_or_default(),
                last_reply: latest_reply_map.remove(&row.thread_root_id),
                reply_count: row.reply_count,
                last_reply_at: row.last_reply_at,
                unread_count: row.unread_count,
                subscribed_at: row.subscribed_at,
            })
        })
        .collect();

    Ok(Json(ListThreadsResponse {
        threads,
        next_cursor,
    }))
}

#[derive(serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MarkThreadReadBody {
    #[serde(deserialize_with = "crate::serde_i64_string::deserialize")]
    message_id: i64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct MarkThreadReadResponse {
    updated: bool,
}

#[derive(serde::Deserialize)]
pub struct ThreadRootIdPath {
    #[serde(deserialize_with = "crate::serde_i64_string::deserialize")]
    thread_root_id: i64,
}

/// POST /threads/:thread_root_id/read — Mark a thread as read.
async fn mark_thread_read(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(ThreadRootIdPath { thread_root_id }): Path<ThreadRootIdPath>,
    Json(body): Json<MarkThreadReadBody>,
) -> Result<Json<MarkThreadReadResponse>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    let updated = thread_svc::mark_thread_as_read(conn, thread_root_id, uid, body.message_id)
        .map_err(|e| {
            tracing::error!("mark_thread_as_read: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to mark thread as read",
            )
        })?;

    Ok(Json(MarkThreadReadResponse { updated }))
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct UnreadThreadCountResponse {
    unread_thread_count: i64,
}

/// GET /threads/unread — Get total unread thread count for the current user.
async fn get_unread_thread_count(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
) -> Result<Json<UnreadThreadCountResponse>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    let count = thread_svc::get_total_unread_thread_count(conn, uid).map_err(|e| {
        tracing::error!("get_total_unread_thread_count: {:?}", e);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Failed to load unread thread count",
        )
    })?;

    Ok(Json(UnreadThreadCountResponse {
        unread_thread_count: count,
    }))
}

#[derive(serde::Deserialize)]
pub struct ThreadSubscribePath {
    chat_id: i64,
    #[serde(deserialize_with = "crate::serde_i64_string::deserialize")]
    thread_root_id: i64,
}

/// PUT /chats/:chat_id/threads/:thread_root_id/subscribe — Follow a thread.
async fn subscribe_thread(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(ThreadSubscribePath {
        chat_id,
        thread_root_id,
    }): Path<ThreadSubscribePath>,
) -> Result<StatusCode, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    check_membership(conn, chat_id, uid)?;

    // Verify the thread root message exists
    let exists: bool = diesel::select(diesel::dsl::exists(
        messages::table.filter(
            messages::id
                .eq(thread_root_id)
                .and(messages::chat_id.eq(chat_id)),
        ),
    ))
    .get_result(conn)
    .map_err(|e| {
        tracing::error!("check thread root exists: {:?}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
    })?;

    if !exists {
        return Err((StatusCode::NOT_FOUND, "Thread root message not found"));
    }

    thread_svc::subscribe_to_thread(conn, chat_id, thread_root_id, uid).map_err(|e| {
        tracing::error!("subscribe_to_thread: {:?}", e);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Failed to subscribe to thread",
        )
    })?;

    Ok(StatusCode::NO_CONTENT)
}

/// DELETE /chats/:chat_id/threads/:thread_root_id/subscribe — Unfollow a thread.
async fn unsubscribe_thread(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(ThreadSubscribePath {
        chat_id,
        thread_root_id,
    }): Path<ThreadSubscribePath>,
) -> Result<StatusCode, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    check_membership(conn, chat_id, uid)?;

    thread_svc::unsubscribe_from_thread(conn, chat_id, thread_root_id, uid).map_err(|e| {
        tracing::error!("unsubscribe_from_thread: {:?}", e);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Failed to unsubscribe from thread",
        )
    })?;

    Ok(StatusCode::NO_CONTENT)
}

#[derive(serde::Deserialize)]
pub struct ThreadSubscriptionStatusPath {
    chat_id: i64,
    #[serde(deserialize_with = "crate::serde_i64_string::deserialize")]
    thread_root_id: i64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct ThreadSubscriptionStatusResponse {
    subscribed: bool,
}

/// GET /chats/:chat_id/threads/:thread_root_id/subscribe — Check subscription status.
async fn get_subscription_status(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(ThreadSubscriptionStatusPath {
        chat_id,
        thread_root_id,
    }): Path<ThreadSubscriptionStatusPath>,
) -> Result<Json<ThreadSubscriptionStatusResponse>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    check_membership(conn, chat_id, uid)?;

    let subscribed =
        thread_svc::is_subscribed(conn, chat_id, thread_root_id, uid).map_err(|e| {
            tracing::error!("is_subscribed: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;

    Ok(Json(ThreadSubscriptionStatusResponse { subscribed }))
}

pub fn router() -> Router<crate::AppState> {
    use axum::routing::*;
    Router::new()
        .route("/", get(get_threads))
        .route("/unread", get(get_unread_thread_count))
        .route("/{thread_root_id}/read", post(mark_thread_read))
}

/// Routes that are nested under /chats/:chat_id/threads/:thread_root_id
pub fn subscribe_router() -> Router<crate::AppState> {
    use axum::routing::*;
    Router::new().route(
        "/subscribe",
        get(get_subscription_status)
            .put(subscribe_thread)
            .delete(unsubscribe_thread),
    )
}
