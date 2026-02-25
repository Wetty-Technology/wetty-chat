use axum::{
    extract::{Query, State},
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use chrono::{DateTime, Utc};
use diesel::prelude::*;
use diesel::sql_query;
use diesel::sql_types::{BigInt, Nullable, Timestamptz};
use serde::Serialize;

use crate::models::{NewGroup, NewGroupMembership};
use crate::schema::{group_membership, groups};
use crate::utils::auth::CurrentUid;
use crate::utils::ids;
use crate::{AppState, MAX_CHATS_LIMIT};

/// Row type for GET /chats raw query (gid, name, created_at, last_message_at).
#[derive(diesel::QueryableByName)]
struct ChatListRow {
    #[diesel(sql_type = BigInt)]
    #[diesel(column_name = gid)]
    gid: i64,
    #[diesel(sql_type = diesel::sql_types::Nullable<diesel::sql_types::Varchar>)]
    #[diesel(column_name = name)]
    name: Option<String>,
    #[diesel(sql_type = Timestamptz)]
    #[diesel(column_name = created_at)]
    created_at: DateTime<Utc>,
    #[diesel(sql_type = diesel::sql_types::Nullable<Timestamptz>)]
    #[diesel(column_name = last_message_at)]
    last_message_at: Option<DateTime<Utc>>,
}

/// Row type for cursor lookup (last_message_at, gid).
#[derive(diesel::QueryableByName)]
struct CursorRow {
    #[diesel(sql_type = diesel::sql_types::Nullable<Timestamptz>)]
    #[diesel(column_name = last_message_at)]
    last_message_at: Option<DateTime<Utc>>,
    #[diesel(sql_type = BigInt)]
    #[diesel(column_name = gid)]
    gid: i64,
}

#[derive(serde::Deserialize)]
pub struct ListChatsQuery {
    #[serde(default)]
    limit: Option<i64>,
    after: Option<i64>,
}

#[derive(Serialize)]
pub struct ChatListItem {
    id: i64,
    name: Option<String>,
    last_message_at: Option<DateTime<Utc>>,
}

#[derive(Serialize)]
pub struct ListChatsResponse {
    chats: Vec<ChatListItem>,
    next_cursor: Option<i64>,
}

/// GET /chats — List chats for the current user (cursor-based).
pub async fn get_chats(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Query(q): Query<ListChatsQuery>,
) -> Result<Json<ListChatsResponse>, (StatusCode, &'static str)> {
    let limit = q
        .limit
        .map(|l| std::cmp::min(l, MAX_CHATS_LIMIT))
        .unwrap_or(MAX_CHATS_LIMIT)
        .max(1);

    let conn = &mut state
        .db
        .get()
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Database connection failed"))?;

    // Query chats the user is a member of, with last_message_at from messages.
    // Cursor: when `after` (gid) is set, we return chats that sort before that chat.
    let rows: Vec<ChatListRow> = match q.after {
        None => sql_query(
            r#"
            SELECT g.gid, g.name, g.created_at,
                   (SELECT max(m.created_at) FROM messages m WHERE m.gid = g.gid) AS last_message_at
            FROM groups g
            INNER JOIN group_membership gm ON gm.gid = g.gid AND gm.uid = $1
            ORDER BY last_message_at DESC NULLS LAST, g.gid DESC
            LIMIT $2
            "#,
        )
        .bind::<diesel::sql_types::Integer, _>(uid)
        .bind::<diesel::sql_types::BigInt, _>(limit + 1)
        .load(conn)
        .map_err(|e| {
            tracing::error!("list chats: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to list chats")
        })?,
        Some(after_gid) => {
            // Get cursor row's last_message_at so we can filter (last_message_at, gid) < (cursor_at, cursor_gid)
            let cursor: Option<CursorRow> = sql_query(
                r#"
                SELECT (SELECT max(m.created_at) FROM messages m WHERE m.gid = g.gid) AS last_message_at, g.gid
                FROM groups g
                INNER JOIN group_membership gm ON gm.gid = g.gid AND gm.uid = $1 AND g.gid = $2
                LIMIT 1
                "#,
            )
            .bind::<diesel::sql_types::Integer, _>(uid)
            .bind::<diesel::sql_types::BigInt, _>(after_gid)
            .load::<CursorRow>(conn)
            .map_err(|e| {
                tracing::error!("list chats cursor: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, "Failed to list chats")
            })?
            .into_iter()
            .next();

            let cursor_at = match &cursor {
                Some(c) => c.last_message_at,
                None => {
                    return Ok(Json(ListChatsResponse {
                        chats: vec![],
                        next_cursor: None,
                    }))
                }
            };
            let cursor_gid = cursor.unwrap().gid;

            sql_query(
                r#"
                WITH ordered AS (
                    SELECT g.gid, g.name, g.created_at,
                           (SELECT max(m.created_at) FROM messages m WHERE m.gid = g.gid) AS last_message_at
                    FROM groups g
                    INNER JOIN group_membership gm ON gm.gid = g.gid AND gm.uid = $1
                )
                SELECT * FROM ordered
                WHERE (COALESCE(last_message_at, '1970-01-01'::timestamptz), gid) < (COALESCE($2, '1970-01-01'::timestamptz), $3)
                ORDER BY last_message_at DESC NULLS LAST, gid DESC
                LIMIT $4
                "#,
            )
            .bind::<diesel::sql_types::Integer, _>(uid)
            .bind::<Nullable<Timestamptz>, _>(cursor_at)
            .bind::<BigInt, _>(cursor_gid)
            .bind::<BigInt, _>(limit + 1)
            .load(conn)
            .map_err(|e| {
                tracing::error!("list chats after: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, "Failed to list chats")
            })?
        }
    };

    let has_more = rows.len() as i64 > limit;
    let chats: Vec<ChatListItem> = rows
        .into_iter()
        .take(limit as usize)
        .map(|r| ChatListItem {
            id: r.gid,
            name: r.name,
            last_message_at: r.last_message_at,
        })
        .collect();
    let next_cursor = has_more.then(|| chats.last().map(|c| c.id)).flatten();

    Ok(Json(ListChatsResponse {
        chats,
        next_cursor,
    }))
}

#[derive(serde::Deserialize)]
pub struct CreateChatBody {
    name: Option<String>,
}

#[derive(Serialize)]
pub struct CreateChatResponse {
    id: i64,
    name: Option<String>,
    created_at: DateTime<Utc>,
}

/// POST /chats — Create a new chat.
pub async fn post_chats(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Json(body): Json<CreateChatBody>,
) -> Result<impl IntoResponse, (StatusCode, &'static str)> {
    let gid = ids::next_gid(state.id_gen.as_ref())
        .await
        .map_err(|e| {
            tracing::error!("ferroid next_gid: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "ID generation failed")
        })?;

    let now = Utc::now();
    let name = body.name.filter(|s| !s.trim().is_empty());

    let conn = &mut state
        .db
        .get()
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Database connection failed"))?;

    diesel::insert_into(groups::table)
        .values(&NewGroup {
            gid,
            name: name.clone(),
            created_at: now,
        })
        .execute(conn)
        .map_err(|e| {
            tracing::error!("insert group: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to create chat")
        })?;

    diesel::insert_into(group_membership::table)
        .values(&NewGroupMembership {
            gid,
            uid,
            role: "member".to_string(),
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
            id: gid,
            name,
            created_at: now,
        }),
    ))
}
