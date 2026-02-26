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

/// Row type for GET /chats raw query (id, name, created_at, last_message_at).
#[derive(diesel::QueryableByName)]
struct ChatListRow {
    #[diesel(sql_type = BigInt)]
    #[diesel(column_name = id)]
    id: i64,
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

/// Row type for cursor lookup (last_message_at, id).
#[derive(diesel::QueryableByName)]
struct CursorRow {
    #[diesel(sql_type = diesel::sql_types::Nullable<Timestamptz>)]
    #[diesel(column_name = last_message_at)]
    last_message_at: Option<DateTime<Utc>>,
    #[diesel(sql_type = BigInt)]
    #[diesel(column_name = id)]
    id: i64,
}

#[derive(serde::Deserialize)]
pub struct ListChatsQuery {
    #[serde(default)]
    limit: Option<i64>,
    #[serde(default, deserialize_with = "crate::serde_i64_string::opt::deserialize")]
    after: Option<i64>,
}

#[derive(Serialize)]
pub struct ChatListItem {
    #[serde(with = "crate::serde_i64_string")]
    id: i64,
    name: Option<String>,
    last_message_at: Option<DateTime<Utc>>,
}

#[derive(Serialize)]
pub struct ListChatsResponse {
    chats: Vec<ChatListItem>,
    #[serde(with = "crate::serde_i64_string::opt")]
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
    // Cursor: when `after` (chat id) is set, we return chats that sort before that chat.
    let rows: Vec<ChatListRow> = match q.after {
        None => sql_query(
            r#"
            SELECT g.id, g.name, g.created_at,
                   (SELECT max(m.created_at) FROM messages m WHERE m.chat_id = g.id) AS last_message_at
            FROM groups g
            INNER JOIN group_membership gm ON gm.chat_id = g.id AND gm.uid = $1
            ORDER BY last_message_at DESC NULLS LAST, g.id DESC
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
        Some(after_id) => {
            // Get cursor row's last_message_at so we can filter (last_message_at, id) < (cursor_at, cursor_id)
            let cursor: Option<CursorRow> = sql_query(
                r#"
                SELECT (SELECT max(m.created_at) FROM messages m WHERE m.chat_id = g.id) AS last_message_at, g.id
                FROM groups g
                INNER JOIN group_membership gm ON gm.chat_id = g.id AND gm.uid = $1 AND g.id = $2
                LIMIT 1
                "#,
            )
            .bind::<diesel::sql_types::Integer, _>(uid)
            .bind::<diesel::sql_types::BigInt, _>(after_id)
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
            let cursor_id = cursor.unwrap().id;

            sql_query(
                r#"
                WITH ordered AS (
                    SELECT g.id, g.name, g.created_at,
                           (SELECT max(m.created_at) FROM messages m WHERE m.chat_id = g.id) AS last_message_at
                    FROM groups g
                    INNER JOIN group_membership gm ON gm.chat_id = g.id AND gm.uid = $1
                )
                SELECT * FROM ordered
                WHERE (COALESCE(last_message_at, '1970-01-01'::timestamptz), id) < (COALESCE($2, '1970-01-01'::timestamptz), $3)
                ORDER BY last_message_at DESC NULLS LAST, id DESC
                LIMIT $4
                "#,
            )
            .bind::<diesel::sql_types::Integer, _>(uid)
            .bind::<Nullable<Timestamptz>, _>(cursor_at)
            .bind::<BigInt, _>(cursor_id)
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
            id: r.id,
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
    #[serde(with = "crate::serde_i64_string")]
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
    let id = ids::next_gid(state.id_gen.as_ref())
        .await
        .map_err(|e| {
            tracing::error!("ferroid next_gid: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "ID generation failed")
        })?;

    let now = Utc::now();
    let name = body
        .name
        .filter(|s| !s.trim().is_empty())
        .unwrap_or_else(|| String::new());

    let conn = &mut state
        .db
        .get()
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Database connection failed"))?;

    diesel::insert_into(groups::table)
        .values(&NewGroup {
            id,
            name: name.clone(),
            description: None,
            avatar: None,
            created_at: now,
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
            id,
            name: if name.is_empty() { None } else { Some(name) },
            created_at: now,
        }),
    ))
}
