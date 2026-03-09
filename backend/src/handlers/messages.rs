use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use chrono::{DateTime, Utc};
use diesel::prelude::*;
use serde::Serialize;

use crate::handlers::members::check_membership;
use crate::models::{
    Attachment, AttachmentResponse, Message, MessageType, NewMessage, Sender, ThreadInfo,
};
use crate::schema::{attachments, group_membership, groups, messages, users};
use crate::services::push::PushJob;
use crate::services::user::lookup_users;
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
pub struct ListMessagesResponse {
    messages: Vec<MessageResponse>,
    #[serde(with = "crate::serde_i64_string::opt")]
    next_cursor: Option<i64>,
    #[serde(with = "crate::serde_i64_string::opt")]
    prev_cursor: Option<i64>,
}

#[derive(Serialize)]
pub struct MessageResponse {
    #[serde(with = "crate::serde_i64_string")]
    id: i64,
    message: Option<String>,
    message_type: MessageType,
    #[serde(with = "crate::serde_i64_string::opt")]
    reply_root_id: Option<i64>,
    client_generated_id: String,
    sender: Sender,
    #[serde(with = "crate::serde_i64_string")]
    chat_id: i64,
    created_at: DateTime<Utc>,
    is_edited: bool,
    is_deleted: bool,
    has_attachments: bool,
    thread_info: Option<ThreadInfo>,
    reply_to_message: Option<Box<ReplyToMessage>>,
    attachments: Vec<AttachmentResponse>,
}

#[derive(Serialize)]
pub struct ReplyToMessage {
    #[serde(with = "crate::serde_i64_string")]
    id: i64,
    message: Option<String>,
    sender: Sender,
    is_deleted: bool,
}

/// Attach reply_to_message to a list of messages by fetching referenced messages in one query.
async fn attach_replies(
    conn: &mut diesel::r2d2::PooledConnection<
        diesel::r2d2::ConnectionManager<diesel::PgConnection>,
    >,
    messages_to_process: Vec<Message>,
    state: &AppState,
) -> Vec<MessageResponse> {
    use crate::schema::messages::dsl;
    let reply_ids: Vec<i64> = messages_to_process
        .iter()
        .filter_map(|m| m.reply_to_id)
        .collect();

    let mut uids_to_lookup = std::collections::HashSet::new();
    for m in &messages_to_process {
        uids_to_lookup.insert(m.sender_uid);
    }

    let mut reply_messages_map = std::collections::HashMap::new();
    if !reply_ids.is_empty() {
        let reply_messages: Vec<Message> = messages::table
            .filter(dsl::id.eq_any(&reply_ids))
            .select(Message::as_select())
            .load(conn)
            .unwrap_or_default();
        for msg in reply_messages {
            uids_to_lookup.insert(msg.sender_uid);
            reply_messages_map.insert(msg.id, msg);
        }
    }

    let target_uids: Vec<i32> = uids_to_lookup.into_iter().collect();
    let user_names = lookup_users(state, &target_uids).await;

    let mut message_attachments_map: std::collections::HashMap<i64, Vec<Attachment>> =
        std::collections::HashMap::new();
    let message_ids: Vec<i64> = messages_to_process.iter().map(|m| m.id).collect();
    if !message_ids.is_empty() {
        use crate::schema::attachments::dsl as a_dsl;
        let attachments: Vec<Attachment> = attachments::table
            .filter(a_dsl::message_id.eq_any(&message_ids))
            .select(Attachment::as_select())
            .load(conn)
            .unwrap_or_default();
        for att in attachments {
            if let Some(msg_id) = att.message_id {
                message_attachments_map.entry(msg_id).or_default().push(att);
            }
        }
    }

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

    let mut responses = Vec::with_capacity(messages_to_process.len());
    for m in messages_to_process {
        let reply_to_message = m.reply_to_id.and_then(|reply_id| {
            reply_messages_map.get(&reply_id).map(|reply_msg| {
                Box::new(ReplyToMessage {
                    id: reply_msg.id,
                    message: if reply_msg.deleted_at.is_some() {
                        None
                    } else {
                        reply_msg.message.clone()
                    },
                    sender: Sender {
                        uid: reply_msg.sender_uid,
                        name: user_names.get(&reply_msg.sender_uid).cloned().flatten(),
                    },
                    is_deleted: reply_msg.deleted_at.is_some(),
                })
            })
        });

        let mut attachments = Vec::new();
        if let Some(atts) = message_attachments_map.remove(&m.id) {
            for att in atts {
                let base_url = state.s3_base_url.clone().unwrap_or_else(|| {
                    format!("https://{}.s3.amazonaws.com", state.s3_bucket_name)
                });
                let url = format!("{}/{}", base_url, att.external_reference);

                attachments.push(AttachmentResponse {
                    id: att.id,
                    url,
                    kind: att.kind,
                    size: att.size,
                    file_name: att.file_name,
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
            reply_root_id: m.reply_root_id,
            client_generated_id: m.client_generated_id,
            sender: Sender {
                uid: m.sender_uid,
                name: user_names.get(&m.sender_uid).cloned().flatten(),
            },
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
        });
    }
    responses
}

/// GET /chats/:chat_id/messages — List messages in a chat (cursor-based).
pub async fn get_messages(
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
            .order(dsl::created_at.asc())
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
            .order(dsl::created_at.desc())
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

        let messages_vec = attach_replies(conn, combined, &state).await;

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
            .order(dsl::created_at.asc())
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

        let messages_vec = attach_replies(conn, messages_to_process, &state).await;

        return Ok(Json(ListMessagesResponse {
            messages: messages_vec,
            next_cursor: None,
            prev_cursor,
        }));
    }

    // Default: before cursor, descending (newest first in response, reversed by client)
    let rows: Vec<Message> = match q.before {
        None => base_query!()
            .order(dsl::created_at.desc())
            .limit(max + 1)
            .select(Message::as_select())
            .load(conn),
        Some(before) => base_query!()
            .filter(dsl::id.lt(before))
            .order(dsl::created_at.desc())
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

    let messages_vec = attach_replies(conn, messages_to_process, &state).await;

    Ok(Json(ListMessagesResponse {
        messages: messages_vec,
        next_cursor,
        prev_cursor: None,
    }))
}

#[derive(serde::Deserialize)]
pub struct CreateMessageBody {
    message: Option<String>,
    message_type: MessageType,
    client_generated_id: String,
    #[serde(
        default,
        deserialize_with = "crate::serde_i64_string::opt::deserialize"
    )]
    reply_to_id: Option<i64>,
    #[serde(default)]
    attachment_ids: Vec<String>,
}

#[derive(serde::Deserialize)]
pub struct ThreadIdPath {
    chat_id: i64,
    #[serde(deserialize_with = "crate::serde_i64_string::deserialize")]
    thread_id: i64,
}

/// POST /chats/:chat_id/messages — Send a message.
pub async fn post_message(
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
        reply_root_id: None,
        created_at: now,
        client_generated_id: body.client_generated_id,
        sender_uid: uid,
        chat_id,
        updated_at: None,
        deleted_at: None,
        has_attachments: !body.attachment_ids.is_empty(),
        has_thread: false,
    };

    let inserted_msg: Message = diesel::insert_into(messages::table)
        .values(&new_msg)
        .returning(Message::as_returning())
        .get_result(conn)
        .map_err(|e| {
            tracing::error!("insert message: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to send message")
        })?;

    if !body.attachment_ids.is_empty() {
        let attachment_ids: Vec<i64> = body
            .attachment_ids
            .iter()
            .filter_map(|s| s.parse().ok())
            .collect();
        use crate::schema::attachments::dsl as a_dsl;
        let _: usize = diesel::update(attachments::table.filter(a_dsl::id.eq_any(&attachment_ids)))
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

    let response = attach_replies(conn, vec![inserted_msg], &state)
        .await
        .into_iter()
        .next()
        .unwrap();

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

    // Enqueue push notification job (non-blocking; runs in background).
    let sender_username = users::table
        .filter(users::dsl::uid.eq(uid))
        .select(users::dsl::username)
        .first::<String>(conn)
        .unwrap_or_else(|_| "Someone".to_string());
    let chat_name = groups::table
        .filter(groups::dsl::id.eq(chat_id))
        .select(groups::dsl::name)
        .first::<String>(conn)
        .unwrap_or_else(|_| "Chat".to_string());
    state.push_service.enqueue(PushJob {
        chat_id,
        sender_uid: uid,
        sender_username,
        chat_name,
        message_preview: response.message.clone(),
        message_id: response.id,
    });

    Ok((StatusCode::CREATED, Json(response)))
}

/// POST /chats/:chat_id/threads/:thread_id/messages — Send a message in a thread.
pub async fn post_thread_message(
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
        reply_root_id: Some(thread_id),
        created_at: now,
        client_generated_id: body.client_generated_id,
        sender_uid: uid,
        chat_id,
        updated_at: None,
        deleted_at: None,
        has_attachments: !body.attachment_ids.is_empty(),
        has_thread: false,
    };

    let inserted_msg: Message = diesel::insert_into(messages::table)
        .values(&new_msg)
        .returning(Message::as_returning())
        .get_result(conn)
        .map_err(|e| {
            tracing::error!("insert threaded message: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to send message")
        })?;

    if !body.attachment_ids.is_empty() {
        let attachment_ids: Vec<i64> = body
            .attachment_ids
            .iter()
            .filter_map(|s| s.parse().ok())
            .collect();
        use crate::schema::attachments::dsl as a_dsl;
        let _: usize = diesel::update(attachments::table.filter(a_dsl::id.eq_any(&attachment_ids)))
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

    let response = attach_replies(conn, vec![inserted_msg], &state)
        .await
        .into_iter()
        .next()
        .unwrap();

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

    // Enqueue push notification job (non-blocking; runs in background).
    let sender_username = users::table
        .filter(users::dsl::uid.eq(uid))
        .select(users::dsl::username)
        .first::<String>(conn)
        .unwrap_or_else(|_| "Someone".to_string());
    let chat_name = groups::table
        .filter(groups::dsl::id.eq(chat_id))
        .select(groups::dsl::name)
        .first::<String>(conn)
        .unwrap_or_else(|_| "Chat".to_string());
    state.push_service.enqueue(PushJob {
        chat_id,
        sender_uid: uid,
        sender_username,
        chat_name,
        message_preview: response.message.clone(),
        message_id: response.id,
    });

    // Mark the root message as having a thread
    let root_msg_updated: Option<Message> =
        diesel::update(messages::table.filter(dsl::id.eq(thread_id)))
            .set(dsl::has_thread.eq(true))
            .get_result(conn)
            .ok();

    if let Some(root_msg) = root_msg_updated {
        let root_response = attach_replies(conn, vec![root_msg], &state)
            .await
            .into_iter()
            .next()
            .unwrap();
        if let Ok(ws_json) = serde_json::to_string(&serde_json::json!({
            "type": "message_updated",
            "payload": &root_response
        })) {
            state.ws_registry.broadcast_to_uids(&member_uids, &ws_json);
        }
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

    if body.message.trim().is_empty() {
        return Err((StatusCode::BAD_REQUEST, "Message cannot be empty"));
    }

    // Update message
    let now = Utc::now();
    let updated_message: Message = diesel::update(messages::table.filter(dsl::id.eq(message_id)))
        .set((
            dsl::message.eq(&body.message),
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

    let response = attach_replies(conn, vec![updated_message], &state)
        .await
        .into_iter()
        .next()
        .unwrap();

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

    let response = attach_replies(conn, vec![deleted_message], &state)
        .await
        .into_iter()
        .next()
        .unwrap();

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

/// GET /chats/:chat_id/messages/:message_id — Get a single message.
pub async fn get_message(
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

    let messages_vec = attach_replies(conn, vec![message], &state).await;
    let response = messages_vec.into_iter().next().unwrap();

    Ok(Json(response))
}
