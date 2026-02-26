use axum::{extract::{Path, State}, http::StatusCode, Json};
use chrono::{DateTime, Utc};
use diesel::prelude::*;
use serde::Serialize;

use crate::schema::{group_membership, users};
use crate::utils::auth::CurrentUid;

use crate::AppState;

#[derive(serde::Deserialize)]
pub struct ChatIdPath {
    chat_id: i64,
}

#[derive(Serialize)]
pub struct MemberResponse {
    uid: i32,
    role: String,
    joined_at: DateTime<Utc>,
    username: Option<String>,
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

/// GET /chats/:chat_id/members — List members of a chat.
pub async fn get_members(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(ChatIdPath { chat_id }): Path<ChatIdPath>,
) -> Result<Json<Vec<MemberResponse>>, (StatusCode, &'static str)> {
    let conn = &mut state
        .db
        .get()
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Database connection failed"))?;

    check_membership(conn, chat_id, uid)?;

    let rows: Vec<(i32, String, DateTime<Utc>, String)> = group_membership::table
        .filter(crate::schema::group_membership::chat_id.eq(chat_id))
        .inner_join(users::table)
        .select((
            crate::schema::group_membership::uid,
            crate::schema::group_membership::role,
            crate::schema::group_membership::joined_at,
            users::username,
        ))
        .load(conn)
        .map_err(|e| {
            tracing::error!("list members: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to list members")
        })?;

    let members: Vec<MemberResponse> = rows
        .into_iter()
        .map(|(uid, role, joined_at, username)| MemberResponse {
            uid,
            role,
            joined_at,
            username: Some(username),
        })
        .collect();

    Ok(Json(members))
}
