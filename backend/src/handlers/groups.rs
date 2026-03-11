use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use chrono::{DateTime, Utc};
use diesel::prelude::*;
use serde::Serialize;

use crate::models::{GroupRole, GroupVisibility, NewGroup, NewGroupMembership, UpdateGroup};
use crate::schema::{group_membership, groups};
use crate::utils::auth::CurrentUid;
use crate::utils::ids;
use crate::AppState;

#[derive(serde::Deserialize)]
pub(super) struct CreateChatBody {
    name: Option<String>,
}

#[derive(Serialize)]
pub(super) struct CreateChatResponse {
    #[serde(with = "crate::serde_i64_string")]
    id: i64,
    name: Option<String>,
    created_at: DateTime<Utc>,
}

/// POST /group — Create a new chat.
async fn post_group(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Json(body): Json<CreateChatBody>,
) -> Result<impl IntoResponse, (StatusCode, &'static str)> {
    let id = ids::next_gid(state.id_gen.as_ref()).await.map_err(|e| {
        tracing::error!("ferroid next_gid: {:?}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, "ID generation failed")
    })?;

    let now = Utc::now();
    let name = body
        .name
        .filter(|s| !s.trim().is_empty())
        .unwrap_or_else(|| String::new());

    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    diesel::insert_into(groups::table)
        .values(&NewGroup {
            id,
            name: name.clone(),
            description: None,
            avatar: None,
            created_at: now,
            visibility: GroupVisibility::Public,
        })
        .execute(conn)
        .map_err(|e| {
            tracing::error!("insert group: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to create chat")
        })?;

    diesel::insert_into(group_membership::table)
        .values(&NewGroupMembership {
            chat_id: id,
            uid,
            role: GroupRole::Admin,
            joined_at: now,
        })
        .execute(conn)
        .map_err(|e| {
            tracing::error!("insert membership: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to create chat")
        })?;

    Ok((
        StatusCode::CREATED,
        Json(CreateChatResponse {
            id,
            name: if name.is_empty() { None } else { Some(name) },
            created_at: now,
        }),
    ))
}

#[derive(serde::Deserialize)]
pub(super) struct ChatIdPath {
    pub(super) chat_id: i64,
}

#[derive(Serialize)]
pub(super) struct ChatDetailResponse {
    #[serde(with = "crate::serde_i64_string")]
    id: i64,
    name: String,
    description: Option<String>,
    avatar: Option<String>,
    visibility: GroupVisibility,
    created_at: DateTime<Utc>,
}

/// GET /group/:chat_id — Get chat details.
async fn get_group(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(ChatIdPath { chat_id }): Path<ChatIdPath>,
) -> Result<Json<ChatDetailResponse>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    // Check membership
    use crate::schema::group_membership::dsl as gm_dsl;
    let is_member = group_membership::table
        .filter(gm_dsl::chat_id.eq(chat_id).and(gm_dsl::uid.eq(uid)))
        .count()
        .get_result::<i64>(conn)
        .map_err(|e| {
            tracing::error!("check membership: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;

    if is_member == 0 {
        return Err((StatusCode::FORBIDDEN, "Not a member of this chat"));
    }

    // Get group details
    use crate::schema::groups::dsl as groups_dsl;
    let group: crate::models::Group = groups::table
        .filter(groups_dsl::id.eq(chat_id))
        .first(conn)
        .map_err(|_| (StatusCode::NOT_FOUND, "Chat not found"))?;

    Ok(Json(ChatDetailResponse {
        id: group.id,
        name: group.name,
        description: group.description,
        avatar: group.avatar,
        visibility: group.visibility,
        created_at: group.created_at,
    }))
}

#[derive(serde::Deserialize)]
pub(super) struct UpdateChatBody {
    name: Option<String>,
    description: Option<String>,
    avatar: Option<String>,
    visibility: Option<GroupVisibility>,
}

/// PATCH /group/:chat_id — Update chat metadata (admin only).
async fn patch_group(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(ChatIdPath { chat_id }): Path<ChatIdPath>,
    Json(body): Json<UpdateChatBody>,
) -> Result<Json<ChatDetailResponse>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    // Check if user is admin
    use crate::schema::group_membership::dsl as gm_dsl;
    let role: Option<GroupRole> = group_membership::table
        .filter(gm_dsl::chat_id.eq(chat_id).and(gm_dsl::uid.eq(uid)))
        .select(gm_dsl::role)
        .first(conn)
        .optional()
        .map_err(|e| {
            tracing::error!("check admin role: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;

    match role {
        Some(r) if r == GroupRole::Admin => {}
        Some(_) => return Err((StatusCode::FORBIDDEN, "Admin role required")),
        None => return Err((StatusCode::FORBIDDEN, "Not a member of this chat")),
    }

    // Update group in a single query
    use crate::schema::groups::dsl as groups_dsl;

    let changeset = UpdateGroup {
        name: body.name,
        description: body.description,
        avatar: body.avatar,
        visibility: body.visibility,
    };

    let group: crate::models::Group =
        diesel::update(groups::table.filter(groups_dsl::id.eq(chat_id)))
            .set(&changeset)
            .returning(crate::models::Group::as_returning())
            .get_result(conn)
            .map_err(|e| {
                tracing::error!("update group: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, "Failed to update chat")
            })?;

    Ok(Json(ChatDetailResponse {
        id: group.id,
        name: group.name,
        description: group.description,
        avatar: group.avatar,
        visibility: group.visibility,
        created_at: group.created_at,
    }))
}

pub fn router() -> axum::Router<crate::AppState> {
    axum::Router::new()
        .route("/", axum::routing::post(post_group))
        .route("/{chat_id}", axum::routing::get(get_group).patch(patch_group))
        .nest("/{chat_id}/members", crate::handlers::members::router())
}
