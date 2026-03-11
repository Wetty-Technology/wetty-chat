use axum::{
    extract::{Query, State},
    http::StatusCode,
    Json,
};
use chrono::{DateTime, Utc};
use diesel::prelude::*;
use serde::Serialize;

use crate::schema::{group_membership, groups, messages};
use crate::utils::auth::CurrentUid;
use crate::{AppState, MAX_CHATS_LIMIT};

// Queryable struct replaced by raw tuples

#[derive(serde::Deserialize)]
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
pub struct ChatListItem {
    #[serde(with = "crate::serde_i64_string")]
    id: i64,
    name: Option<String>,
    last_message_at: Option<DateTime<Utc>>,
    unread_count: i64,
    last_message: Option<crate::handlers::messages::MessageResponse>,
}

#[derive(Serialize)]
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
        "(SELECT count(*) FROM messages WHERE chat_id = groups.id AND id > COALESCE(group_membership.last_read_message_id, 0))"
    );

    let base_query = groups::table
        .inner_join(group_membership::table)
        .left_join(messages::table.on(groups::last_message_id.eq(messages::id.nullable())))
        .filter(group_membership::uid.eq(uid));

    type RowType = (
        i64,
        String,
        Option<DateTime<Utc>>,
        i64,
        Option<crate::models::Message>,
    );

    let rows: Vec<RowType> = match q.after {
        None => base_query
            .select((
                groups::id,
                groups::name,
                groups::last_message_at,
                unread_count_sq.clone(),
                messages::all_columns.nullable(),
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

            let default_time_str = "1970-01-01T00:00:00Z";
            let default_time = default_time_str.parse::<DateTime<Utc>>().unwrap();
            let c_at = cursor_at.unwrap_or(default_time);

            base_query
                .select((
                    groups::id,
                    groups::name,
                    groups::last_message_at,
                    unread_count_sq.clone(),
                    messages::all_columns.nullable(),
                ))
                .filter(
                    diesel::dsl::sql::<diesel::sql_types::Timestamptz>(
                        "COALESCE(groups.last_message_at, '1970-01-01'::timestamptz)",
                    )
                    .lt(c_at)
                    .or(diesel::dsl::sql::<diesel::sql_types::Timestamptz>(
                        "COALESCE(groups.last_message_at, '1970-01-01'::timestamptz)",
                    )
                    .eq(c_at)
                    .and(groups::id.lt(cursor_id))),
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
                })?
        }
    };

    let has_more = rows.len() as i64 > limit;
    let items_to_process: Vec<RowType> = rows.into_iter().take(limit as usize).collect();

    let messages_to_process: Vec<crate::models::Message> = items_to_process
        .iter()
        .filter_map(|(_, _, _, _, msg)| msg.clone())
        .collect();

    let message_responses =
        crate::handlers::messages::attach_replies(conn, messages_to_process, &state).await;

    let mut message_response_map: std::collections::HashMap<
        i64,
        crate::handlers::messages::MessageResponse,
    > = message_responses
        .into_iter()
        .map(|mr| (mr.id, mr))
        .collect();

    let chats: Vec<ChatListItem> = items_to_process
        .into_iter()
        .map(|(id, name, last_message_at, unread_count, msg)| {
            let mr = msg.and_then(|m| message_response_map.remove(&m.id));
            ChatListItem {
                id,
                name: Some(name),
                last_message_at,
                unread_count,
                last_message: mr,
            }
        })
        .collect();

    let next_cursor = has_more.then(|| chats.last().map(|c| c.id)).flatten();

    Ok(Json(ListChatsResponse { chats, next_cursor }))
}

pub fn router() -> axum::Router<crate::AppState> {
    axum::Router::new()
        .route("/", axum::routing::get(get_chats))
        .nest("/{chat_id}/messages", crate::handlers::messages::router())
}
