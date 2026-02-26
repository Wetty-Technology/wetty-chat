use axum::{extract::{Path, State}, http::StatusCode, Json};
use chrono::Utc;
use diesel::prelude::*;
use serde::Serialize;

use crate::models::NewGroupMembership;
use crate::schema;
use crate::utils::auth::CurrentUid;

use crate::AppState;

#[derive(serde::Deserialize)]
pub struct ChatIdPath {
    pub chat_id: i64,
}

#[derive(serde::Deserialize)]
pub struct MemberIdPath {
    chat_id: i64,
    uid: i32,
}

#[derive(serde::Deserialize)]
pub struct AddMemberBody {
    uid: i32,
}

#[derive(Serialize)]
pub struct MemberResponse {
    uid: i32,
    role: String,
    username: Option<String>,
}

/// Check if user is a member of the chat; return 403 if not.
pub(crate) fn check_membership(
    conn: &mut diesel::r2d2::PooledConnection<diesel::r2d2::ConnectionManager<diesel::PgConnection>>,
    chat_id: i64,
    uid: i32,
) -> Result<(), (StatusCode, &'static str)> {
    use crate::schema::group_membership::dsl;
    let exists = schema::group_membership::table
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

/// Check if user is an admin of the chat; return 403 if not a member or not admin.
fn check_admin(
    conn: &mut diesel::r2d2::PooledConnection<diesel::r2d2::ConnectionManager<diesel::PgConnection>>,
    chat_id: i64,
    uid: i32,
) -> Result<(), (StatusCode, &'static str)> {
    use crate::schema::group_membership::dsl;
    let role: Option<String> = schema::group_membership::table
        .filter(dsl::chat_id.eq(chat_id).and(dsl::uid.eq(uid)))
        .select(dsl::role)
        .get_result(conn)
        .optional()
        .map_err(|e| {
            tracing::error!("check admin: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;
    match role.as_deref() {
        Some("admin") => Ok(()),
        Some(_) => Err((StatusCode::FORBIDDEN, "Not an admin of this chat")),
        None => Err((StatusCode::FORBIDDEN, "Not a member of this chat")),
    }
}

// TODO: deal with pagination later. I think we just return a list of member IDs for now
/// GET /a/group/:chat_id/members — List members of a chat.
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

    let rows: Vec<(i32, String, String)> = schema::group_membership::table
        .filter(schema::group_membership::chat_id.eq(chat_id))
        .inner_join(schema::users::table)
        .select((
            schema::group_membership::uid,
            schema::group_membership::role,
            schema::users::username,
        ))
        .load(conn)
        .map_err(|e| {
            tracing::error!("list members: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to list members")
        })?;

    let members: Vec<MemberResponse> = rows
        .into_iter()
        .map(|(uid, role, username)| MemberResponse {
            uid,
            role,
            username: Some(username),
        })
        .collect();

    Ok(Json(members))
}

/// POST /a/group/:chat_id/members — Add a member to the chat (caller must be admin).
pub async fn post_add_member(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(ChatIdPath { chat_id }): Path<ChatIdPath>,
    Json(body): Json<AddMemberBody>,
) -> Result<StatusCode, (StatusCode, &'static str)> {
    let conn = &mut state
        .db
        .get()
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Database connection failed"))?;

    let group_exists = schema::groups::table
        .find(chat_id)
        .count()
        .get_result::<i64>(conn)
        .map_err(|e| {
            tracing::error!("check group exists: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;
    if group_exists == 0 {
        return Err((StatusCode::NOT_FOUND, "Chat not found"));
    }

    let user_exists = schema::users::table
        .find(body.uid)
        .count()
        .get_result::<i64>(conn)
        .map_err(|e| {
            tracing::error!("check user exists: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;
    if user_exists == 0 {
        return Err((StatusCode::NOT_FOUND, "User not found"));
    }

    use crate::schema::group_membership::dsl;
    let already_member = schema::group_membership::table
        .filter(dsl::chat_id.eq(chat_id).and(dsl::uid.eq(body.uid)))
        .count()
        .get_result::<i64>(conn)
        .map_err(|e| {
            tracing::error!("check existing member: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;
    if already_member > 0 {
        return Err((StatusCode::CONFLICT, "User is already a member of this chat"));
    }

    let now = Utc::now();
    diesel::insert_into(schema::group_membership::table)
        .values(&NewGroupMembership {
            chat_id,
            uid: body.uid,
            role: "member".to_string(),
            joined_at: now,
        })
        .execute(conn)
        .map_err(|e| {
            tracing::error!("insert membership: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to add member")
        })?;

    Ok(StatusCode::CREATED)
}

/// DELETE /a/group/:chat_id/members/:uid — Remove a member from the chat (caller must be admin).
pub async fn delete_remove_member(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(MemberIdPath { chat_id, uid: target_uid }): Path<MemberIdPath>,
) -> Result<StatusCode, (StatusCode, &'static str)> {
    let conn = &mut state
        .db
        .get()
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Database connection failed"))?;

    check_admin(conn, chat_id, uid)?;

    use crate::schema::group_membership::dsl;
    let deleted = diesel::delete(
        schema::group_membership::table.filter(dsl::chat_id.eq(chat_id).and(dsl::uid.eq(target_uid))),
    )
    .execute(conn)
    .map_err(|e| {
        tracing::error!("delete membership: {:?}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, "Failed to remove member")
    })?;

    if deleted == 0 {
        return Err((StatusCode::NOT_FOUND, "Member not found in this chat"));
    }

    Ok(StatusCode::NO_CONTENT)
}
