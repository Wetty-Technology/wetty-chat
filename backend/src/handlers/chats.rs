use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::IntoResponse,
    Json, Router,
};
use chrono::{DateTime, Utc};
use diesel::prelude::*;
use serde::Serialize;

use crate::{
    handlers::members::check_membership,
    models::NewMessage,
    services::{
        media::build_public_object_url,
        push::{PushJob, PushMessagePreview, PushMessagePreviewSticker},
        user::{lookup_user_avatars, lookup_user_profiles, UserProfile},
    },
    utils::{auth::CurrentUid, ids},
};
use crate::{
    models::{
        Attachment,
        AttachmentResponse,
        Media,
        Message,
        MessageReaction,
        MessageType,
        Sender,
        Sticker,
        ThreadInfo, //
    },
    schema::{
        attachments,
        group_membership,
        groups,
        media,
        message_reactions,
        messages, //
        sticker_pack_stickers,
        sticker_packs,
        stickers,
        user_favorite_stickers,
        user_sticker_pack_subscriptions,
    },
};
use crate::{AppState, MAX_CHATS_LIMIT, MAX_MESSAGES_LIMIT};
use unicode_segmentation::UnicodeSegmentation;

// ---------------------------------------------------------------------------
// Mention extraction
// ---------------------------------------------------------------------------

/// Parsed mention info for serialization in `MessageResponse`.
#[derive(Debug, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct MentionInfo {
    pub uid: i32,
    pub username: Option<String>,
}

/// Extract `@[uid:<N>]` tokens from a message string.
fn extract_mention_uids(text: &str) -> Vec<i32> {
    let mut uids = Vec::new();

    let bytes = text.as_bytes();
    let len = bytes.len();
    let mut i = 0;

    while i < len {
        if bytes[i] == b'@' && i + 1 < len && bytes[i + 1] == b'[' {
            if let Some(rest) = text.get(i + 2..) {
                if let Some(close) = rest.find(']') {
                    let inner = &rest[..close];
                    if let Some(id_str) = inner.strip_prefix("uid:") {
                        if let Ok(uid) = id_str.parse::<i32>() {
                            if !uids.contains(&uid) {
                                uids.push(uid);
                            }
                            i += 2 + close + 1;
                            continue;
                        }
                    }
                }
            }
        }
        i += 1;
    }

    uids
}

// Queryable struct replaced by raw tuples

#[derive(serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ListChatsQuery {
    #[serde(default)]
    limit: Option<i64>,
    #[serde(
        default,
        deserialize_with = "crate::serde_i64_string::opt::deserialize"
    )]
    after: Option<i64>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ChatListItem {
    #[serde(with = "crate::serde_i64_string")]
    id: i64,
    name: Option<String>,
    avatar: Option<String>,
    last_message_at: Option<DateTime<Utc>>,
    unread_count: i64,
    #[serde(with = "crate::serde_i64_string::opt")]
    last_read_message_id: Option<i64>,
    last_message: Option<MessageResponse>,
    muted_until: Option<DateTime<Utc>>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ListChatsResponse {
    chats: Vec<ChatListItem>,
    #[serde(with = "crate::serde_i64_string::opt")]
    next_cursor: Option<i64>,
}

/// GET /chats — List chats for the current user (cursor-based).
async fn get_chats(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Query(q): Query<ListChatsQuery>,
) -> Result<Json<ListChatsResponse>, (StatusCode, &'static str)> {
    let limit = q
        .limit
        .map(|l| std::cmp::min(l, MAX_CHATS_LIMIT))
        .unwrap_or(MAX_CHATS_LIMIT)
        .max(1);

    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    let unread_count_sq = diesel::dsl::sql::<diesel::sql_types::BigInt>(
        "(SELECT count(*) FROM (
            SELECT 1
            FROM messages
            WHERE
                chat_id = groups.id
            AND
                reply_root_id IS NULL
            AND
                deleted_at IS NULL
            AND
                id > COALESCE(group_membership.last_read_message_id, 0)
            LIMIT 100
        ) AS unread_messages)",
    );

    let base_query = groups::table
        .inner_join(group_membership::table)
        .left_join(messages::table.on(groups::last_message_id.eq(messages::id.nullable())))
        .left_join(
            media::table.on(groups::avatar_image_id
                .eq(media::id.nullable())
                .and(media::deleted_at.is_null())),
        )
        .filter(group_membership::uid.eq(uid));

    type RowType = (
        i64,
        String,
        Option<String>,
        Option<DateTime<Utc>>,
        i64,
        Option<i64>,
        Option<crate::models::Message>,
        Option<DateTime<Utc>>,
    );

    let rows: Vec<RowType> = match q.after {
        None => base_query
            .select((
                groups::id,
                groups::name,
                media::storage_key.nullable(),
                groups::last_message_at,
                unread_count_sq.clone(),
                group_membership::last_read_message_id,
                messages::all_columns.nullable(),
                group_membership::muted_until,
            ))
            .order_by((
                groups::last_message_at.desc().nulls_last(),
                groups::id.desc(),
            ))
            .limit(limit + 1)
            .load(conn)
            .map_err(|e| {
                tracing::error!("list chats: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, "Failed to list chats")
            })?,
        Some(after_id) => {
            let cursor_at: Option<Option<DateTime<Utc>>> = groups::table
                .inner_join(group_membership::table)
                .filter(group_membership::uid.eq(uid))
                .filter(groups::id.eq(after_id))
                .select(groups::last_message_at)
                .first(conn)
                .optional()
                .map_err(|e| {
                    tracing::error!("list chats cursor: {:?}", e);
                    (StatusCode::INTERNAL_SERVER_ERROR, "Failed to list chats")
                })?;

            let cursor_at = match cursor_at {
                Some(c) => c,
                None => {
                    return Ok(Json(ListChatsResponse {
                        chats: vec![],
                        next_cursor: None,
                    }))
                }
            };
            let cursor_id = after_id;

            match cursor_at {
                Some(c_at) => base_query
                    .select((
                        groups::id,
                        groups::name,
                        media::storage_key.nullable(),
                        groups::last_message_at,
                        unread_count_sq.clone(),
                        group_membership::last_read_message_id,
                        messages::all_columns.nullable(),
                        group_membership::muted_until,
                    ))
                    .filter(
                        groups::last_message_at
                            .lt(c_at)
                            .or(groups::last_message_at
                                .eq(c_at)
                                .and(groups::id.lt(cursor_id)))
                            .or(groups::last_message_at.is_null()),
                    )
                    .order_by((
                        groups::last_message_at.desc().nulls_last(),
                        groups::id.desc(),
                    ))
                    .limit(limit + 1)
                    .load(conn)
                    .map_err(|e| {
                        tracing::error!("list chats after: {:?}", e);
                        (StatusCode::INTERNAL_SERVER_ERROR, "Failed to list chats")
                    })?,
                None => base_query
                    .select((
                        groups::id,
                        groups::name,
                        media::storage_key.nullable(),
                        groups::last_message_at,
                        unread_count_sq.clone(),
                        group_membership::last_read_message_id,
                        messages::all_columns.nullable(),
                        group_membership::muted_until,
                    ))
                    .filter(
                        groups::last_message_at
                            .is_null()
                            .and(groups::id.lt(cursor_id)),
                    )
                    .order_by((
                        groups::last_message_at.desc().nulls_last(),
                        groups::id.desc(),
                    ))
                    .limit(limit + 1)
                    .load(conn)
                    .map_err(|e| {
                        tracing::error!("list chats after: {:?}", e);
                        (StatusCode::INTERNAL_SERVER_ERROR, "Failed to list chats")
                    })?,
            }
        }
    };

    let has_more = rows.len() as i64 > limit;
    let items_to_process: Vec<RowType> = rows.into_iter().take(limit as usize).collect();

    let messages_to_process: Vec<crate::models::Message> = items_to_process
        .iter()
        .filter_map(|(_, _, _, _, _, _, msg, _)| msg.clone())
        .collect();

    let message_responses = attach_metadata(conn, messages_to_process, &state, uid).await;

    let mut message_response_map: std::collections::HashMap<i64, MessageResponse> =
        message_responses
            .into_iter()
            .map(|mr| (mr.id, mr))
            .collect();

    let chats: Vec<ChatListItem> = items_to_process
        .into_iter()
        .map(
            |(
                id,
                name,
                avatar_key,
                last_message_at,
                unread_count,
                last_read_message_id,
                msg,
                muted_until,
            )| {
                let mr = msg.and_then(|m| message_response_map.remove(&m.id));
                ChatListItem {
                    id,
                    name: Some(name),
                    avatar: avatar_key
                        .as_deref()
                        .map(|storage_key| build_public_object_url(&state, storage_key)),
                    last_message_at,
                    unread_count,
                    last_read_message_id,
                    last_message: mr,
                    muted_until,
                }
            },
        )
        .collect();

    let next_cursor = has_more.then(|| chats.last().map(|c| c.id)).flatten();

    Ok(Json(ListChatsResponse { chats, next_cursor }))
}

#[derive(serde::Deserialize)]
pub struct ChatIdPath {
    chat_id: i64,
}

#[derive(serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ListMessagesQuery {
    #[serde(
        default,
        deserialize_with = "crate::serde_i64_string::opt::deserialize"
    )]
    before: Option<i64>,
    #[serde(
        default,
        deserialize_with = "crate::serde_i64_string::opt::deserialize"
    )]
    around: Option<i64>,
    #[serde(
        default,
        deserialize_with = "crate::serde_i64_string::opt::deserialize"
    )]
    after: Option<i64>,
    #[serde(default)]
    max: Option<i64>,
    #[serde(
        default,
        deserialize_with = "crate::serde_i64_string::opt::deserialize"
    )]
    thread_id: Option<i64>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ListMessagesResponse {
    messages: Vec<MessageResponse>,
    #[serde(with = "crate::serde_i64_string::opt")]
    next_cursor: Option<i64>,
    #[serde(with = "crate::serde_i64_string::opt")]
    prev_cursor: Option<i64>,
}

#[derive(Debug, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct MessageResponse {
    #[serde(with = "crate::serde_i64_string")]
    pub id: i64,
    pub message: Option<String>,
    pub message_type: MessageType,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sticker: Option<MessageStickerResponse>,
    #[serde(with = "crate::serde_i64_string::opt")]
    pub reply_root_id: Option<i64>,
    pub client_generated_id: String,
    pub sender: Sender,
    #[serde(with = "crate::serde_i64_string")]
    pub chat_id: i64,
    pub created_at: DateTime<Utc>,
    pub is_edited: bool,
    pub is_deleted: bool,
    pub has_attachments: bool,
    pub thread_info: Option<ThreadInfo>,
    pub reply_to_message: Option<Box<ReplyToMessage>>,
    pub attachments: Vec<AttachmentResponse>,
    pub reactions: Vec<ReactionSummary>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub mentions: Vec<MentionInfo>,
}

#[derive(Debug, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ReactionReactor {
    pub uid: i32,
    pub name: Option<String>,
    pub avatar_url: Option<String>,
}

#[derive(Debug, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ReactionSummary {
    pub emoji: String,
    pub count: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reacted_by_me: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reactors: Option<Vec<ReactionReactor>>,
}

#[derive(Debug, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ReplyToMessage {
    #[serde(with = "crate::serde_i64_string")]
    id: i64,
    message: Option<String>,
    message_type: MessageType,
    #[serde(skip_serializing_if = "Option::is_none")]
    sticker: Option<MessageStickerResponse>,
    sender: Sender,
    is_deleted: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    first_attachment_kind: Option<String>,
}

#[derive(Debug, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct StickerMediaResponse {
    #[serde(with = "crate::serde_i64_string")]
    pub id: i64,
    pub url: String,
    pub content_type: String,
    pub size: i64,
    pub width: Option<i32>,
    pub height: Option<i32>,
}

#[derive(Debug, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct MessageStickerResponse {
    #[serde(with = "crate::serde_i64_string")]
    pub id: i64,
    pub emoji: String,
    pub name: Option<String>,
    pub description: Option<String>,
    pub created_at: DateTime<Utc>,
    pub is_favorited: bool,
    pub media: StickerMediaResponse,
}

type DbConn = diesel::r2d2::PooledConnection<diesel::r2d2::ConnectionManager<diesel::PgConnection>>;

pub(crate) struct PreparedMessageSend {
    pub chat_id: i64,
    pub sender_uid: i32,
    pub message: Option<String>,
    pub message_type: MessageType,
    pub sticker_id: Option<i64>,
    pub reply_to_id: Option<i64>,
    pub reply_root_id: Option<i64>,
    pub client_generated_id: String,
    pub attachment_ids: Vec<i64>,
    pub update_group_last_message: bool,
    pub push_preview_override: Option<String>,
}

pub(crate) struct SendMessageResult {
    pub response: MessageResponse,
    pub member_uids: Vec<i32>,
}

fn load_username_by_uid(conn: &mut DbConn, uid: i32) -> QueryResult<Option<String>> {
    lookup_user_profiles(conn, &[uid])
        .map(|mut profiles| profiles.remove(&uid).and_then(|profile| profile.username))
}

pub(crate) async fn send_prepared_message(
    conn: &mut DbConn,
    state: &AppState,
    prepared: PreparedMessageSend,
) -> Result<SendMessageResult, (StatusCode, &'static str)> {
    let id = ids::next_message_id(state.id_gen.as_ref())
        .await
        .map_err(|e| {
            tracing::error!("ferroid next_message_id: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "ID generation failed")
        })?;

    let now = Utc::now();

    let new_msg = NewMessage {
        id,
        message: prepared.message,
        message_type: prepared.message_type,
        sticker_id: prepared.sticker_id,
        reply_to_id: prepared.reply_to_id,
        reply_root_id: prepared.reply_root_id,
        created_at: now,
        client_generated_id: prepared.client_generated_id,
        sender_uid: prepared.sender_uid,
        chat_id: prepared.chat_id,
        updated_at: None,
        deleted_at: None,
        has_attachments: !prepared.attachment_ids.is_empty(),
        has_thread: false,
        has_reactions: false,
    };

    let inserted_msg: Message = diesel::insert_into(messages::table)
        .values(&new_msg)
        .returning(Message::as_returning())
        .get_result(conn)
        .map_err(|e| {
            tracing::error!("insert message: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to send message")
        })?;
    state.metrics.record_message(prepared.chat_id);

    if prepared.update_group_last_message {
        use crate::schema::groups::dsl as g_dsl;
        diesel::update(groups::table.filter(g_dsl::id.eq(prepared.chat_id)))
            .set((
                g_dsl::last_message_id.eq(Some(id)),
                g_dsl::last_message_at.eq(Some(now)),
            ))
            .execute(conn)
            .map_err(|e| {
                tracing::error!("update group last_message: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, "Failed to update group")
            })?;
    }

    if !prepared.attachment_ids.is_empty() {
        use crate::schema::attachments::dsl as a_dsl;
        diesel::update(attachments::table.filter(a_dsl::id.eq_any(&prepared.attachment_ids)))
            .set(a_dsl::message_id.eq(id))
            .execute(conn)
            .map_err(|e| {
                tracing::error!("update attachments: {:?}", e);
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "Failed to link attachments",
                )
            })?;
    }

    let response = attach_metadata(conn, vec![inserted_msg], state, prepared.sender_uid)
        .await
        .into_iter()
        .next()
        .ok_or((
            StatusCode::INTERNAL_SERVER_ERROR,
            "Failed to build message response",
        ))?;

    let member_uids: Vec<i32> = {
        use crate::schema::group_membership as gm_dsl;
        group_membership::table
            .filter(gm_dsl::chat_id.eq(prepared.chat_id))
            .select(group_membership::uid)
            .load(conn)
            .map_err(|e| {
                tracing::error!("list members for broadcast: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
            })?
    };

    let ws_msg = std::sync::Arc::new(crate::handlers::ws::messages::ServerWsMessage::Message(
        response.clone(),
    ));
    state.ws_registry.broadcast_to_uids(&member_uids, ws_msg);

    let sender_username = load_username_by_uid(conn, prepared.sender_uid)
        .map_err(|e| {
            tracing::error!("load sender username: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?
        .unwrap_or_else(|| "Someone".to_string());
    let chat_name = groups::table
        .filter(groups::dsl::id.eq(prepared.chat_id))
        .select(groups::dsl::name)
        .first::<String>(conn)
        .unwrap_or_else(|_| "Chat".to_string());
    let mentioned_uids = response
        .message
        .as_deref()
        .map(extract_mention_uids)
        .unwrap_or_default();
    state.push_service.enqueue(PushJob {
        chat_id: prepared.chat_id,
        sender_uid: prepared.sender_uid,
        sender_username,
        chat_name,
        message_preview: push_message_preview_from_response(&response),
        legacy_message_preview: prepared.push_preview_override.or_else(|| {
            response
                .message
                .as_deref()
                .map(|text| render_mentions_as_text(text, &response.mentions))
                .or_else(|| {
                    response
                        .sticker
                        .as_ref()
                        .map(|sticker| sticker_preview_text(Some(&sticker.emoji)))
                })
        }),
        message_id: response.id,
        thread_root_id: response.reply_root_id,
        mentioned_uids,
    });

    Ok(SendMessageResult {
        response,
        member_uids,
    })
}

fn sticker_preview_text(emoji: Option<&str>) -> String {
    match emoji.filter(|value| !value.trim().is_empty()) {
        Some(emoji) => format!("[Sticker] {emoji}"),
        None => "[Sticker]".to_string(),
    }
}

/// Replace `@[uid:N]` tokens with `@username` for human-readable previews.
fn render_mentions_as_text(text: &str, mentions: &[MentionInfo]) -> String {
    if mentions.is_empty() {
        return text.to_string();
    }
    let mention_map: std::collections::HashMap<i32, &str> = mentions
        .iter()
        .filter_map(|m| m.username.as_deref().map(|name| (m.uid, name)))
        .collect();

    let mut result = String::with_capacity(text.len());
    let bytes = text.as_bytes();
    let len = bytes.len();
    let mut i = 0;
    while i < len {
        if bytes[i] == b'@' && i + 1 < len && bytes[i + 1] == b'[' {
            if let Some(rest) = text.get(i + 2..) {
                if let Some(close) = rest.find(']') {
                    let inner = &rest[..close];
                    if let Some(id_str) = inner.strip_prefix("uid:") {
                        if let Ok(uid) = id_str.parse::<i32>() {
                            let name = mention_map.get(&uid).copied().unwrap_or("Unknown User");
                            result.push('@');
                            result.push_str(name);
                            i += 2 + close + 1;
                            continue;
                        }
                    }
                }
            }
        }
        result.push(bytes[i] as char);
        i += 1;
    }
    result
}

fn push_message_preview_from_response(response: &MessageResponse) -> PushMessagePreview {
    PushMessagePreview {
        message: response
            .message
            .as_deref()
            .map(|text| render_mentions_as_text(text, &response.mentions)),
        message_type: response.message_type.clone(),
        sticker: response.sticker.as_ref().and_then(|sticker| {
            (!sticker.emoji.trim().is_empty()).then(|| PushMessagePreviewSticker {
                emoji: sticker.emoji.clone(),
            })
        }),
        first_attachment_kind: response
            .attachments
            .first()
            .map(|attachment| attachment.kind.clone()),
        is_deleted: response.is_deleted,
    }
}

fn load_usernames_by_uids(
    conn: &mut DbConn,
    uids: &[i32],
) -> std::collections::HashMap<i32, Option<String>> {
    lookup_user_profiles(conn, uids)
        .unwrap_or_default()
        .into_iter()
        .map(|(uid, profile)| (uid, profile.username))
        .collect()
}

fn load_reply_messages(
    conn: &mut DbConn,
    reply_ids: &[i64],
) -> QueryResult<std::collections::HashMap<i64, Message>> {
    if reply_ids.is_empty() {
        return Ok(std::collections::HashMap::new());
    }

    messages::table
        .filter(messages::id.eq_any(reply_ids))
        .select(Message::as_select())
        .load::<Message>(conn)
        .map(|rows| rows.into_iter().map(|msg| (msg.id, msg)).collect())
}

fn load_sticker_accessible_ids(
    conn: &mut DbConn,
    uid: i32,
    sticker_ids: &[i64],
) -> QueryResult<std::collections::HashSet<i64>> {
    if sticker_ids.is_empty() {
        return Ok(std::collections::HashSet::new());
    }

    stickers::table
        .inner_join(sticker_pack_stickers::table)
        .left_join(
            user_sticker_pack_subscriptions::table.on(user_sticker_pack_subscriptions::pack_id
                .eq(sticker_pack_stickers::pack_id)
                .and(user_sticker_pack_subscriptions::uid.eq(uid))),
        )
        .left_join(sticker_packs::table.on(sticker_packs::id.eq(sticker_pack_stickers::pack_id)))
        .filter(stickers::id.eq_any(sticker_ids))
        .filter(
            user_sticker_pack_subscriptions::uid
                .is_not_null()
                .or(sticker_packs::owner_uid.eq(uid)),
        )
        .select(stickers::id)
        .load::<i64>(conn)
        .map(|rows| rows.into_iter().collect())
}

fn load_sticker_rows(
    conn: &mut DbConn,
    sticker_ids: &[i64],
) -> QueryResult<std::collections::HashMap<i64, (Sticker, Media)>> {
    if sticker_ids.is_empty() {
        return Ok(std::collections::HashMap::new());
    }

    stickers::table
        .inner_join(media::table)
        .filter(stickers::id.eq_any(sticker_ids))
        .select((Sticker::as_select(), Media::as_select()))
        .load::<(Sticker, Media)>(conn)
        .map(|rows| {
            rows.into_iter()
                .map(|(sticker, media_row)| (sticker.id, (sticker, media_row)))
                .collect()
        })
}

fn load_favorited_sticker_ids(
    conn: &mut DbConn,
    uid: i32,
    sticker_ids: &[i64],
) -> QueryResult<std::collections::HashSet<i64>> {
    if sticker_ids.is_empty() {
        return Ok(std::collections::HashSet::new());
    }

    user_favorite_stickers::table
        .filter(user_favorite_stickers::uid.eq(uid))
        .filter(user_favorite_stickers::sticker_id.eq_any(sticker_ids))
        .select(user_favorite_stickers::sticker_id)
        .load::<i64>(conn)
        .map(|rows| rows.into_iter().collect())
}

fn build_message_sticker_response(
    state: &AppState,
    sticker: &Sticker,
    media_row: &Media,
    is_favorited: bool,
) -> MessageStickerResponse {
    MessageStickerResponse {
        id: sticker.id,
        emoji: sticker.emoji.clone(),
        name: sticker.name.clone(),
        description: sticker.description.clone(),
        created_at: sticker.created_at,
        is_favorited,
        media: StickerMediaResponse {
            id: media_row.id,
            url: build_public_object_url(state, &media_row.storage_key),
            content_type: media_row.content_type.clone(),
            size: media_row.size,
            width: media_row.width,
            height: media_row.height,
        },
    }
}

fn build_sender(
    uid: i32,
    user_avatars: &std::collections::HashMap<i32, Option<String>>,
    user_profiles: &std::collections::HashMap<i32, UserProfile>,
) -> Sender {
    let profile = user_profiles.get(&uid);

    Sender {
        uid,
        avatar_url: user_avatars.get(&uid).cloned().flatten(),
        name: profile.and_then(|profile| profile.username.clone()),
        gender: profile.map(|profile| profile.gender).unwrap_or(0),
        user_group: profile.and_then(|profile| profile.user_group.clone()),
    }
}

fn first_attachment_kind(
    message_attachments_map: &std::collections::HashMap<i64, Vec<Attachment>>,
    message_id: i64,
) -> Option<String> {
    message_attachments_map
        .get(&message_id)
        .and_then(|attachments| attachments.first())
        .map(|attachment| attachment.kind.clone())
}

/// Attach reply_to_message to a list of messages by fetching referenced messages in one query.
pub async fn attach_metadata(
    conn: &mut DbConn,
    messages_to_process: Vec<Message>,
    state: &AppState,
    current_user_uid: i32,
) -> Vec<MessageResponse> {
    let reply_ids: Vec<i64> = messages_to_process
        .iter()
        .filter_map(|m| m.reply_to_id)
        .collect();

    let message_ids: Vec<i64> = messages_to_process.iter().map(|m| m.id).collect();
    let reply_messages_map = load_reply_messages(conn, &reply_ids).unwrap_or_default();

    let mut avatar_uids = std::collections::HashSet::new();
    for m in &messages_to_process {
        avatar_uids.insert(m.sender_uid);
    }
    for reply_msg in reply_messages_map.values() {
        avatar_uids.insert(reply_msg.sender_uid);
    }
    let target_uids: Vec<i32> = avatar_uids.into_iter().collect();
    let user_avatars = lookup_user_avatars(state, &target_uids);
    let user_profiles = lookup_user_profiles(conn, &target_uids).unwrap_or_default();

    let mut message_attachments_map: std::collections::HashMap<i64, Vec<Attachment>> =
        std::collections::HashMap::new();
    let attachment_message_ids: Vec<i64> = message_ids
        .iter()
        .copied()
        .chain(reply_ids.iter().copied())
        .collect::<std::collections::HashSet<_>>()
        .into_iter()
        .collect();
    if !attachment_message_ids.is_empty() {
        use crate::schema::attachments::dsl as a_dsl;
        let attachments: Vec<Attachment> = match attachments::table
            .filter(a_dsl::message_id.eq_any(&attachment_message_ids))
            .order((a_dsl::created_at.asc(), a_dsl::id.asc()))
            .select(Attachment::as_select())
            .load(conn)
        {
            Ok(attachments) => attachments,
            Err(err) => {
                tracing::error!(
                    error = ?err,
                    message_ids = ?attachment_message_ids,
                    "attach_metadata: failed to load attachments"
                );
                Vec::new()
            }
        };
        for att in attachments {
            if let Some(msg_id) = att.message_id {
                message_attachments_map.entry(msg_id).or_default().push(att);
            }
        }
    }

    let sticker_ids: Vec<i64> = messages_to_process
        .iter()
        .filter_map(|m| m.sticker_id)
        .chain(
            reply_messages_map
                .values()
                .filter_map(|reply_msg| reply_msg.sticker_id),
        )
        .collect::<std::collections::HashSet<_>>()
        .into_iter()
        .collect();
    let sticker_rows = load_sticker_rows(conn, &sticker_ids).unwrap_or_default();
    let favorited_sticker_ids =
        load_favorited_sticker_ids(conn, current_user_uid, &sticker_ids).unwrap_or_default();

    let mut thread_counts_map: std::collections::HashMap<i64, i64> =
        std::collections::HashMap::new();
    let thread_root_ids: Vec<i64> = messages_to_process
        .iter()
        .filter(|m| m.has_thread)
        .map(|m| m.id)
        .collect();
    if !thread_root_ids.is_empty() {
        use crate::schema::messages::dsl as m_dsl;
        let counts: Vec<(Option<i64>, i64)> = messages::table
            .filter(m_dsl::reply_root_id.eq_any(&thread_root_ids))
            .filter(m_dsl::deleted_at.is_null())
            .group_by(m_dsl::reply_root_id)
            .select((m_dsl::reply_root_id, diesel::dsl::count_star()))
            .load(conn)
            .unwrap_or_default();
        for (root_id_opt, count) in counts {
            if let Some(root_id) = root_id_opt {
                thread_counts_map.insert(root_id, count);
            }
        }
    }

    // --- Reactions ---
    let mut reaction_summaries_map: std::collections::HashMap<i64, Vec<ReactionSummary>> =
        std::collections::HashMap::new();
    let reacted_message_ids: Vec<i64> = messages_to_process
        .iter()
        .filter(|m| m.has_reactions)
        .map(|m| m.id)
        .collect();
    if !reacted_message_ids.is_empty() {
        let counts: Vec<(i64, String, i64)> = message_reactions::table
            .filter(message_reactions::message_id.eq_any(&reacted_message_ids))
            .group_by((message_reactions::message_id, message_reactions::emoji))
            .select((
                message_reactions::message_id,
                message_reactions::emoji,
                diesel::dsl::count_star(),
            ))
            .load(conn)
            .unwrap_or_default();

        let my_reactions: std::collections::HashSet<(i64, String)> = message_reactions::table
            .filter(message_reactions::message_id.eq_any(&reacted_message_ids))
            .filter(message_reactions::user_uid.eq(current_user_uid))
            .select((message_reactions::message_id, message_reactions::emoji))
            .load::<(i64, String)>(conn)
            .unwrap_or_default()
            .into_iter()
            .collect();

        // Query 3: Fetch reactor UIDs per (message_id, emoji)
        let raw_reactors: Vec<(i64, String, i32)> = message_reactions::table
            .filter(message_reactions::message_id.eq_any(&reacted_message_ids))
            .select((
                message_reactions::message_id,
                message_reactions::emoji,
                message_reactions::user_uid,
            ))
            .load(conn)
            .unwrap_or_default();

        // Group by (msg_id, emoji) → Vec<uid>, capped at 5
        let mut reactor_uids_map: std::collections::HashMap<(i64, String), Vec<i32>> =
            std::collections::HashMap::new();
        for (msg_id, emoji, uid) in &raw_reactors {
            let entry = reactor_uids_map
                .entry((*msg_id, emoji.clone()))
                .or_default();
            if entry.len() < 5 {
                entry.push(*uid);
            }
        }

        // Batch-resolve names + avatars for all reactor UIDs
        let all_reactor_uids: Vec<i32> = reactor_uids_map
            .values()
            .flatten()
            .copied()
            .collect::<std::collections::HashSet<i32>>()
            .into_iter()
            .collect();
        let reactor_names = load_usernames_by_uids(conn, &all_reactor_uids);
        let reactor_avatars = lookup_user_avatars(state, &all_reactor_uids);

        for (msg_id, emoji, count) in counts {
            let reacted_by_me = Some(my_reactions.contains(&(msg_id, emoji.clone())));
            let reactors = reactor_uids_map.get(&(msg_id, emoji.clone())).map(|uids| {
                uids.iter()
                    .map(|&uid| ReactionReactor {
                        uid,
                        name: reactor_names.get(&uid).cloned().flatten(),
                        avatar_url: reactor_avatars.get(&uid).cloned().flatten(),
                    })
                    .collect()
            });
            reaction_summaries_map
                .entry(msg_id)
                .or_default()
                .push(ReactionSummary {
                    emoji,
                    count,
                    reacted_by_me,
                    reactors,
                });
        }
    }

    // --- Mentions ---
    // Collect all mentioned UIDs across all messages so we can batch-resolve profiles.
    let mut all_mentioned_uids = std::collections::HashSet::new();
    let mut per_message_mentions: Vec<Vec<i32>> = Vec::with_capacity(messages_to_process.len());
    for m in &messages_to_process {
        if let Some(ref text) = m.message {
            if m.deleted_at.is_none() {
                let uids = extract_mention_uids(text);
                for &uid in &uids {
                    all_mentioned_uids.insert(uid);
                }
                per_message_mentions.push(uids);
                continue;
            }
        }
        per_message_mentions.push(Vec::new());
    }
    // Resolve profiles for mentioned UIDs not already loaded
    let extra_mention_uids: Vec<i32> = all_mentioned_uids
        .iter()
        .copied()
        .filter(|uid| !user_profiles.contains_key(uid))
        .collect();
    let mention_profiles = if extra_mention_uids.is_empty() {
        std::collections::HashMap::new()
    } else {
        lookup_user_profiles(conn, &extra_mention_uids).unwrap_or_default()
    };

    let mut responses = Vec::with_capacity(messages_to_process.len());
    for (idx, m) in messages_to_process.into_iter().enumerate() {
        let reply_to_message = m.reply_to_id.and_then(|reply_id| {
            reply_messages_map.get(&reply_id).map(|reply_msg| {
                if reply_msg.has_attachments
                    && message_attachments_map
                        .get(&reply_msg.id)
                        .is_none_or(|attachments| attachments.is_empty())
                {
                    tracing::warn!(
                        reply_id = reply_msg.id,
                        parent_message_id = m.id,
                        chat_id = m.chat_id,
                        "attach_metadata: reply message has_attachments=true but no attachments were hydrated"
                    );
                }

                Box::new(ReplyToMessage {
                    id: reply_msg.id,
                    message: if reply_msg.deleted_at.is_some() {
                        None
                    } else {
                        reply_msg.message.clone()
                    },
                    message_type: reply_msg.message_type.clone(),
                    sticker: reply_msg.sticker_id.and_then(|sticker_id| {
                        sticker_rows.get(&sticker_id).map(|(sticker, media_row)| {
                            build_message_sticker_response(
                                state,
                                sticker,
                                media_row,
                                favorited_sticker_ids.contains(&sticker_id),
                            )
                        })
                    }),
                    sender: build_sender(reply_msg.sender_uid, &user_avatars, &user_profiles),
                    is_deleted: reply_msg.deleted_at.is_some(),
                    first_attachment_kind: first_attachment_kind(
                        &message_attachments_map,
                        reply_msg.id,
                    ),
                })
            })
        });

        let mut attachments = Vec::new();
        if let Some(atts) = message_attachments_map.get(&m.id) {
            for att in atts {
                attachments.push(AttachmentResponse {
                    id: att.id,
                    url: build_public_object_url(state, &att.external_reference),
                    kind: att.kind.clone(),
                    size: att.size,
                    file_name: att.file_name.clone(),
                    width: att.width,
                    height: att.height,
                });
            }
        }

        responses.push(MessageResponse {
            id: m.id,
            message: if m.deleted_at.is_some() {
                None
            } else {
                m.message
            },
            message_type: m.message_type,
            sticker: m.sticker_id.and_then(|sticker_id| {
                sticker_rows.get(&sticker_id).map(|(sticker, media_row)| {
                    build_message_sticker_response(
                        state,
                        sticker,
                        media_row,
                        favorited_sticker_ids.contains(&sticker_id),
                    )
                })
            }),
            reply_root_id: m.reply_root_id,
            client_generated_id: m.client_generated_id,
            sender: build_sender(m.sender_uid, &user_avatars, &user_profiles),
            chat_id: m.chat_id,
            created_at: m.created_at,
            is_edited: m.updated_at.is_some(),
            is_deleted: m.deleted_at.is_some(),
            has_attachments: m.has_attachments,
            thread_info: if m.has_thread {
                Some(ThreadInfo {
                    reply_count: *thread_counts_map.get(&m.id).unwrap_or(&0),
                })
            } else {
                None
            },
            reply_to_message,
            attachments,
            reactions: reaction_summaries_map.remove(&m.id).unwrap_or_default(),
            mentions: {
                per_message_mentions[idx]
                    .iter()
                    .map(|&uid| {
                        let username = user_profiles
                            .get(&uid)
                            .or_else(|| mention_profiles.get(&uid))
                            .and_then(|p| p.username.clone());
                        MentionInfo { uid, username }
                    })
                    .collect()
            },
        });
    }
    responses
}

/// GET /chats/:chat_id/messages — List messages in a chat (cursor-based).
async fn get_messages(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(ChatIdPath { chat_id }): Path<ChatIdPath>,
    Query(q): Query<ListMessagesQuery>,
) -> Result<Json<ListMessagesResponse>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    check_membership(conn, chat_id, uid)?;

    let max = q
        .max
        .map(|m| std::cmp::min(m, MAX_MESSAGES_LIMIT))
        .unwrap_or(MAX_MESSAGES_LIMIT)
        .max(1);

    use crate::schema::messages::dsl;

    let q_thread_id = q.thread_id;
    macro_rules! base_query {
        () => {{
            let mut b = messages::table
                .into_boxed()
                .filter(dsl::chat_id.eq(chat_id).and(dsl::deleted_at.is_null()));
            if let Some(tid) = q_thread_id {
                b = b.filter(dsl::reply_root_id.eq(tid).or(dsl::id.eq(tid)));
            } else {
                b = b.filter(dsl::reply_root_id.is_null());
            }
            b
        }};
    }

    // around=<id>: fetch a window centered on the target message
    if let Some(target) = q.around {
        let half = max / 2;

        // Messages with id >= target, ordered ASC (target first, then newer)
        let newer_rows: Vec<Message> = base_query!()
            .filter(dsl::id.ge(target))
            .order(dsl::id.asc())
            .limit(half + 2)
            .select(Message::as_select())
            .load(conn)
            .map_err(|e| {
                tracing::error!("around newer: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, "Failed to list messages")
            })?;

        // Messages with id < target, ordered DESC (closest to target first)
        let older_rows: Vec<Message> = base_query!()
            .filter(dsl::id.lt(target))
            .order(dsl::id.desc())
            .limit(half + 1)
            .select(Message::as_select())
            .load(conn)
            .map_err(|e| {
                tracing::error!("around older: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, "Failed to list messages")
            })?;

        let has_older = older_rows.len() as i64 > half;
        let has_newer = newer_rows.len() as i64 > half + 1;

        let older_to_use: Vec<Message> = older_rows.into_iter().take(half as usize).collect();
        let newer_to_use: Vec<Message> = newer_rows.into_iter().take((half + 1) as usize).collect();

        // next_cursor = oldest id (for loading older), prev_cursor = newest id (for loading newer)
        let next_cursor = has_older
            .then(|| older_to_use.last().map(|m| m.id))
            .flatten();
        let prev_cursor = has_newer
            .then(|| newer_to_use.last().map(|m| m.id))
            .flatten();

        // Combine: older reversed (oldest first) + newer (target first, ascending)
        let mut combined: Vec<Message> = older_to_use.into_iter().rev().collect();
        combined.extend(newer_to_use);

        let messages_vec = attach_metadata(conn, combined, &state, uid).await;

        return Ok(Json(ListMessagesResponse {
            messages: messages_vec,
            next_cursor,
            prev_cursor,
        }));
    }

    // after=<id>: fetch messages newer than `after`, ascending order
    if let Some(after) = q.after {
        let rows: Vec<Message> = base_query!()
            .filter(dsl::id.gt(after))
            .order(dsl::id.asc())
            .limit(max + 1)
            .select(Message::as_select())
            .load(conn)
            .map_err(|e| {
                tracing::error!("after query: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, "Failed to list messages")
            })?;

        let has_more = rows.len() as i64 > max;
        let messages_to_process: Vec<Message> = rows.into_iter().take(max as usize).collect();
        let prev_cursor = has_more
            .then(|| messages_to_process.last().map(|m| m.id))
            .flatten();

        let messages_vec = attach_metadata(conn, messages_to_process, &state, uid).await;

        return Ok(Json(ListMessagesResponse {
            messages: messages_vec,
            next_cursor: None,
            prev_cursor,
        }));
    }

    // Default: before cursor, descending (newest first in response, reversed by client)
    let rows: Vec<Message> = match q.before {
        None => base_query!()
            .order(dsl::id.desc())
            .limit(max + 1)
            .select(Message::as_select())
            .load(conn),
        Some(before) => base_query!()
            .filter(dsl::id.lt(before))
            .order(dsl::id.desc())
            .limit(max + 1)
            .select(Message::as_select())
            .load(conn),
    }
    .map_err(|e| {
        tracing::error!("list messages: {:?}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, "Failed to list messages")
    })?;

    let has_more = rows.len() as i64 > max;
    let messages_to_process: Vec<Message> = rows.into_iter().take(max as usize).collect();
    let next_cursor = has_more
        .then(|| messages_to_process.last().map(|m| m.id))
        .flatten();

    // Reverse to return ASC (oldest first)
    let messages_to_process: Vec<Message> = messages_to_process.into_iter().rev().collect();

    let messages_vec = attach_metadata(conn, messages_to_process, &state, uid).await;

    Ok(Json(ListMessagesResponse {
        messages: messages_vec,
        next_cursor,
        prev_cursor: None,
    }))
}

#[derive(serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateMessageBody {
    message: Option<String>,
    message_type: MessageType,
    #[serde(
        default,
        deserialize_with = "crate::serde_i64_string::opt::deserialize"
    )]
    sticker_id: Option<i64>,
    client_generated_id: String,
    #[serde(
        default,
        deserialize_with = "crate::serde_i64_string::opt::deserialize"
    )]
    reply_to_id: Option<i64>,
    #[serde(default)]
    attachment_ids: Vec<String>,
}

const SYSTEM_MESSAGE_TYPE_FORBIDDEN: &str = "System messages cannot be sent by clients";
const INVITE_MESSAGE_TYPE_FORBIDDEN: &str = "Invite messages must be sent through invite APIs";

fn validate_client_message_type(
    message_type: &MessageType,
) -> Result<(), (StatusCode, &'static str)> {
    if matches!(message_type, MessageType::System) {
        return Err((StatusCode::BAD_REQUEST, SYSTEM_MESSAGE_TYPE_FORBIDDEN));
    }

    if matches!(message_type, MessageType::Invite) {
        return Err((StatusCode::BAD_REQUEST, INVITE_MESSAGE_TYPE_FORBIDDEN));
    }

    Ok(())
}

fn validate_message_payload(
    conn: &mut DbConn,
    uid: i32,
    body: &CreateMessageBody,
    attachment_ids: &[i64],
) -> Result<(), (StatusCode, &'static str)> {
    if matches!(body.message_type, MessageType::Sticker) {
        let sticker_id = body
            .sticker_id
            .ok_or((StatusCode::BAD_REQUEST, "Sticker ID is required"))?;

        if !attachment_ids.is_empty() {
            return Err((
                StatusCode::BAD_REQUEST,
                "Sticker messages cannot include attachments",
            ));
        }
        if body
            .message
            .as_deref()
            .is_some_and(|message| !message.trim().is_empty())
        {
            return Err((
                StatusCode::BAD_REQUEST,
                "Sticker messages cannot include text",
            ));
        }

        let accessible = load_sticker_accessible_ids(conn, uid, &[sticker_id]).map_err(|e| {
            tracing::error!("validate sticker access: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to validate sticker",
            )
        })?;
        if !accessible.contains(&sticker_id) {
            return Err((
                StatusCode::FORBIDDEN,
                "Sticker is not available to this user",
            ));
        }
    } else if body.sticker_id.is_some() {
        return Err((
            StatusCode::BAD_REQUEST,
            "Sticker ID is only valid for sticker messages",
        ));
    }

    Ok(())
}

#[derive(serde::Deserialize)]
pub struct ThreadIdPath {
    chat_id: i64,
    #[serde(deserialize_with = "crate::serde_i64_string::deserialize")]
    thread_id: i64,
}

/// POST /chats/:chat_id/messages — Send a message.
async fn post_message(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(ChatIdPath { chat_id }): Path<ChatIdPath>,
    Json(body): Json<CreateMessageBody>,
) -> Result<impl IntoResponse, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    check_membership(conn, chat_id, uid)?;
    validate_client_message_type(&body.message_type)?;
    let attachment_ids: Vec<i64> = body
        .attachment_ids
        .iter()
        .filter_map(|s| s.parse().ok())
        .collect();
    validate_message_payload(conn, uid, &body, &attachment_ids)?;
    let send_result = send_prepared_message(
        conn,
        &state,
        PreparedMessageSend {
            chat_id,
            sender_uid: uid,
            message: if matches!(body.message_type, MessageType::Sticker) {
                None
            } else {
                body.message
            },
            message_type: body.message_type,
            sticker_id: body.sticker_id,
            reply_to_id: body.reply_to_id,
            reply_root_id: None,
            client_generated_id: body.client_generated_id,
            attachment_ids,
            update_group_last_message: true,
            push_preview_override: None,
        },
    )
    .await?;

    Ok((StatusCode::CREATED, Json(send_result.response)))
}

/// POST /chats/:chat_id/threads/:thread_id/messages — Send a message in a thread.
async fn post_thread_message(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(ThreadIdPath { chat_id, thread_id }): Path<ThreadIdPath>,
    Json(body): Json<CreateMessageBody>,
) -> Result<impl IntoResponse, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    check_membership(conn, chat_id, uid)?;
    validate_client_message_type(&body.message_type)?;

    // Fast-path: check if root message actually exists
    use crate::schema::messages::dsl;
    let root_msg_exists: bool = diesel::select(diesel::dsl::exists(
        messages::table.filter(dsl::id.eq(thread_id).and(dsl::chat_id.eq(chat_id))),
    ))
    .get_result(conn)
    .map_err(|e| {
        tracing::error!("check root message exists: {:?}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
    })?;

    if !root_msg_exists {
        return Err((StatusCode::NOT_FOUND, "Thread root message not found"));
    }
    let attachment_ids: Vec<i64> = body
        .attachment_ids
        .iter()
        .filter_map(|s| s.parse().ok())
        .collect();
    validate_message_payload(conn, uid, &body, &attachment_ids)?;
    let send_result = send_prepared_message(
        conn,
        &state,
        PreparedMessageSend {
            chat_id,
            sender_uid: uid,
            message: if matches!(body.message_type, MessageType::Sticker) {
                None
            } else {
                body.message
            },
            message_type: body.message_type,
            sticker_id: body.sticker_id,
            reply_to_id: body.reply_to_id,
            reply_root_id: Some(thread_id),
            client_generated_id: body.client_generated_id,
            attachment_ids,
            update_group_last_message: false,
            push_preview_override: None,
        },
    )
    .await?;
    let response = send_result.response;
    let member_uids = send_result.member_uids;

    // Auto-subscribe the replying user to this thread
    if let Err(e) =
        crate::services::threads::ensure_thread_subscription(conn, chat_id, thread_id, uid)
    {
        tracing::warn!("auto-subscribe replier to thread: {:?}", e);
    }

    // Auto-subscribe the root message author
    if let Ok(root_sender_uid) = messages::table
        .filter(dsl::id.eq(thread_id))
        .select(messages::sender_uid)
        .first::<i32>(conn)
    {
        if root_sender_uid != uid {
            if let Err(e) = crate::services::threads::ensure_thread_subscription(
                conn,
                chat_id,
                thread_id,
                root_sender_uid,
            ) {
                tracing::warn!("auto-subscribe root author to thread: {:?}", e);
            }
        }
    }

    // Mark the root message as having a thread
    let root_msg_updated: Option<Message> =
        diesel::update(messages::table.filter(dsl::id.eq(thread_id)))
            .set(dsl::has_thread.eq(true))
            .get_result(conn)
            .ok();

    if let Some(root_msg) = root_msg_updated {
        let root_response = attach_metadata(conn, vec![root_msg], &state, uid)
            .await
            .into_iter()
            .next()
            .unwrap();
        let ws_msg = std::sync::Arc::new(
            crate::handlers::ws::messages::ServerWsMessage::MessageUpdated(root_response.clone()),
        );
        state.ws_registry.broadcast_to_uids(&member_uids, ws_msg);
    }

    // Broadcast ThreadUpdate to all subscribers of this thread
    if let Ok(subscriber_uids) =
        crate::services::threads::get_thread_subscriber_uids(conn, chat_id, thread_id)
    {
        if !subscriber_uids.is_empty() {
            let reply_count: i64 = messages::table
                .filter(
                    messages::reply_root_id
                        .eq(thread_id)
                        .and(messages::deleted_at.is_null()),
                )
                .count()
                .get_result(conn)
                .unwrap_or(0);

            let thread_update = std::sync::Arc::new(
                crate::handlers::ws::messages::ServerWsMessage::ThreadUpdate(
                    crate::handlers::ws::messages::ThreadUpdatePayload {
                        thread_root_id: thread_id,
                        chat_id,
                        last_reply_at: response.created_at,
                        reply_count,
                    },
                ),
            );
            state
                .ws_registry
                .broadcast_to_uids(&subscriber_uids, thread_update);
        }
    }

    Ok((StatusCode::CREATED, Json(response)))
}

#[cfg(test)]
mod tests {
    use super::{
        first_attachment_kind, sticker_preview_text, validate_client_message_type, ReplyToMessage,
        INVITE_MESSAGE_TYPE_FORBIDDEN, SYSTEM_MESSAGE_TYPE_FORBIDDEN,
    };
    use crate::models::{Attachment, MessageType, Sender};
    use axum::http::StatusCode;
    use chrono::Utc;
    use serde_json::json;
    use std::collections::HashMap;

    #[test]
    fn rejects_system_message_type_from_clients() {
        let err = validate_client_message_type(&MessageType::System)
            .expect_err("system should be rejected");
        assert_eq!(
            err,
            (StatusCode::BAD_REQUEST, SYSTEM_MESSAGE_TYPE_FORBIDDEN)
        );
    }

    #[test]
    fn allows_standard_message_types_from_clients() {
        assert!(validate_client_message_type(&MessageType::Text).is_ok());
        assert!(validate_client_message_type(&MessageType::Audio).is_ok());
        assert!(validate_client_message_type(&MessageType::File).is_ok());
        assert!(validate_client_message_type(&MessageType::Sticker).is_ok());
    }

    #[test]
    fn rejects_invite_message_type_from_generic_message_api() {
        let err = validate_client_message_type(&MessageType::Invite)
            .expect_err("invite should be rejected");
        assert_eq!(
            err,
            (StatusCode::BAD_REQUEST, INVITE_MESSAGE_TYPE_FORBIDDEN)
        );
    }

    #[test]
    fn sticker_preview_text_includes_emoji_when_available() {
        assert_eq!(sticker_preview_text(Some("🙂")), "[Sticker] 🙂");
        assert_eq!(sticker_preview_text(None), "[Sticker]");
    }

    #[test]
    fn serializes_reply_to_message_type_and_camel_case_keys() {
        let reply = ReplyToMessage {
            id: 42,
            message: Some("voice".to_string()),
            message_type: MessageType::Audio,
            sticker: None,
            sender: Sender {
                uid: 7,
                avatar_url: None,
                name: Some("Alice".to_string()),
                gender: 0,
                user_group: None,
            },
            is_deleted: false,
            first_attachment_kind: Some("audio/webm".to_string()),
        };

        let value = serde_json::to_value(reply).expect("serialize reply_to_message");
        assert_eq!(value["messageType"], json!("audio"));
        assert_eq!(value["isDeleted"], json!(false));
        assert_eq!(value["firstAttachmentKind"], json!("audio/webm"));
        assert!(value.get("message_type").is_none());
    }

    #[test]
    fn first_attachment_kind_can_be_read_multiple_times_for_same_message() {
        let attachment = Attachment {
            id: 1,
            message_id: Some(42),
            file_name: "image.png".to_string(),
            kind: "image/png".to_string(),
            external_reference: "attachments/image.png".to_string(),
            size: 123,
            created_at: Utc::now(),
            deleted_at: None,
            width: Some(100),
            height: Some(100),
        };

        let mut attachments_map = HashMap::new();
        attachments_map.insert(42, vec![attachment]);

        assert_eq!(
            first_attachment_kind(&attachments_map, 42),
            Some("image/png".to_string())
        );
        assert_eq!(
            first_attachment_kind(&attachments_map, 42),
            Some("image/png".to_string())
        );
    }
}

#[derive(serde::Deserialize)]
pub struct MessageIdPath {
    chat_id: i64,
    #[serde(deserialize_with = "crate::serde_i64_string::deserialize")]
    message_id: i64,
}

#[derive(serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateMessageBody {
    message: String,
    #[serde(default)]
    attachment_ids: Vec<String>,
}

/// PATCH /chats/:chat_id/messages/:message_id — Edit a message.
async fn patch_message(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(MessageIdPath {
        chat_id,
        message_id,
    }): Path<MessageIdPath>,
    Json(body): Json<UpdateMessageBody>,
) -> Result<Json<MessageResponse>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    check_membership(conn, chat_id, uid)?;

    // Verify message exists and belongs to the user
    use crate::schema::messages::dsl;
    let message: Message = messages::table
        .filter(dsl::id.eq(message_id).and(dsl::chat_id.eq(chat_id)))
        .select(Message::as_select())
        .first(conn)
        .map_err(|_| (StatusCode::NOT_FOUND, "Message not found"))?;

    if message.sender_uid != uid {
        return Err((StatusCode::FORBIDDEN, "You can only edit your own messages"));
    }

    if message.deleted_at.is_some() {
        return Err((StatusCode::BAD_REQUEST, "Cannot edit deleted message"));
    }

    if body.message.trim().is_empty() && body.attachment_ids.is_empty() {
        return Err((StatusCode::BAD_REQUEST, "Message cannot be empty"));
    }

    let attachment_ids: Vec<i64> = body
        .attachment_ids
        .iter()
        .filter_map(|s| s.parse().ok())
        .collect();

    use crate::schema::attachments::dsl as a_dsl;
    diesel::update(attachments::table.filter(a_dsl::message_id.eq(message_id)))
        .set(a_dsl::message_id.eq::<Option<i64>>(None))
        .execute(conn)
        .map_err(|e| {
            tracing::error!("clear message attachments: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to update attachments",
            )
        })?;

    if !attachment_ids.is_empty() {
        diesel::update(attachments::table.filter(a_dsl::id.eq_any(&attachment_ids)))
            .set(a_dsl::message_id.eq(message_id))
            .execute(conn)
            .map_err(|e| {
                tracing::error!("replace message attachments: {:?}", e);
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "Failed to update attachments",
                )
            })?;
    }

    // Update message
    let now = Utc::now();
    let updated_message: Message = diesel::update(messages::table.filter(dsl::id.eq(message_id)))
        .set((
            dsl::message.eq(&body.message),
            dsl::has_attachments.eq(!attachment_ids.is_empty()),
            dsl::updated_at.eq(Some(now)),
        ))
        .returning(Message::as_returning())
        .get_result(conn)
        .map_err(|e| {
            tracing::error!("update message: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to update message",
            )
        })?;

    let response = attach_metadata(conn, vec![updated_message], &state, uid)
        .await
        .into_iter()
        .next()
        .unwrap();

    // Broadcast update to all members
    let member_uids: Vec<i32> = {
        use crate::schema::group_membership as gm_dsl;
        group_membership::table
            .filter(gm_dsl::chat_id.eq(chat_id))
            .select(group_membership::uid)
            .load(conn)
            .map_err(|e| {
                tracing::error!("list members for broadcast: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
            })?
    };
    let ws_msg = std::sync::Arc::new(
        crate::handlers::ws::messages::ServerWsMessage::MessageUpdated(response.clone()),
    );
    state.ws_registry.broadcast_to_uids(&member_uids, ws_msg);

    Ok(Json(response))
}

/// DELETE /chats/:chat_id/messages/:message_id — Delete a message (soft delete).
async fn delete_message(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(MessageIdPath {
        chat_id,
        message_id,
    }): Path<MessageIdPath>,
) -> Result<StatusCode, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    check_membership(conn, chat_id, uid)?;

    // Verify message exists and belongs to the user
    use crate::schema::messages::dsl;
    let message: Message = messages::table
        .filter(dsl::id.eq(message_id).and(dsl::chat_id.eq(chat_id)))
        .select(Message::as_select())
        .first(conn)
        .map_err(|_| (StatusCode::NOT_FOUND, "Message not found"))?;

    if message.sender_uid != uid {
        return Err((
            StatusCode::FORBIDDEN,
            "You can only delete your own messages",
        ));
    }

    if message.deleted_at.is_some() {
        return Err((StatusCode::GONE, "Message already deleted"));
    }

    // Soft delete message
    let now = Utc::now();
    let deleted_message: Message = diesel::update(messages::table.filter(dsl::id.eq(message_id)))
        .set(dsl::deleted_at.eq(Some(now)))
        .returning(Message::as_returning())
        .get_result(conn)
        .map_err(|e| {
            tracing::error!("delete message: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to delete message",
            )
        })?;

    // If the deleted message was the group's last_message_id, recalculate it
    {
        use crate::schema::groups::dsl as g_dsl;
        let group_last_msg: Option<i64> = groups::table
            .filter(g_dsl::id.eq(chat_id))
            .select(g_dsl::last_message_id)
            .first::<Option<i64>>(conn)
            .map_err(|e| {
                tracing::error!("fetch group last_message_id: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
            })?;

        if group_last_msg == Some(message_id) {
            let prev_message: Option<(i64, DateTime<Utc>)> = messages::table
                .filter(dsl::chat_id.eq(chat_id))
                .filter(dsl::deleted_at.is_null())
                .filter(dsl::reply_root_id.is_null())
                .order(dsl::id.desc())
                .select((dsl::id, dsl::created_at))
                .first(conn)
                .optional()
                .map_err(|e| {
                    tracing::error!("find previous message: {:?}", e);
                    (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
                })?;

            match prev_message {
                Some((prev_id, prev_at)) => {
                    diesel::update(groups::table.filter(g_dsl::id.eq(chat_id)))
                        .set((
                            g_dsl::last_message_id.eq(Some(prev_id)),
                            g_dsl::last_message_at.eq(Some(prev_at)),
                        ))
                        .execute(conn)
                        .map_err(|e| {
                            tracing::error!("update group last_message: {:?}", e);
                            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
                        })?;
                }
                None => {
                    diesel::update(groups::table.filter(g_dsl::id.eq(chat_id)))
                        .set((
                            g_dsl::last_message_id.eq(None::<i64>),
                            g_dsl::last_message_at.eq(None::<DateTime<Utc>>),
                        ))
                        .execute(conn)
                        .map_err(|e| {
                            tracing::error!("clear group last_message: {:?}", e);
                            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
                        })?;
                }
            }
        }
    }

    let response = attach_metadata(conn, vec![deleted_message], &state, uid)
        .await
        .into_iter()
        .next()
        .unwrap();

    // Broadcast deletion to all members
    let member_uids: Vec<i32> = {
        use crate::schema::group_membership as gm_dsl;
        group_membership::table
            .filter(gm_dsl::chat_id.eq(chat_id))
            .select(group_membership::uid)
            .load(conn)
            .map_err(|e| {
                tracing::error!("list members for broadcast: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
            })?
    };
    let ws_msg = std::sync::Arc::new(
        crate::handlers::ws::messages::ServerWsMessage::MessageDeleted(response.clone()),
    );
    state.ws_registry.broadcast_to_uids(&member_uids, ws_msg);

    Ok(StatusCode::NO_CONTENT)
}

/// GET /chats/:chat_id/messages/:message_id — Get a single message.
async fn get_message(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(MessageIdPath {
        chat_id,
        message_id,
    }): Path<MessageIdPath>,
) -> Result<Json<MessageResponse>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    check_membership(conn, chat_id, uid)?;

    use crate::schema::messages::dsl;
    let message: Message = messages::table
        .filter(
            dsl::id
                .eq(message_id)
                .and(dsl::chat_id.eq(chat_id))
                .and(dsl::deleted_at.is_null()),
        )
        .select(Message::as_select())
        .first(conn)
        .map_err(|_| (StatusCode::NOT_FOUND, "Message not found"))?;

    let messages_vec = attach_metadata(conn, vec![message], &state, uid).await;
    let response = messages_vec.into_iter().next().unwrap();

    Ok(Json(response))
}

#[derive(serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MarkAsReadBody {
    #[serde(deserialize_with = "crate::serde_i64_string::deserialize")]
    message_id: i64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct MarkChatReadStateResponse {
    #[serde(serialize_with = "crate::serde_i64_string::opt::serialize")]
    last_read_message_id: Option<i64>,
    unread_count: i64,
}

/// POST /chats/:chat_id/messages/read — Mark messages as read up to a specific message ID.
async fn mark_as_read(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(ChatIdPath { chat_id }): Path<ChatIdPath>,
    Json(body): Json<MarkAsReadBody>,
) -> Result<Json<MarkChatReadStateResponse>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    check_membership(conn, chat_id, uid)?;

    use crate::schema::group_membership::dsl as gm_dsl;
    diesel::update(
        group_membership::table.filter(gm_dsl::chat_id.eq(chat_id).and(gm_dsl::uid.eq(uid))),
    )
    .set(gm_dsl::last_read_message_id.eq(Some(body.message_id)))
    .execute(conn)
    .map_err(|e| {
        tracing::error!("mark as read: {:?}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, "Failed to mark as read")
    })?;

    let unread_count =
        crate::services::chat::get_chat_unread_count(conn, chat_id, Some(body.message_id))
            .map_err(|e| {
                tracing::error!("mark as read unread count: {:?}", e);
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "Failed to load unread count",
                )
            })?;

    Ok(Json(MarkChatReadStateResponse {
        last_read_message_id: Some(body.message_id),
        unread_count,
    }))
}

/// POST /chats/:chat_id/unread — Mark a chat as unread by rewinding the read pointer.
async fn mark_as_unread(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(ChatIdPath { chat_id }): Path<ChatIdPath>,
) -> Result<Json<MarkChatReadStateResponse>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    check_membership(conn, chat_id, uid)?;

    use crate::schema::messages::dsl;
    let last_two: Vec<i64> = messages::table
        .filter(
            dsl::chat_id
                .eq(chat_id)
                .and(dsl::reply_root_id.is_null())
                .and(dsl::deleted_at.is_null()),
        )
        .order(dsl::id.desc())
        .limit(2)
        .select(dsl::id)
        .load(conn)
        .map_err(|e| {
            tracing::error!("mark as unread query: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to mark as unread",
            )
        })?;

    // If < 2 public messages, set to NULL (entire chat unread); otherwise second-to-last
    let new_read_id = if last_two.len() >= 2 {
        Some(last_two[1])
    } else {
        None
    };

    use crate::schema::group_membership::dsl as gm_dsl;
    diesel::update(
        group_membership::table.filter(gm_dsl::chat_id.eq(chat_id).and(gm_dsl::uid.eq(uid))),
    )
    .set(gm_dsl::last_read_message_id.eq(new_read_id))
    .execute(conn)
    .map_err(|e| {
        tracing::error!("mark as unread update: {:?}", e);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Failed to mark as unread",
        )
    })?;

    // Unread count is always 1 when we rewind to second-to-last, or total messages if NULL
    let unread_count = if new_read_id.is_some() {
        1
    } else {
        last_two.len() as i64
    };

    Ok(Json(MarkChatReadStateResponse {
        last_read_message_id: new_read_id,
        unread_count,
    }))
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UnreadCountResponse {
    unread_count: i64,
}

/// GET /chats/unread — Get total unread count for the current user.
async fn get_unread_count(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
) -> Result<Json<UnreadCountResponse>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    let counts = crate::services::chat::get_unread_counts(conn, &[uid]).map_err(|e| {
        tracing::error!("Failed to get unread counts: {:?}", e);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Failed to get unread counts",
        )
    })?;

    let unread_count = counts.get(&uid).copied().unwrap_or(0);

    Ok(Json(UnreadCountResponse { unread_count }))
}

fn validate_emoji(input: &str) -> Result<String, (StatusCode, &'static str)> {
    if input.is_empty() {
        return Err((StatusCode::BAD_REQUEST, "Invalid emoji"));
    }

    let graphemes: Vec<&str> = input.graphemes(true).collect();

    if !graphemes.iter().all(|g| emojis::get(g).is_some()) {
        return Err((StatusCode::BAD_REQUEST, "Invalid emoji"));
    }

    Ok(input.to_string())
}

fn broadcast_reaction_update(conn: &mut DbConn, state: &AppState, chat_id: i64, message_id: i64) {
    let counts: Vec<(String, i64)> = message_reactions::table
        .filter(message_reactions::message_id.eq(message_id))
        .group_by(message_reactions::emoji)
        .select((message_reactions::emoji, diesel::dsl::count_star()))
        .load(conn)
        .unwrap_or_default();

    // Load reactor UIDs (capped at 5 per emoji)
    let raw_reactors: Vec<(String, i32)> = message_reactions::table
        .filter(message_reactions::message_id.eq(message_id))
        .select((message_reactions::emoji, message_reactions::user_uid))
        .load(conn)
        .unwrap_or_default();

    let mut reactor_uids_map: std::collections::HashMap<String, Vec<i32>> =
        std::collections::HashMap::new();
    for (emoji, uid) in &raw_reactors {
        let entry = reactor_uids_map.entry(emoji.clone()).or_default();
        if entry.len() < 5 {
            entry.push(*uid);
        }
    }

    let all_uids: Vec<i32> = reactor_uids_map
        .values()
        .flatten()
        .copied()
        .collect::<std::collections::HashSet<i32>>()
        .into_iter()
        .collect();
    let names = load_usernames_by_uids(conn, &all_uids);
    let avatars = lookup_user_avatars(state, &all_uids);

    let reactions: Vec<ReactionSummary> = counts
        .into_iter()
        .map(|(emoji, count)| {
            let reactors = reactor_uids_map.get(&emoji).map(|uids| {
                uids.iter()
                    .map(|&uid| ReactionReactor {
                        uid,
                        name: names.get(&uid).cloned().flatten(),
                        avatar_url: avatars.get(&uid).cloned().flatten(),
                    })
                    .collect()
            });
            ReactionSummary {
                emoji,
                count,
                reacted_by_me: None,
                reactors,
            }
        })
        .collect();

    let member_uids: Vec<i32> = group_membership::table
        .filter(group_membership::chat_id.eq(chat_id))
        .select(group_membership::uid)
        .load(conn)
        .unwrap_or_default();

    let ws_msg = std::sync::Arc::new(
        crate::handlers::ws::messages::ServerWsMessage::ReactionUpdated(
            crate::handlers::ws::messages::ReactionUpdatePayload {
                message_id,
                chat_id,
                reactions,
            },
        ),
    );
    state.ws_registry.broadcast_to_uids(&member_uids, ws_msg);
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ReactionDetailGroup {
    emoji: String,
    reactors: Vec<ReactionReactor>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ReactionDetailResponse {
    reactions: Vec<ReactionDetailGroup>,
}

async fn get_reaction_details(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path((chat_id, message_id)): Path<(i64, i64)>,
) -> Result<Json<ReactionDetailResponse>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;
    check_membership(conn, chat_id, uid)?;

    // Verify message exists in this chat
    let _message: Message = messages::table
        .filter(messages::id.eq(message_id))
        .filter(messages::chat_id.eq(chat_id))
        .first(conn)
        .map_err(|_| (StatusCode::NOT_FOUND, "Message not found"))?;

    // Load all reactions for this message
    let raw: Vec<(String, i32)> = message_reactions::table
        .filter(message_reactions::message_id.eq(message_id))
        .order(message_reactions::created_at.asc())
        .select((message_reactions::emoji, message_reactions::user_uid))
        .load(conn)
        .map_err(|e| {
            tracing::error!("load reactions: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to load reactions",
            )
        })?;

    // Group by emoji, preserving order
    let mut groups: Vec<ReactionDetailGroup> = Vec::new();
    let mut emoji_index: std::collections::HashMap<String, usize> =
        std::collections::HashMap::new();
    let mut all_uids = std::collections::HashSet::new();

    for (emoji, uid) in &raw {
        all_uids.insert(*uid);
        if let Some(&idx) = emoji_index.get(emoji) {
            groups[idx].reactors.push(ReactionReactor {
                uid: *uid,
                name: None,
                avatar_url: None,
            });
        } else {
            let idx = groups.len();
            emoji_index.insert(emoji.clone(), idx);
            groups.push(ReactionDetailGroup {
                emoji: emoji.clone(),
                reactors: vec![ReactionReactor {
                    uid: *uid,
                    name: None,
                    avatar_url: None,
                }],
            });
        }
    }

    // Resolve names + avatars
    let uids_vec: Vec<i32> = all_uids.into_iter().collect();
    let names = load_usernames_by_uids(conn, &uids_vec);
    let avatars = lookup_user_avatars(&state, &uids_vec);

    for group in &mut groups {
        for reactor in &mut group.reactors {
            reactor.name = names.get(&reactor.uid).cloned().flatten();
            reactor.avatar_url = avatars.get(&reactor.uid).cloned().flatten();
        }
    }

    Ok(Json(ReactionDetailResponse { reactions: groups }))
}

async fn put_reaction(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path((chat_id, message_id, emoji)): Path<(i64, i64, String)>,
) -> Result<StatusCode, (StatusCode, &'static str)> {
    let emoji = validate_emoji(&emoji)?;
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;
    check_membership(conn, chat_id, uid)?;

    // Verify message exists and belongs to this chat
    let _message: Message = messages::table
        .filter(messages::id.eq(message_id))
        .filter(messages::chat_id.eq(chat_id))
        .filter(messages::deleted_at.is_null())
        .first(conn)
        .map_err(|_| (StatusCode::NOT_FOUND, "Message not found"))?;

    // Insert reaction (ON CONFLICT DO NOTHING for idempotency)
    diesel::insert_into(message_reactions::table)
        .values(&MessageReaction {
            message_id,
            user_uid: uid,
            emoji,
            created_at: Utc::now(),
        })
        .on_conflict_do_nothing()
        .execute(conn)
        .map_err(|e| {
            tracing::error!("insert reaction: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to add reaction")
        })?;

    // Set denormalized flag
    diesel::update(messages::table.filter(messages::id.eq(message_id)))
        .set(messages::has_reactions.eq(true))
        .execute(conn)
        .map_err(|e| {
            tracing::error!("update has_reactions: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to update message",
            )
        })?;

    broadcast_reaction_update(conn, &state, chat_id, message_id);

    Ok(StatusCode::NO_CONTENT)
}

async fn delete_reaction(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path((chat_id, message_id, emoji)): Path<(i64, i64, String)>,
) -> Result<StatusCode, (StatusCode, &'static str)> {
    let emoji = validate_emoji(&emoji)?;
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;
    check_membership(conn, chat_id, uid)?;

    let deleted = diesel::delete(
        message_reactions::table
            .filter(message_reactions::message_id.eq(message_id))
            .filter(message_reactions::user_uid.eq(uid))
            .filter(message_reactions::emoji.eq(&emoji)),
    )
    .execute(conn)
    .map_err(|e| {
        tracing::error!("delete reaction: {:?}", e);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Failed to remove reaction",
        )
    })?;

    if deleted > 0 {
        let remaining: i64 = message_reactions::table
            .filter(message_reactions::message_id.eq(message_id))
            .count()
            .get_result(conn)
            .unwrap_or(0);

        if remaining == 0 {
            diesel::update(messages::table.filter(messages::id.eq(message_id)))
                .set(messages::has_reactions.eq(false))
                .execute(conn)
                .map_err(|e| {
                    tracing::error!("update has_reactions: {:?}", e);
                    (
                        StatusCode::INTERNAL_SERVER_ERROR,
                        "Failed to update message",
                    )
                })?;
        }

        broadcast_reaction_update(conn, &state, chat_id, message_id);
    }

    Ok(StatusCode::NO_CONTENT)
}

pub fn router() -> Router<crate::AppState> {
    use axum::routing::*;
    Router::new()
        .route("/", get(get_chats)) //
        .route("/unread", get(get_unread_count))
        .nest(
            "/{chat_id}",
            Router::new() //
                .nest(
                    "/messages",
                    Router::new()
                        .route("/", get(get_messages).post(post_message))
                        .route(
                            "/{message_id}",
                            get(get_message).patch(patch_message).delete(delete_message),
                        )
                        .route("/{message_id}/reactions", get(get_reaction_details))
                        .route(
                            "/{message_id}/reactions/{emoji}",
                            put(put_reaction).delete(delete_reaction),
                        ),
                )
                .route("/read", post(mark_as_read))
                .route("/unread", post(mark_as_unread))
                .route("/threads/{thread_id}/messages", post(post_thread_message))
                .nest(
                    "/threads/{thread_root_id}",
                    super::threads::subscribe_router(),
                ),
        )
}
