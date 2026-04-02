use chrono::{DateTime, Utc};
use diesel::prelude::*;
use diesel::sql_query;
use diesel::PgConnection;
use serde::Serialize;
use std::collections::HashMap;
use tracing::warn;

use crate::handlers::chats::MessageResponse;
use crate::models::{Attachment, MessageType};
use crate::schema::{attachments, stickers, thread_subscriptions};
use crate::services::chat::MAX_UNREAD_COUNT;
use crate::services::media::build_public_object_url;
use crate::services::user::{lookup_user_avatars, lookup_user_profiles};
use crate::AppState;

/// Insert a subscription if one doesn't exist (auto-subscribe on participation).
pub fn ensure_thread_subscription(
    conn: &mut PgConnection,
    chat_id: i64,
    thread_root_id: i64,
    uid: i32,
) -> Result<(), diesel::result::Error> {
    diesel::insert_into(thread_subscriptions::table)
        .values((
            thread_subscriptions::chat_id.eq(chat_id),
            thread_subscriptions::thread_root_id.eq(thread_root_id),
            thread_subscriptions::uid.eq(uid),
            thread_subscriptions::subscribed_at.eq(Utc::now()),
        ))
        .on_conflict_do_nothing()
        .execute(conn)?;
    Ok(())
}

/// Explicit subscribe (for "Follow thread" button). Same upsert.
pub fn subscribe_to_thread(
    conn: &mut PgConnection,
    chat_id: i64,
    thread_root_id: i64,
    uid: i32,
) -> Result<(), diesel::result::Error> {
    ensure_thread_subscription(conn, chat_id, thread_root_id, uid)
}

/// Explicit unsubscribe (for "Unfollow thread" button).
pub fn unsubscribe_from_thread(
    conn: &mut PgConnection,
    chat_id: i64,
    thread_root_id: i64,
    uid: i32,
) -> Result<bool, diesel::result::Error> {
    let deleted = diesel::delete(
        thread_subscriptions::table.filter(
            thread_subscriptions::chat_id
                .eq(chat_id)
                .and(thread_subscriptions::thread_root_id.eq(thread_root_id))
                .and(thread_subscriptions::uid.eq(uid)),
        ),
    )
    .execute(conn)?;
    Ok(deleted > 0)
}

/// Check if a user is subscribed to a thread.
pub fn is_subscribed(
    conn: &mut PgConnection,
    chat_id: i64,
    thread_root_id: i64,
    uid: i32,
) -> Result<bool, diesel::result::Error> {
    diesel::select(diesel::dsl::exists(
        thread_subscriptions::table.filter(
            thread_subscriptions::chat_id
                .eq(chat_id)
                .and(thread_subscriptions::thread_root_id.eq(thread_root_id))
                .and(thread_subscriptions::uid.eq(uid)),
        ),
    ))
    .get_result(conn)
}

/// Update `last_read_message_id` for an existing subscription only.
pub fn mark_thread_as_read(
    conn: &mut PgConnection,
    thread_root_id: i64,
    uid: i32,
    message_id: i64,
) -> Result<bool, diesel::result::Error> {
    let updated = diesel::update(
        thread_subscriptions::table.filter(
            thread_subscriptions::thread_root_id
                .eq(thread_root_id)
                .and(thread_subscriptions::uid.eq(uid)),
        ),
    )
    .set(thread_subscriptions::last_read_message_id.eq(Some(message_id)))
    .execute(conn)?;
    Ok(updated > 0)
}

/// Get all UIDs subscribed to a given thread.
pub fn get_thread_subscriber_uids(
    conn: &mut PgConnection,
    chat_id: i64,
    thread_root_id: i64,
) -> Result<Vec<i32>, diesel::result::Error> {
    thread_subscriptions::table
        .filter(
            thread_subscriptions::chat_id
                .eq(chat_id)
                .and(thread_subscriptions::thread_root_id.eq(thread_root_id)),
        )
        .select(thread_subscriptions::uid)
        .load(conn)
}

#[derive(QueryableByName)]
pub struct ThreadListRow {
    #[diesel(sql_type = diesel::sql_types::BigInt)]
    pub chat_id: i64,
    #[diesel(sql_type = diesel::sql_types::BigInt)]
    pub thread_root_id: i64,
    #[diesel(sql_type = diesel::sql_types::Text)]
    pub chat_name: String,
    #[diesel(sql_type = diesel::sql_types::Nullable<diesel::sql_types::Text>)]
    pub chat_avatar_key: Option<String>,
    #[diesel(sql_type = diesel::sql_types::BigInt)]
    pub reply_count: i64,
    #[diesel(sql_type = diesel::sql_types::Timestamptz)]
    pub last_reply_at: DateTime<Utc>,
    #[diesel(sql_type = diesel::sql_types::BigInt)]
    pub unread_count: i64,
    #[diesel(sql_type = diesel::sql_types::Timestamptz)]
    pub subscribed_at: DateTime<Utc>,
}

/// List threads the user is subscribed to, ordered by most recent reply.
pub fn get_user_threads(
    conn: &mut PgConnection,
    uid: i32,
    limit: i64,
    before_cursor: Option<DateTime<Utc>>,
) -> Result<Vec<ThreadListRow>, diesel::result::Error> {
    let query = sql_query(
        "SELECT
            ts.chat_id,
            ts.thread_root_id,
            g.name AS chat_name,
            avatar_media.storage_key AS chat_avatar_key,
            COALESCE(thread_stats.reply_count, 0)::bigint AS reply_count,
            COALESCE(thread_stats.last_reply_at, ts.subscribed_at) AS last_reply_at,
            LEAST(
                COALESCE(thread_stats.unread_count, 0),
                $4
            )::bigint AS unread_count,
            ts.subscribed_at
        FROM thread_subscriptions ts
        JOIN groups g ON g.id = ts.chat_id
        LEFT JOIN media avatar_media ON g.avatar_image_id = avatar_media.id AND avatar_media.deleted_at IS NULL
        JOIN messages root_msg ON root_msg.id = ts.thread_root_id
        LEFT JOIN LATERAL (
            SELECT
                COUNT(*)::bigint AS reply_count,
                MAX(m.created_at) AS last_reply_at,
                COUNT(*) FILTER (
                    WHERE m.id > COALESCE(ts.last_read_message_id, 0)
                )::bigint AS unread_count
            FROM messages m
            WHERE m.reply_root_id = ts.thread_root_id
              AND m.deleted_at IS NULL
        ) thread_stats ON TRUE
        WHERE ts.uid = $1
          AND root_msg.deleted_at IS NULL
          AND ($2::timestamptz IS NULL OR COALESCE(thread_stats.last_reply_at, ts.subscribed_at) < $2)
        ORDER BY COALESCE(thread_stats.last_reply_at, ts.subscribed_at) DESC
        LIMIT $3",
    )
    .bind::<diesel::sql_types::Integer, _>(uid)
    .bind::<diesel::sql_types::Nullable<diesel::sql_types::Timestamptz>, _>(before_cursor)
    .bind::<diesel::sql_types::BigInt, _>(limit)
    .bind::<diesel::sql_types::BigInt, _>(MAX_UNREAD_COUNT);

    match query.load::<ThreadListRow>(conn) {
        Ok(rows) => Ok(rows),
        Err(e) => {
            warn!("Failed to load user threads: {:?}", e);
            Err(e)
        }
    }
}

#[derive(QueryableByName)]
struct UnreadThreadCountRow {
    #[diesel(sql_type = diesel::sql_types::BigInt)]
    unread_thread_count: i64,
}

/// Count of subscribed threads that have at least one unread reply.
pub fn get_total_unread_thread_count(
    conn: &mut PgConnection,
    uid: i32,
) -> Result<i64, diesel::result::Error> {
    let query = sql_query(
        "SELECT COUNT(*)::bigint AS unread_thread_count
         FROM thread_subscriptions ts
         JOIN messages root_msg ON root_msg.id = ts.thread_root_id
         WHERE ts.uid = $1
           AND root_msg.deleted_at IS NULL
           AND EXISTS (
               SELECT 1 FROM messages m
               WHERE m.reply_root_id = ts.thread_root_id
                 AND m.deleted_at IS NULL
                 AND m.id > COALESCE(ts.last_read_message_id, 0)
           )",
    )
    .bind::<diesel::sql_types::Integer, _>(uid);

    query
        .get_result::<UnreadThreadCountRow>(conn)
        .map(|row| row.unread_thread_count)
}

// --- Thread list enrichment types and logic ---

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

/// Enrich a list of thread rows with participants, latest replies, user profiles,
/// and assemble the final `ListThreadsResponse`.
///
/// `rows` — the thread subscription rows (already trimmed to the page size).
/// `has_more` — whether there are more results beyond this page.
/// `msg_map` — root messages already enriched via `attach_metadata`, keyed by message id.
/// `state` — application state (for avatar URLs, S3 URLs, etc.).
pub fn enrich_thread_list(
    conn: &mut PgConnection,
    rows: Vec<ThreadListRow>,
    has_more: bool,
    mut msg_map: HashMap<i64, MessageResponse>,
    state: &AppState,
) -> ListThreadsResponse {
    let root_ids: Vec<i64> = rows.iter().map(|r| r.thread_root_id).collect();

    if root_ids.is_empty() {
        return ListThreadsResponse {
            threads: vec![],
            next_cursor: None,
        };
    }

    // 1. Batch query: distinct participants per thread (replies + root message author)
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

    // 2. Batch query: latest reply per thread
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

    // 3. Collect all UIDs that need profile/avatar lookup
    let mut all_uids: Vec<i32> = participant_rows.iter().map(|r| r.sender_uid).collect();
    for row in &latest_reply_rows {
        all_uids.push(row.sender_uid);
    }
    all_uids.sort_unstable();
    all_uids.dedup();

    let user_profiles = lookup_user_profiles(conn, &all_uids).unwrap_or_default();
    let user_avatars = lookup_user_avatars(state, &all_uids);

    let make_participant = |uid: i32| -> ThreadParticipant {
        let profile = user_profiles.get(&uid);
        ThreadParticipant {
            uid,
            name: profile.and_then(|p| p.username.clone()),
            avatar_url: user_avatars.get(&uid).cloned().flatten(),
        }
    };

    // 4. Build participants map: thread_root_id -> Vec<ThreadParticipant>
    let mut participants_map: HashMap<i64, Vec<ThreadParticipant>> = HashMap::new();
    for row in &participant_rows {
        participants_map
            .entry(row.reply_root_id)
            .or_default()
            .push(make_participant(row.sender_uid));
    }

    // 5. Build latest reply map, load sticker emoji and first attachment kind
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

    // 6. Assemble final response
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
                    .map(|key| build_public_object_url(state, key)),
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

    ListThreadsResponse {
        threads,
        next_cursor,
    }
}
