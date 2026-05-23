use std::sync::{Arc, Mutex, MutexGuard};

use dashmap::DashMap;
use diesel::prelude::*;
use diesel::result::Error as DieselError;
use diesel::sql_query;
use diesel::PgConnection;

use super::chat_index::{ChatUnreadIndex, ChatUnreadMessageSnapshot};
use crate::services::chat::MAX_UNREAD_COUNT;

#[derive(Default)]
pub struct UnreadService {
    chats: DashMap<i64, Arc<Mutex<ChatUnreadCacheEntry>>>,
}

#[derive(Debug, Default)]
struct ChatUnreadCacheEntry {
    index: Option<ChatUnreadIndex>,
}

#[derive(diesel::QueryableByName)]
struct ChatUnreadSnapshotRow {
    #[diesel(sql_type = diesel::sql_types::BigInt)]
    id: i64,
    #[diesel(sql_type = diesel::sql_types::Bool)]
    countable: bool,
}

impl UnreadService {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn count_chat_unread(
        &self,
        conn: &mut PgConnection,
        chat_id: i64,
        last_read_message_id: Option<i64>,
    ) -> Result<i64, DieselError> {
        self.count_chat_unread_with_loader(chat_id, last_read_message_id, || {
            Self::load_chat_unread_snapshot(conn, chat_id)
        })
    }

    pub fn observe_top_level_message(&self, chat_id: i64, message_id: i64, countable: bool) {
        self.update_loaded_chat(chat_id, |index| {
            index.observe_message(message_id, countable)
        });
    }

    pub fn observe_top_level_message_countability(
        &self,
        chat_id: i64,
        message_id: i64,
        countable: bool,
    ) {
        self.update_loaded_chat(chat_id, |index| {
            index.set_countability(message_id, countable)
        });
    }

    pub fn invalidate_chat(&self, chat_id: i64) {
        if let Some(entry) = self.loaded_entry(chat_id) {
            Self::lock_entry(&entry).index = None;
        }
    }

    fn count_chat_unread_with_loader<E>(
        &self,
        chat_id: i64,
        last_read_message_id: Option<i64>,
        load: impl FnOnce() -> Result<Vec<ChatUnreadMessageSnapshot>, E>,
    ) -> Result<i64, E> {
        let entry = self.entry(chat_id);
        let mut guard = Self::lock_entry(&entry);

        if guard.index.is_none() {
            guard.index = Some(ChatUnreadIndex::from_snapshot(load()?));
        }

        Ok(guard
            .index
            .as_ref()
            .map(|index| {
                index
                    .count_after(last_read_message_id)
                    .min(MAX_UNREAD_COUNT)
            })
            .unwrap_or(0))
    }

    fn update_loaded_chat(&self, chat_id: i64, update: impl FnOnce(&mut ChatUnreadIndex) -> bool) {
        if let Some(entry) = self.loaded_entry(chat_id) {
            let mut guard = Self::lock_entry(&entry);
            if let Some(index) = guard.index.as_mut() {
                if !update(index) {
                    guard.index = None;
                }
            }
        }
    }

    fn entry(&self, chat_id: i64) -> Arc<Mutex<ChatUnreadCacheEntry>> {
        self.chats
            .entry(chat_id)
            .or_insert_with(|| Arc::new(Mutex::new(ChatUnreadCacheEntry::default())))
            .clone()
    }

    fn loaded_entry(&self, chat_id: i64) -> Option<Arc<Mutex<ChatUnreadCacheEntry>>> {
        self.chats.get(&chat_id).map(|entry| entry.clone())
    }

    fn lock_entry(
        entry: &Arc<Mutex<ChatUnreadCacheEntry>>,
    ) -> MutexGuard<'_, ChatUnreadCacheEntry> {
        entry
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
    }

    fn load_chat_unread_snapshot(
        conn: &mut PgConnection,
        chat_id: i64,
    ) -> Result<Vec<ChatUnreadMessageSnapshot>, DieselError> {
        let rows = sql_query(
            "SELECT id,
                    (deleted_at IS NULL AND is_published = TRUE) AS countable
             FROM messages
             WHERE chat_id = $1
               AND reply_root_id IS NULL
             ORDER BY id ASC",
        )
        .bind::<diesel::sql_types::BigInt, _>(chat_id)
        .load::<ChatUnreadSnapshotRow>(conn)?;

        Ok(rows
            .into_iter()
            .map(|row| ChatUnreadMessageSnapshot {
                id: row.id,
                countable: row.countable,
            })
            .collect())
    }
}

#[cfg(test)]
mod tests {
    use std::cell::Cell;

    use super::{ChatUnreadMessageSnapshot, UnreadService};
    use crate::services::chat::MAX_UNREAD_COUNT;

    fn snapshot(id: i64, countable: bool) -> ChatUnreadMessageSnapshot {
        ChatUnreadMessageSnapshot { id, countable }
    }

    #[test]
    fn loads_chat_once_and_reuses_index_for_later_reads() {
        let service = UnreadService::new();
        let loads = Cell::new(0);

        let first: Result<i64, ()> = service.count_chat_unread_with_loader(1, Some(10), || {
            loads.set(loads.get() + 1);
            Ok(vec![
                snapshot(10, true),
                snapshot(20, true),
                snapshot(30, true),
            ])
        });
        assert_eq!(first.unwrap(), 2);

        let second: Result<i64, ()> = service.count_chat_unread_with_loader(1, Some(20), || {
            loads.set(loads.get() + 1);
            Ok(vec![])
        });
        assert_eq!(second.unwrap(), 1);
        assert_eq!(loads.get(), 1);
    }

    #[test]
    fn caps_single_chat_counts_at_public_unread_limit() {
        let service = UnreadService::new();
        let messages = (1..=(MAX_UNREAD_COUNT + 10))
            .map(|id| snapshot(id, true))
            .collect::<Vec<_>>();

        let count: Result<i64, ()> =
            service.count_chat_unread_with_loader(1, Some(0), || Ok(messages));

        assert_eq!(count.unwrap(), MAX_UNREAD_COUNT);
    }

    #[test]
    fn applies_append_and_countability_mutations_to_loaded_chat() {
        let service = UnreadService::new();

        let count: Result<i64, ()> = service.count_chat_unread_with_loader(1, None, || {
            Ok(vec![snapshot(10, true), snapshot(20, false)])
        });
        assert_eq!(count.unwrap(), 1);

        service.observe_top_level_message(1, 30, true);
        service.observe_top_level_message_countability(1, 20, true);
        service.observe_top_level_message_countability(1, 10, false);

        let count: Result<i64, ()> = service.count_chat_unread_with_loader(1, None, || Ok(vec![]));
        assert_eq!(count.unwrap(), 2);
    }

    #[test]
    fn invalidates_loaded_chat_when_mutation_cannot_be_applied() {
        let service = UnreadService::new();
        let loads = Cell::new(0);

        let count: Result<i64, ()> = service.count_chat_unread_with_loader(1, None, || {
            loads.set(loads.get() + 1);
            Ok(vec![snapshot(10, true), snapshot(30, true)])
        });
        assert_eq!(count.unwrap(), 2);

        service.observe_top_level_message(1, 20, true);

        let count: Result<i64, ()> = service.count_chat_unread_with_loader(1, None, || {
            loads.set(loads.get() + 1);
            Ok(vec![
                snapshot(10, true),
                snapshot(20, true),
                snapshot(30, true),
            ])
        });
        assert_eq!(count.unwrap(), 3);
        assert_eq!(loads.get(), 2);
    }
}
