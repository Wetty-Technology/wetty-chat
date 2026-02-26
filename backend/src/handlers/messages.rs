use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use chrono::{DateTime, Utc};
use diesel::prelude::*;
use serde::Serialize;

use crate::models::{Message, NewMessage};
use crate::schema::{group_membership, messages};
use crate::utils::auth::CurrentUid;
use crate::utils::ids;
use crate::{AppState, MAX_MESSAGES_LIMIT};

use crate::schema::group_membership::dsl as gm_dsl;

#[derive(serde::Deserialize)]
pub struct ChatIdPath {
    chat_id: i64,
}

#[derive(serde::Deserialize)]
pub struct ListMessagesQuery {
    #[serde(default, deserialize_with = "crate::serde_i64_string::opt::deserialize")]
    before: Option<i64>,
    #[serde(default)]
    max: Option<i64>,
}

#[derive(Serialize)]
pub struct ListMessagesResponse {
    messages: Vec<MessageResponse>,
    #[serde(with = "crate::serde_i64_string::opt")]
    next_cursor: Option<i64>,
}

#[derive(Serialize)]
pub struct MessageResponse {
    #[serde(with = "crate::serde_i64_string")]
    id: i64,
    message: Option<String>,
    message_type: String,
    #[serde(with = "crate::serde_i64_string::opt")]
    reply_to_id: Option<i64>,
    #[serde(with = "crate::serde_i64_string::opt")]
    reply_root_id: Option<i64>,
    client_generated_id: String,
    sender_uid: i32,
    #[serde(with = "crate::serde_i64_string")]
    chat_id: i64,
    created_at: DateTime<Utc>,
    updated_at: Option<DateTime<Utc>>,
    deleted_at: Option<DateTime<Utc>>,
    has_attachments: bool,
    reply_to_message: Option<Box<ReplyToMessage>>,
}

#[derive(Serialize)]
pub struct ReplyToMessage {
    #[serde(with = "crate::serde_i64_string")]
    id: i64,
    message: Option<String>,
    sender_uid: i32,
    deleted_at: Option<DateTime<Utc>>,
}

impl From<Message> for MessageResponse {
    fn from(m: Message) -> Self {
        MessageResponse {
            id: m.id,
            message: m.message,
            message_type: m.message_type,
            reply_to_id: m.reply_to_id,
            reply_root_id: m.reply_root_id,
            client_generated_id: m.client_generated_id,
            sender_uid: m.sender_uid,
            chat_id: m.chat_id,
            created_at: m.created_at,
            updated_at: m.updated_at,
            deleted_at: m.deleted_at,
            has_attachments: m.has_attachments,
            reply_to_message: None,
        }
    }
}

/// Check if user is a member of the chat; return 403 if not.
fn check_membership(
    conn: &mut diesel::r2d2::PooledConnection<diesel::r2d2::ConnectionManager<diesel::PgConnection>>,
    chat_id: i64,
    uid: i32,
) -> Result<(), (StatusCode, &'static str)> {
    use crate::schema::group_membership::dsl;
    let exists = group_membership::table
        .filter(dsl::chat_id.eq(chat_id).and(dsl::uid.eq(uid)))
        .count()
        .get_result::<i64>(conn)
        .map_err(|e| {
            tracing::error!("check membership: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;
    if exists == 0 {
        return Err((StatusCode::FORBIDDEN, "Not a member of this chat"));
    }
    Ok(())
}

/// GET /chats/:chat_id/messages — List messages in a chat (cursor-based).
pub async fn get_messages(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(ChatIdPath { chat_id }): Path<ChatIdPath>,
    Query(q): Query<ListMessagesQuery>,
) -> Result<Json<ListMessagesResponse>, (StatusCode, &'static str)> {
    let conn = &mut state
        .db
        .get()
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Database connection failed"))?;

    check_membership(conn, chat_id, uid)?;

    let max = q
        .max
        .map(|m| std::cmp::min(m, MAX_MESSAGES_LIMIT))
        .unwrap_or(MAX_MESSAGES_LIMIT)
        .max(1);

    use crate::schema::messages::dsl;
    let rows: Vec<Message> = match q.before {
        None => messages::table
            .filter(dsl::chat_id.eq(chat_id))
            .order(dsl::id.desc())
            .limit(max + 1)
            .select(Message::as_select())
            .load(conn),
        Some(before) => messages::table
            .filter(dsl::chat_id.eq(chat_id).and(dsl::id.lt(before)))
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

    // Collect all reply_to_ids
    let reply_ids: Vec<i64> = messages_to_process
        .iter()
        .filter_map(|m| m.reply_to_id)
        .collect();

    // Fetch all referenced messages in one query
    let mut reply_messages_map = std::collections::HashMap::new();
    if !reply_ids.is_empty() {
        let reply_messages: Vec<Message> = messages::table
            .filter(dsl::id.eq_any(&reply_ids))
            .select(Message::as_select())
            .load(conn)
            .unwrap_or_default();

        for msg in reply_messages {
            reply_messages_map.insert(msg.id, msg);
        }
    }

    // Build MessageResponse with reply_to_message
    let messages_vec: Vec<MessageResponse> = messages_to_process
        .into_iter()
        .map(|m| {
            let reply_to_message = m.reply_to_id.and_then(|reply_id| {
                reply_messages_map.get(&reply_id).map(|reply_msg| {
                    Box::new(ReplyToMessage {
                        id: reply_msg.id,
                        message: reply_msg.message.clone(),
                        sender_uid: reply_msg.sender_uid,
                        deleted_at: reply_msg.deleted_at,
                    })
                })
            });

            MessageResponse {
                id: m.id,
                message: m.message,
                message_type: m.message_type,
                reply_to_id: m.reply_to_id,
                reply_root_id: m.reply_root_id,
                client_generated_id: m.client_generated_id,
                sender_uid: m.sender_uid,
                chat_id: m.chat_id,
                created_at: m.created_at,
                updated_at: m.updated_at,
                deleted_at: m.deleted_at,
                has_attachments: m.has_attachments,
                reply_to_message,
            }
        })
        .collect();
    let next_cursor = has_more.then(|| messages_vec.last().map(|m| m.id)).flatten();

    Ok(Json(ListMessagesResponse {
        messages: messages_vec,
        next_cursor,
    }))
}

#[derive(serde::Deserialize)]
pub struct CreateMessageBody {
    message: Option<String>,
    message_type: String,
    client_generated_id: String,
    #[serde(default, deserialize_with = "crate::serde_i64_string::opt::deserialize")]
    reply_to_id: Option<i64>,
    #[serde(default, deserialize_with = "crate::serde_i64_string::opt::deserialize")]
    reply_root_id: Option<i64>,
}

/// POST /chats/:chat_id/messages — Send a message.
pub async fn post_message(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(ChatIdPath { chat_id }): Path<ChatIdPath>,
    Json(body): Json<CreateMessageBody>,
) -> Result<impl IntoResponse, (StatusCode, &'static str)> {
    let conn = &mut state
        .db
        .get()
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Database connection failed"))?;

    check_membership(conn, chat_id, uid)?;

    let id = ids::next_message_id(state.id_gen.as_ref())
        .await
        .map_err(|e| {
            tracing::error!("ferroid next_message_id: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "ID generation failed")
        })?;

    let now = Utc::now();

    let new_msg = NewMessage {
        id,
        message: body.message,
        message_type: body.message_type,
        reply_to_id: body.reply_to_id,
        reply_root_id: body.reply_root_id,
        created_at: now,
        client_generated_id: body.client_generated_id,
        sender_uid: uid,
        chat_id,
        updated_at: None,
        deleted_at: None,
        has_attachments: false,
    };

    diesel::insert_into(messages::table)
        .values(&new_msg)
        .execute(conn)
        .map_err(|e| {
            tracing::error!("insert message: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to send message")
        })?;

    // Fetch reply_to_message if exists
    let reply_to_message = if let Some(reply_id) = new_msg.reply_to_id {
        use crate::schema::messages::dsl;
        messages::table
            .filter(dsl::id.eq(reply_id))
            .select(Message::as_select())
            .first(conn)
            .ok()
            .map(|reply_msg: Message| {
                Box::new(ReplyToMessage {
                    id: reply_msg.id,
                    message: reply_msg.message,
                    sender_uid: reply_msg.sender_uid,
                    deleted_at: reply_msg.deleted_at,
                })
            })
    } else {
        None
    };

    let response = MessageResponse {
        id: new_msg.id,
        message: new_msg.message,
        message_type: new_msg.message_type,
        reply_to_id: new_msg.reply_to_id,
        reply_root_id: new_msg.reply_root_id,
        client_generated_id: new_msg.client_generated_id,
        sender_uid: new_msg.sender_uid,
        chat_id: new_msg.chat_id,
        created_at: new_msg.created_at,
        updated_at: new_msg.updated_at,
        deleted_at: new_msg.deleted_at,
        has_attachments: new_msg.has_attachments,
        reply_to_message,
    };

    let member_uids: Vec<i32> = group_membership::table
        .filter(gm_dsl::chat_id.eq(chat_id))
        .select(group_membership::uid)
        .load(conn)
        .map_err(|e| {
            tracing::error!("list members for broadcast: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;
    if let Ok(ws_json) = serde_json::to_string(&serde_json::json!({
        "type": "message",
        "payload": &response
    })) {
        state.ws_registry.broadcast_to_uids(&member_uids, &ws_json);
    }

    Ok((StatusCode::CREATED, Json(response)))
}

#[derive(serde::Deserialize)]
pub struct MessageIdPath {
    chat_id: i64,
    #[serde(deserialize_with = "crate::serde_i64_string::deserialize")]
    message_id: i64,
}

#[derive(serde::Deserialize)]
pub struct UpdateMessageBody {
    message: String,
}

/// PATCH /chats/:chat_id/messages/:message_id — Edit a message.
pub async fn patch_message(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(MessageIdPath { chat_id, message_id }): Path<MessageIdPath>,
    Json(body): Json<UpdateMessageBody>,
) -> Result<Json<MessageResponse>, (StatusCode, &'static str)> {
    let conn = &mut state
        .db
        .get()
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Database connection failed"))?;

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

    if body.message.trim().is_empty() {
        return Err((StatusCode::BAD_REQUEST, "Message cannot be empty"));
    }

    // Update message
    let now = Utc::now();
    diesel::update(messages::table.filter(dsl::id.eq(message_id)))
        .set((dsl::message.eq(&body.message), dsl::updated_at.eq(Some(now))))
        .execute(conn)
        .map_err(|e| {
            tracing::error!("update message: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to update message")
        })?;

    let updated_message: Message = messages::table
        .filter(dsl::id.eq(message_id))
        .select(Message::as_select())
        .first(conn)
        .map_err(|e| {
            tracing::error!("fetch updated message: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch updated message")
        })?;

    let response = MessageResponse::from(updated_message);

    // Broadcast update to all members
    let member_uids: Vec<i32> = group_membership::table
        .filter(gm_dsl::chat_id.eq(chat_id))
        .select(group_membership::uid)
        .load(conn)
        .map_err(|e| {
            tracing::error!("list members for broadcast: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;
    if let Ok(ws_json) = serde_json::to_string(&serde_json::json!({
        "type": "message_updated",
        "payload": &response
    })) {
        state.ws_registry.broadcast_to_uids(&member_uids, &ws_json);
    }

    Ok(Json(response))
}

/// DELETE /chats/:chat_id/messages/:message_id — Delete a message (soft delete).
pub async fn delete_message(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(MessageIdPath { chat_id, message_id }): Path<MessageIdPath>,
) -> Result<StatusCode, (StatusCode, &'static str)> {
    let conn = &mut state
        .db
        .get()
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Database connection failed"))?;

    check_membership(conn, chat_id, uid)?;

    // Verify message exists and belongs to the user
    use crate::schema::messages::dsl;
    let message: Message = messages::table
        .filter(dsl::id.eq(message_id).and(dsl::chat_id.eq(chat_id)))
        .select(Message::as_select())
        .first(conn)
        .map_err(|_| (StatusCode::NOT_FOUND, "Message not found"))?;

    if message.sender_uid != uid {
        return Err((StatusCode::FORBIDDEN, "You can only delete your own messages"));
    }

    if message.deleted_at.is_some() {
        return Err((StatusCode::GONE, "Message already deleted"));
    }

    // Soft delete message
    let now = Utc::now();
    diesel::update(messages::table.filter(dsl::id.eq(message_id)))
        .set(dsl::deleted_at.eq(Some(now)))
        .execute(conn)
        .map_err(|e| {
            tracing::error!("delete message: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to delete message")
        })?;

    let deleted_message: Message = messages::table
        .filter(dsl::id.eq(message_id))
        .select(Message::as_select())
        .first(conn)
        .map_err(|e| {
            tracing::error!("fetch deleted message: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch deleted message")
        })?;

    let response = MessageResponse::from(deleted_message);

    // Broadcast deletion to all members
    let member_uids: Vec<i32> = group_membership::table
        .filter(gm_dsl::chat_id.eq(chat_id))
        .select(group_membership::uid)
        .load(conn)
        .map_err(|e| {
            tracing::error!("list members for broadcast: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;
    if let Ok(ws_json) = serde_json::to_string(&serde_json::json!({
        "type": "message_deleted",
        "payload": &response
    })) {
        state.ws_registry.broadcast_to_uids(&member_uids, &ws_json);
    }

    Ok(StatusCode::NO_CONTENT)
}
