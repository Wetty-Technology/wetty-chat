use diesel::prelude::*;
use diesel::sql_types::{BigInt, Integer};
use diesel::PgConnection;
use std::collections::HashMap;
use tracing::warn;

#[derive(QueryableByName)]
struct UnreadCountRow {
    #[diesel(sql_type = Integer)]
    uid: i32,
    #[diesel(sql_type = BigInt)]
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

    let query = diesel::sql_query(
        "SELECT gm.uid, count(m.id) as unread_count \
         FROM group_membership gm \
         INNER JOIN messages m ON gm.chat_id = m.chat_id \
         WHERE gm.uid = ANY($1) AND m.id > COALESCE(gm.last_read_message_id, 0) AND m.deleted_at IS NULL \
         GROUP BY gm.uid"
    ).bind::<diesel::sql_types::Array<diesel::sql_types::Integer>, _>(target_uids);

    match query.load::<UnreadCountRow>(conn) {
        Ok(rows) => Ok(rows.into_iter().map(|r| (r.uid, r.unread_count)).collect()),
        Err(e) => {
            warn!("Failed to load unread counts: {:?}", e);
            Err(e)
        }
    }
}
