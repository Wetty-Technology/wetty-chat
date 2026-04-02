use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    Json, Router,
};
use chrono::{DateTime, Utc};
use diesel::prelude::*;
use serde::Serialize;
use std::collections::HashMap;

use crate::{
    errors::AppError,
    extractors::DbConn,
    handlers::chats::MessageResponse,
    handlers::members::check_membership,
    models::Message,
    schema::messages,
    services::threads as thread_svc,
    utils::{auth::CurrentUid, pagination::validate_limit},
    AppState,
};

// Re-use the attach_metadata function from chats
use crate::handlers::chats::attach_metadata;

// Re-export response type used by the handler
pub use thread_svc::ListThreadsResponse;

#[derive(serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ListThreadsQuery {
    #[serde(default)]
    limit: Option<i64>,
    #[serde(default)]
    before: Option<DateTime<Utc>>,
}

/// GET /threads — List threads the user is subscribed to.
async fn get_threads(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    mut conn: DbConn,
    Query(query): Query<ListThreadsQuery>,
) -> Result<Json<ListThreadsResponse>, AppError> {
    let conn = &mut *conn;

    let limit = validate_limit(query.limit.or(Some(20)), 50);
    let rows = thread_svc::get_user_threads(conn, uid, limit + 1, query.before)?;

    let has_more = rows.len() as i64 > limit;
    let rows: Vec<_> = rows.into_iter().take(limit as usize).collect();

    let root_ids: Vec<i64> = rows.iter().map(|r| r.thread_root_id).collect();

    if root_ids.is_empty() {
        return Ok(Json(ListThreadsResponse {
            threads: vec![],
            next_cursor: None,
        }));
    }

    // Load root messages and enrich with metadata
    let root_messages: Vec<Message> = messages::table
        .filter(messages::id.eq_any(&root_ids))
        .select(Message::as_select())
        .load(conn)?;

    let enriched = attach_metadata(conn, root_messages, &state, uid).await;
    let msg_map: HashMap<i64, MessageResponse> = enriched.into_iter().map(|m| (m.id, m)).collect();

    // Delegate enrichment and assembly to the service layer
    let response = thread_svc::enrich_thread_list(conn, rows, has_more, msg_map, &state);

    Ok(Json(response))
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
    Path(ThreadRootIdPath { thread_root_id }): Path<ThreadRootIdPath>,
    mut conn: DbConn,
    Json(body): Json<MarkThreadReadBody>,
) -> Result<Json<MarkThreadReadResponse>, AppError> {
    let conn = &mut *conn;

    let updated = thread_svc::mark_thread_as_read(conn, thread_root_id, uid, body.message_id)?;

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
    mut conn: DbConn,
) -> Result<Json<UnreadThreadCountResponse>, AppError> {
    let conn = &mut *conn;

    let count = thread_svc::get_total_unread_thread_count(conn, uid)?;

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
    Path(ThreadSubscribePath {
        chat_id,
        thread_root_id,
    }): Path<ThreadSubscribePath>,
    mut conn: DbConn,
) -> Result<StatusCode, AppError> {
    let conn = &mut *conn;

    check_membership(conn, chat_id, uid)?;

    // Verify the thread root message exists
    let exists: bool = diesel::select(diesel::dsl::exists(
        messages::table.filter(
            messages::id
                .eq(thread_root_id)
                .and(messages::chat_id.eq(chat_id)),
        ),
    ))
    .get_result(conn)?;

    if !exists {
        return Err(AppError::NotFound("Thread root message not found"));
    }

    thread_svc::subscribe_to_thread(conn, chat_id, thread_root_id, uid)?;

    Ok(StatusCode::NO_CONTENT)
}

/// DELETE /chats/:chat_id/threads/:thread_root_id/subscribe — Unfollow a thread.
async fn unsubscribe_thread(
    CurrentUid(uid): CurrentUid,
    Path(ThreadSubscribePath {
        chat_id,
        thread_root_id,
    }): Path<ThreadSubscribePath>,
    mut conn: DbConn,
) -> Result<StatusCode, AppError> {
    let conn = &mut *conn;

    check_membership(conn, chat_id, uid)?;

    thread_svc::unsubscribe_from_thread(conn, chat_id, thread_root_id, uid)?;

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
    Path(ThreadSubscriptionStatusPath {
        chat_id,
        thread_root_id,
    }): Path<ThreadSubscriptionStatusPath>,
    mut conn: DbConn,
) -> Result<Json<ThreadSubscriptionStatusResponse>, AppError> {
    let conn = &mut *conn;

    check_membership(conn, chat_id, uid)?;

    let subscribed = thread_svc::is_subscribed(conn, chat_id, thread_root_id, uid)?;

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
