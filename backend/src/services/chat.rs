use diesel::prelude::*;
use diesel::sql_query;
use diesel::PgConnection;
use std::collections::HashMap;
use tracing::warn;

pub const MAX_UNREAD_COUNT: i64 = 100;
const UNREAD_COUNT_CHUNK_SIZE: usize = 50;

#[derive(QueryableByName)]
struct UnreadCountRow {
    #[diesel(sql_type = diesel::sql_types::Integer)]
    uid: i32,
    #[diesel(sql_type = diesel::sql_types::BigInt)]
    unread_count: i64,
}

#[derive(QueryableByName)]
struct ChatUnreadCountRow {
    #[diesel(sql_type = diesel::sql_types::BigInt)]
    unread_count: i64,
}

/// Calculate capped global unread counts for badge-style displays.
/// UIDs are processed in chunks to keep individual query times bounded.
pub fn get_unread_counts(
    conn: &mut PgConnection,
    target_uids: &[i32],
) -> Result<HashMap<i32, i64>, diesel::result::Error> {
    if target_uids.is_empty() {
        return Ok(HashMap::new());
    }

    let mut result = HashMap::with_capacity(target_uids.len());

    for chunk in target_uids.chunks(UNREAD_COUNT_CHUNK_SIZE) {
        let rows = get_unread_counts_batch(conn, chunk)?;
        for row in rows {
            result.insert(row.uid, row.unread_count.min(MAX_UNREAD_COUNT));
        }
    }

    Ok(result)
}

fn get_unread_counts_batch(
    conn: &mut PgConnection,
    uids: &[i32],
) -> Result<Vec<UnreadCountRow>, diesel::result::Error> {
    let query = sql_query(
        "WITH input_uids AS (
             SELECT DISTINCT uid
             FROM UNNEST($1::int[]) AS input(uid)
         )
         SELECT input_uids.uid, COUNT(unread_messages.marker)::bigint AS unread_count
         FROM input_uids
         LEFT JOIN LATERAL (
             SELECT 1 AS marker
             FROM group_membership AS gm
             JOIN messages AS m
               ON m.chat_id = gm.chat_id
             WHERE gm.uid = input_uids.uid
               AND m.id > COALESCE(gm.last_read_message_id, 0)
               AND m.deleted_at IS NULL
               AND m.reply_root_id IS NULL
               AND (gm.muted_until IS NULL OR gm.muted_until <= NOW())
             LIMIT 100
         ) AS unread_messages ON TRUE
         GROUP BY input_uids.uid",
    )
    .bind::<diesel::sql_types::Array<diesel::sql_types::Integer>, _>(uids.to_vec());

    match query.load::<UnreadCountRow>(conn) {
        Ok(rows) => Ok(rows),
        Err(e) => {
            warn!("Failed to load unread counts: {:?}", e);
            Err(e)
        }
    }
}

pub fn get_chat_unread_count(
    conn: &mut PgConnection,
    chat_id: i64,
    last_read_message_id: Option<i64>,
) -> Result<i64, diesel::result::Error> {
    let query = sql_query(
        "SELECT COUNT(unread_messages.marker)::bigint AS unread_count
         FROM (
             SELECT 1 AS marker
             FROM messages
             WHERE chat_id = $1
               AND reply_root_id IS NULL
               AND deleted_at IS NULL
               AND id > COALESCE($2, 0)
             LIMIT 100
         ) AS unread_messages",
    )
    .bind::<diesel::sql_types::BigInt, _>(chat_id)
    .bind::<diesel::sql_types::Nullable<diesel::sql_types::BigInt>, _>(last_read_message_id);

    query
        .get_result::<ChatUnreadCountRow>(conn)
        .map(|row| row.unread_count.min(MAX_UNREAD_COUNT))
}
