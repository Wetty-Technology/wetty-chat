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

/// Check if user is an admin of the chat; return 403 if not.
fn check_admin_role(
    conn: &mut diesel::r2d2::PooledConnection<diesel::r2d2::ConnectionManager<diesel::PgConnection>>,
    chat_id: i64,
    uid: i32,
) -> Result<(), (StatusCode, &'static str)> {
    use crate::schema::group_membership::dsl;
    let role: Option<String> = group_membership::table
        .filter(dsl::chat_id.eq(chat_id).and(dsl::uid.eq(uid)))
        .select(dsl::role)
        .first(conn)
        .optional()
        .map_err(|e| {
            tracing::error!("check admin role: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;

    match role {
        Some(r) if r == "admin" => Ok(()),
        Some(_) => Err((StatusCode::FORBIDDEN, "Admin role required")),
        None => Err((StatusCode::FORBIDDEN, "Not a member of this chat")),
    }
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

#[derive(serde::Deserialize)]
pub struct AddMemberBody {
    uid: i32,
    #[serde(default)]
    role: Option<String>,
}

/// POST /chats/:chat_id/members — Add a member to the chat (admin only).
pub async fn post_member(
    CurrentUid(requester_uid): CurrentUid,
    State(state): State<AppState>,
    Path(ChatIdPath { chat_id }): Path<ChatIdPath>,
    Json(body): Json<AddMemberBody>,
) -> Result<(StatusCode, Json<MemberResponse>), (StatusCode, &'static str)> {
    let conn = &mut state
        .db
        .get()
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Database connection failed"))?;

    // Check if requester is admin
    check_admin_role(conn, chat_id, requester_uid)?;

    // Check if target user exists
    use crate::schema::users::dsl as users_dsl;
    let user_exists = users::table
        .filter(users_dsl::uid.eq(body.uid))
        .count()
        .get_result::<i64>(conn)
        .map_err(|e| {
            tracing::error!("check user exists: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;

    if user_exists == 0 {
        return Err((StatusCode::NOT_FOUND, "User not found"));
    }

    // Check if already a member
    use crate::schema::group_membership::dsl as gm_dsl;
    let already_member = group_membership::table
        .filter(gm_dsl::chat_id.eq(chat_id).and(gm_dsl::uid.eq(body.uid)))
        .count()
        .get_result::<i64>(conn)
        .map_err(|e| {
            tracing::error!("check already member: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;

    if already_member > 0 {
        return Err((StatusCode::CONFLICT, "User is already a member"));
    }

    let role = body.role.unwrap_or_else(|| "member".to_string());
    if role != "admin" && role != "member" {
        return Err((StatusCode::BAD_REQUEST, "Invalid role"));
    }

    let now = chrono::Utc::now();
    let new_membership = crate::models::NewGroupMembership {
        chat_id,
        uid: body.uid,
        role: role.clone(),
        joined_at: now,
    };

    diesel::insert_into(group_membership::table)
        .values(&new_membership)
        .execute(conn)
        .map_err(|e| {
            tracing::error!("insert membership: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to add member")
        })?;

    // Get username
    let username: Option<String> = users::table
        .filter(users_dsl::uid.eq(body.uid))
        .select(users_dsl::username)
        .first(conn)
        .optional()
        .map_err(|e| {
            tracing::error!("get username: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;

    Ok((
        StatusCode::CREATED,
        Json(MemberResponse {
            uid: body.uid,
            role,
            joined_at: now,
            username,
        }),
    ))
}

#[derive(serde::Deserialize)]
pub struct MemberPath {
    chat_id: i64,
    uid: i32,
}

/// DELETE /chats/:chat_id/members/:uid — Remove a member (admin or self).
pub async fn delete_member(
    CurrentUid(requester_uid): CurrentUid,
    State(state): State<AppState>,
    Path(MemberPath { chat_id, uid: target_uid }): Path<MemberPath>,
) -> Result<StatusCode, (StatusCode, &'static str)> {
    let conn = &mut state
        .db
        .get()
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Database connection failed"))?;

    // Allow if requester is admin OR removing themselves
    if requester_uid != target_uid {
        check_admin_role(conn, chat_id, requester_uid)?;
    } else {
        check_membership(conn, chat_id, requester_uid)?;
    }

    // Check if target is a member
    use crate::schema::group_membership::dsl as gm_dsl;
    let is_member = group_membership::table
        .filter(gm_dsl::chat_id.eq(chat_id).and(gm_dsl::uid.eq(target_uid)))
        .count()
        .get_result::<i64>(conn)
        .map_err(|e| {
            tracing::error!("check member exists: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;

    if is_member == 0 {
        return Err((StatusCode::NOT_FOUND, "Member not found"));
    }

    diesel::delete(
        group_membership::table
            .filter(gm_dsl::chat_id.eq(chat_id).and(gm_dsl::uid.eq(target_uid))),
    )
    .execute(conn)
    .map_err(|e| {
        tracing::error!("delete membership: {:?}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, "Failed to remove member")
    })?;

    Ok(StatusCode::NO_CONTENT)
}

#[derive(serde::Deserialize)]
pub struct UpdateMemberBody {
    role: String,
}

/// PATCH /chats/:chat_id/members/:uid — Update member role (admin only).
pub async fn patch_member(
    CurrentUid(requester_uid): CurrentUid,
    State(state): State<AppState>,
    Path(MemberPath { chat_id, uid: target_uid }): Path<MemberPath>,
    Json(body): Json<UpdateMemberBody>,
) -> Result<Json<MemberResponse>, (StatusCode, &'static str)> {
    let conn = &mut state
        .db
        .get()
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Database connection failed"))?;

    // Check if requester is admin
    check_admin_role(conn, chat_id, requester_uid)?;

    // Validate role
    if body.role != "admin" && body.role != "member" {
        return Err((StatusCode::BAD_REQUEST, "Invalid role"));
    }

    // Check if target is a member
    use crate::schema::group_membership::dsl as gm_dsl;
    let is_member = group_membership::table
        .filter(gm_dsl::chat_id.eq(chat_id).and(gm_dsl::uid.eq(target_uid)))
        .count()
        .get_result::<i64>(conn)
        .map_err(|e| {
            tracing::error!("check member exists: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;

    if is_member == 0 {
        return Err((StatusCode::NOT_FOUND, "Member not found"));
    }

    // Update role
    diesel::update(
        group_membership::table
            .filter(gm_dsl::chat_id.eq(chat_id).and(gm_dsl::uid.eq(target_uid))),
    )
    .set(gm_dsl::role.eq(&body.role))
    .execute(conn)
    .map_err(|e| {
        tracing::error!("update member role: {:?}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, "Failed to update member role")
    })?;

    // Get updated member info
    let (role, joined_at, username): (String, DateTime<Utc>, String) = group_membership::table
        .filter(gm_dsl::chat_id.eq(chat_id).and(gm_dsl::uid.eq(target_uid)))
        .inner_join(users::table)
        .select((
            gm_dsl::role,
            gm_dsl::joined_at,
            users::username,
        ))
        .first(conn)
        .map_err(|e| {
            tracing::error!("get updated member: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to get updated member")
        })?;

    Ok(Json(MemberResponse {
        uid: target_uid,
        role,
        joined_at,
        username: Some(username),
    }))
}
