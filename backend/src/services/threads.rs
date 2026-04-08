use chrono::{DateTime, Utc};
use diesel::prelude::*;
use diesel::sql_query;
use diesel::PgConnection;
use serde::Serialize;
use std::collections::HashMap;
use tracing::warn;

use crate::handlers::chats::{build_mention_info, extract_mention_uids, MentionInfo};
use crate::models::{Attachment, Message, MessageType};
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
                .and(thread_subscriptions::uid.eq(uid))
                .and(
                    thread_subscriptions::last_read_message_id
                        .is_null()
                        .or(thread_subscriptions::last_read_message_id.lt(message_id)),
                ),
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
    // Latest reply fields (from second LATERAL join)
    #[diesel(sql_type = diesel::sql_types::Nullable<diesel::sql_types::BigInt>)]
    pub latest_reply_id: Option<i64>,
    #[diesel(sql_type = diesel::sql_types::Nullable<diesel::sql_types::Text>)]
    pub latest_reply_message: Option<String>,
    #[diesel(sql_type = diesel::sql_types::Nullable<crate::schema::sql_types::MessageType>)]
    pub latest_reply_message_type: Option<MessageType>,
    #[diesel(sql_type = diesel::sql_types::Nullable<diesel::sql_types::Integer>)]
    pub latest_reply_sender_uid: Option<i32>,
    #[diesel(sql_type = diesel::sql_types::Nullable<diesel::sql_types::BigInt>)]
    pub latest_reply_sticker_id: Option<i64>,
    #[diesel(sql_type = diesel::sql_types::Nullable<diesel::sql_types::Bool>)]
    pub latest_reply_has_attachments: Option<bool>,
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
            ts.subscribed_at,
            latest_reply.id AS latest_reply_id,
            latest_reply.message AS latest_reply_message,
            latest_reply.message_type AS latest_reply_message_type,
            latest_reply.sender_uid AS latest_reply_sender_uid,
            latest_reply.sticker_id AS latest_reply_sticker_id,
            latest_reply.has_attachments AS latest_reply_has_attachments
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
        LEFT JOIN LATERAL (
            SELECT id, message, message_type, sender_uid, sticker_id, has_attachments
            FROM messages
            WHERE reply_root_id = ts.thread_root_id
              AND deleted_at IS NULL
            ORDER BY id DESC
            LIMIT 1
        ) latest_reply ON TRUE
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

#[derive(Debug, Serialize, Clone, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ThreadParticipant {
    pub uid: i32,
    pub name: Option<String>,
    pub avatar_url: Option<String>,
}

#[derive(Debug, Serialize, Clone, utoipa::ToSchema)]
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
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub mentions: Vec<MentionInfo>,
}

#[derive(Debug, Serialize, Clone, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ThreadRootMessagePreview {
    #[serde(with = "crate::serde_i64_string")]
    #[schema(value_type = String)]
    pub id: i64,
    pub sender: ThreadParticipant,
    pub message: Option<String>,
    pub message_type: MessageType,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub first_attachment_kind: Option<String>,
    pub is_deleted: bool,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub mentions: Vec<MentionInfo>,
}

#[derive(Serialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ThreadListItem {
    #[serde(with = "crate::serde_i64_string")]
    #[schema(value_type = String)]
    pub chat_id: i64,
    pub chat_name: String,
    pub chat_avatar: Option<String>,
    pub thread_root_message: ThreadRootMessagePreview,
    pub participants: Vec<ThreadParticipant>,
    pub last_reply: Option<ThreadReplyPreview>,
    pub reply_count: i64,
    pub last_reply_at: DateTime<Utc>,
    pub unread_count: i64,
    pub subscribed_at: DateTime<Utc>,
}

#[derive(Serialize, utoipa::ToSchema)]
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

/// Enrich a list of thread rows with participants, latest replies, user profiles,
/// and assemble the final `ListThreadsResponse`.
///
/// `rows` — the thread subscription rows (already trimmed to the page size).
/// `has_more` — whether there are more results beyond this page.
/// `root_messages` — raw root `Message` rows (no heavy enrichment needed).
/// `state` — application state (for avatar URLs, S3 URLs, etc.).
pub fn enrich_thread_list(
    conn: &mut PgConnection,
    rows: Vec<ThreadListRow>,
    has_more: bool,
    root_messages: Vec<Message>,
    state: &AppState,
) -> ListThreadsResponse {
    let root_ids: Vec<i64> = rows.iter().map(|r| r.thread_root_id).collect();

    if root_ids.is_empty() {
        return ListThreadsResponse {
            threads: vec![],
            next_cursor: None,
        };
    }

    let root_msg_map: HashMap<i64, &Message> = root_messages.iter().map(|m| (m.id, m)).collect();

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

    // 2. Collect ALL UIDs that need profile/avatar lookup in one pass:
    //    participants + latest reply senders + root message senders + mention UIDs
    let mut all_uids: Vec<i32> = participant_rows.iter().map(|r| r.sender_uid).collect();
    for row in &rows {
        if let Some(uid) = row.latest_reply_sender_uid {
            all_uids.push(uid);
        }
    }
    for msg in &root_messages {
        all_uids.push(msg.sender_uid);
    }

    // Pre-scan mentions from both root messages and latest replies
    let mut mention_uids_per_root: HashMap<i64, Vec<i32>> = HashMap::new();
    let mut mention_uids_per_reply: HashMap<i64, Vec<i32>> = HashMap::new();
    for msg in &root_messages {
        if let Some(ref text) = msg.message {
            let uids = extract_mention_uids(text);
            all_uids.extend(&uids);
            mention_uids_per_root.insert(msg.id, uids);
        }
    }
    for row in &rows {
        if let Some(ref text) = row.latest_reply_message {
            let uids = extract_mention_uids(text);
            all_uids.extend(&uids);
            mention_uids_per_reply.insert(row.thread_root_id, uids);
        }
    }

    all_uids.sort_unstable();
    all_uids.dedup();

    // Single batched profile + avatar lookup
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

    // 3. Build participants map: thread_root_id -> Vec<ThreadParticipant>
    let mut participants_map: HashMap<i64, Vec<ThreadParticipant>> = HashMap::new();
    for row in &participant_rows {
        participants_map
            .entry(row.reply_root_id)
            .or_default()
            .push(make_participant(row.sender_uid));
    }

    // 4. Load sticker emoji for latest replies
    let sticker_ids: Vec<i64> = rows
        .iter()
        .filter_map(|r| r.latest_reply_sticker_id)
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

    // 5. Batch load first attachment kind for both root messages and latest replies
    let mut attachment_msg_ids: Vec<i64> = rows
        .iter()
        .filter(|r| r.latest_reply_has_attachments.unwrap_or(false))
        .filter_map(|r| r.latest_reply_id)
        .collect();
    for msg in &root_messages {
        if msg.has_attachments {
            attachment_msg_ids.push(msg.id);
        }
    }
    let first_attachment_map: HashMap<i64, String> = if attachment_msg_ids.is_empty() {
        HashMap::new()
    } else {
        let atts: Vec<Attachment> = attachments::table
            .filter(attachments::message_id.eq_any(&attachment_msg_ids))
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

    // 6. Build latest reply map
    let mut latest_reply_map: HashMap<i64, ThreadReplyPreview> = HashMap::new();
    for row in &rows {
        if let (Some(reply_id), Some(message_type), Some(sender_uid)) = (
            row.latest_reply_id,
            row.latest_reply_message_type.clone(),
            row.latest_reply_sender_uid,
        ) {
            let has_attachments = row.latest_reply_has_attachments.unwrap_or(false);
            latest_reply_map.insert(
                row.thread_root_id,
                ThreadReplyPreview {
                    sender: make_participant(sender_uid),
                    message: row.latest_reply_message.clone(),
                    message_type,
                    sticker_emoji: row
                        .latest_reply_sticker_id
                        .and_then(|sid| sticker_emoji_map.get(&sid).cloned()),
                    first_attachment_kind: if has_attachments {
                        first_attachment_map.get(&reply_id).cloned()
                    } else {
                        None
                    },
                    is_deleted: false,
                    mentions: mention_uids_per_reply
                        .get(&row.thread_root_id)
                        .map(|uids| {
                            uids.iter()
                                .map(|&uid| build_mention_info(uid, &user_avatars, &user_profiles))
                                .collect()
                        })
                        .unwrap_or_default(),
                },
            );
        }
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
            let root_msg = root_msg_map.get(&row.thread_root_id)?;
            let root_preview = ThreadRootMessagePreview {
                id: root_msg.id,
                sender: make_participant(root_msg.sender_uid),
                message: root_msg.message.clone(),
                message_type: root_msg.message_type.clone(),
                first_attachment_kind: if root_msg.has_attachments {
                    first_attachment_map.get(&root_msg.id).cloned()
                } else {
                    None
                },
                is_deleted: false,
                mentions: mention_uids_per_root
                    .get(&root_msg.id)
                    .map(|uids| {
                        uids.iter()
                            .map(|&uid| build_mention_info(uid, &user_avatars, &user_profiles))
                            .collect()
                    })
                    .unwrap_or_default(),
            };
            Some(ThreadListItem {
                chat_id: row.chat_id,
                chat_name: row.chat_name,
                chat_avatar: row
                    .chat_avatar_key
                    .as_deref()
                    .map(|key| build_public_object_url(state, key)),
                thread_root_message: root_preview,
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
