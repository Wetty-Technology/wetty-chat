use diesel::prelude::*;
use diesel::sql_query;
use diesel::PgConnection;
use std::collections::HashMap;
use tracing::warn;

#[derive(QueryableByName)]
struct UnreadCountRow {
    #[diesel(sql_type = diesel::sql_types::Integer)]
    uid: i32,
    #[diesel(sql_type = diesel::sql_types::BigInt)]
    unread_count: i64,
}

/// Calculate the global unread count for a given list of user IDs.
pub fn get_unread_counts(
    conn: &mut PgConnection,
    target_uids: &[i32],
) -> Result<HashMap<i32, i64>, diesel::result::Error> {
    if target_uids.is_empty() {
        return Ok(HashMap::new());
    }

    let query = sql_query(
        "SELECT gm.uid, COALESCE(SUM(chat_counts.unread_count), 0) AS unread_count
         FROM group_membership AS gm
         LEFT JOIN LATERAL (
             SELECT count(*)::bigint AS unread_count
             FROM messages AS m
             WHERE m.chat_id = gm.chat_id
               AND m.id > COALESCE(gm.last_read_message_id, 0)
               AND m.deleted_at IS NULL
               AND m.reply_root_id IS NULL
         ) AS chat_counts ON TRUE
         WHERE gm.uid = ANY($1)
         GROUP BY gm.uid",
    )
    .bind::<diesel::sql_types::Array<diesel::sql_types::Integer>, _>(target_uids.to_vec());

    match query.load::<UnreadCountRow>(conn) {
        Ok(rows) => Ok(rows
            .into_iter()
            .map(|row| (row.uid, row.unread_count))
            .collect()),
        Err(e) => {
            warn!("Failed to load unread counts: {:?}", e);
            Err(e)
        }
    }
}
