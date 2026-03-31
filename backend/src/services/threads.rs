use chrono::{DateTime, Utc};
use diesel::prelude::*;
use diesel::sql_query;
use diesel::PgConnection;
use tracing::warn;

use crate::schema::thread_subscriptions;

const MAX_UNREAD_COUNT: i64 = 100;

/// Insert a subscription if one doesn't exist (auto-subscribe on participation).
pub fn ensure_thread_subscription(
    conn: &mut PgConnection,
    chat_id: i64,
    thread_root_id: i64,
    uid: i32,
) -> Result<(), diesel::result::Error> {
    diesel::insert_into(thread_subscriptions::table)
        .values((
            thread_subscriptions::chat_id.eq(chat_id),
            thread_subscriptions::thread_root_id.eq(thread_root_id),
            thread_subscriptions::uid.eq(uid),
            thread_subscriptions::subscribed_at.eq(Utc::now()),
        ))
        .on_conflict_do_nothing()
        .execute(conn)?;
    Ok(())
}

/// Explicit subscribe (for "Follow thread" button). Same upsert.
pub fn subscribe_to_thread(
    conn: &mut PgConnection,
    chat_id: i64,
    thread_root_id: i64,
    uid: i32,
) -> Result<(), diesel::result::Error> {
    ensure_thread_subscription(conn, chat_id, thread_root_id, uid)
}

/// Explicit unsubscribe (for "Unfollow thread" button).
pub fn unsubscribe_from_thread(
    conn: &mut PgConnection,
    chat_id: i64,
    thread_root_id: i64,
    uid: i32,
) -> Result<bool, diesel::result::Error> {
    let deleted = diesel::delete(
        thread_subscriptions::table.filter(
            thread_subscriptions::chat_id
                .eq(chat_id)
                .and(thread_subscriptions::thread_root_id.eq(thread_root_id))
                .and(thread_subscriptions::uid.eq(uid)),
        ),
    )
    .execute(conn)?;
    Ok(deleted > 0)
}

/// Check if a user is subscribed to a thread.
pub fn is_subscribed(
    conn: &mut PgConnection,
    chat_id: i64,
    thread_root_id: i64,
    uid: i32,
) -> Result<bool, diesel::result::Error> {
    diesel::select(diesel::dsl::exists(
        thread_subscriptions::table.filter(
            thread_subscriptions::chat_id
                .eq(chat_id)
                .and(thread_subscriptions::thread_root_id.eq(thread_root_id))
                .and(thread_subscriptions::uid.eq(uid)),
        ),
    ))
    .get_result(conn)
}

/// Update `last_read_message_id` for an existing subscription only.
pub fn mark_thread_as_read(
    conn: &mut PgConnection,
    thread_root_id: i64,
    uid: i32,
    message_id: i64,
) -> Result<bool, diesel::result::Error> {
    let updated = diesel::update(
        thread_subscriptions::table.filter(
            thread_subscriptions::thread_root_id
                .eq(thread_root_id)
                .and(thread_subscriptions::uid.eq(uid)),
        ),
    )
    .set(thread_subscriptions::last_read_message_id.eq(Some(message_id)))
    .execute(conn)?;
    Ok(updated > 0)
}

/// Get all UIDs subscribed to a given thread.
pub fn get_thread_subscriber_uids(
    conn: &mut PgConnection,
    chat_id: i64,
    thread_root_id: i64,
) -> Result<Vec<i32>, diesel::result::Error> {
    thread_subscriptions::table
        .filter(
            thread_subscriptions::chat_id
                .eq(chat_id)
                .and(thread_subscriptions::thread_root_id.eq(thread_root_id)),
        )
        .select(thread_subscriptions::uid)
        .load(conn)
}

#[derive(QueryableByName)]
pub struct ThreadListRow {
    #[diesel(sql_type = diesel::sql_types::BigInt)]
    pub chat_id: i64,
    #[diesel(sql_type = diesel::sql_types::BigInt)]
    pub thread_root_id: i64,
    #[diesel(sql_type = diesel::sql_types::Text)]
    pub chat_name: String,
    #[diesel(sql_type = diesel::sql_types::Nullable<diesel::sql_types::Text>)]
    pub chat_avatar_key: Option<String>,
    #[diesel(sql_type = diesel::sql_types::BigInt)]
    pub reply_count: i64,
    #[diesel(sql_type = diesel::sql_types::Timestamptz)]
    pub last_reply_at: DateTime<Utc>,
    #[diesel(sql_type = diesel::sql_types::BigInt)]
    pub unread_count: i64,
    #[diesel(sql_type = diesel::sql_types::Timestamptz)]
    pub subscribed_at: DateTime<Utc>,
}

/// List threads the user is subscribed to, ordered by most recent reply.
pub fn get_user_threads(
    conn: &mut PgConnection,
    uid: i32,
    limit: i64,
    before_cursor: Option<DateTime<Utc>>,
) -> Result<Vec<ThreadListRow>, diesel::result::Error> {
    let query = sql_query(
        "SELECT
            ts.chat_id,
            ts.thread_root_id,
            g.name AS chat_name,
            avatar_media.storage_key AS chat_avatar_key,
            COALESCE(thread_stats.reply_count, 0)::bigint AS reply_count,
            COALESCE(thread_stats.last_reply_at, ts.subscribed_at) AS last_reply_at,
            LEAST(
                COALESCE(thread_stats.unread_count, 0),
                $4
            )::bigint AS unread_count,
            ts.subscribed_at
        FROM thread_subscriptions ts
        JOIN groups g ON g.id = ts.chat_id
        LEFT JOIN media avatar_media ON g.avatar_image_id = avatar_media.id AND avatar_media.deleted_at IS NULL
        JOIN messages root_msg ON root_msg.id = ts.thread_root_id
        LEFT JOIN LATERAL (
            SELECT
                COUNT(*)::bigint AS reply_count,
                MAX(m.created_at) AS last_reply_at,
                COUNT(*) FILTER (
                    WHERE m.id > COALESCE(ts.last_read_message_id, 0)
                )::bigint AS unread_count
            FROM messages m
            WHERE m.reply_root_id = ts.thread_root_id
              AND m.deleted_at IS NULL
        ) thread_stats ON TRUE
        WHERE ts.uid = $1
          AND root_msg.deleted_at IS NULL
          AND ($2::timestamptz IS NULL OR COALESCE(thread_stats.last_reply_at, ts.subscribed_at) < $2)
        ORDER BY COALESCE(thread_stats.last_reply_at, ts.subscribed_at) DESC
        LIMIT $3",
    )
    .bind::<diesel::sql_types::Integer, _>(uid)
    .bind::<diesel::sql_types::Nullable<diesel::sql_types::Timestamptz>, _>(before_cursor)
    .bind::<diesel::sql_types::BigInt, _>(limit)
    .bind::<diesel::sql_types::BigInt, _>(MAX_UNREAD_COUNT);

    match query.load::<ThreadListRow>(conn) {
        Ok(rows) => Ok(rows),
        Err(e) => {
            warn!("Failed to load user threads: {:?}", e);
            Err(e)
        }
    }
}

#[derive(QueryableByName)]
struct UnreadThreadCountRow {
    #[diesel(sql_type = diesel::sql_types::BigInt)]
    unread_thread_count: i64,
}

/// Count of subscribed threads that have at least one unread reply.
pub fn get_total_unread_thread_count(
    conn: &mut PgConnection,
    uid: i32,
) -> Result<i64, diesel::result::Error> {
    let query = sql_query(
        "SELECT COUNT(*)::bigint AS unread_thread_count
         FROM thread_subscriptions ts
         JOIN messages root_msg ON root_msg.id = ts.thread_root_id
         WHERE ts.uid = $1
           AND root_msg.deleted_at IS NULL
           AND EXISTS (
               SELECT 1 FROM messages m
               WHERE m.reply_root_id = ts.thread_root_id
                 AND m.deleted_at IS NULL
                 AND m.id > COALESCE(ts.last_read_message_id, 0)
           )",
    )
    .bind::<diesel::sql_types::Integer, _>(uid);

    query
        .get_result::<UnreadThreadCountRow>(conn)
        .map(|row| row.unread_thread_count)
}
