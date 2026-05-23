use super::fenwick::FenwickTree;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) struct ChatUnreadMessageSnapshot {
    pub(super) id: i64,
    pub(super) countable: bool,
}

#[derive(Debug, Clone)]
pub(super) struct ChatUnreadIndex {
    message_ids: Vec<i64>,
    countable: Vec<bool>,
    tree: FenwickTree,
}

impl ChatUnreadIndex {
    pub(super) fn from_snapshot(mut messages: Vec<ChatUnreadMessageSnapshot>) -> Self {
        messages.sort_by_key(|message| message.id);

        let message_ids = messages
            .iter()
            .map(|message| message.id)
            .collect::<Vec<_>>();
        let countable = messages
            .iter()
            .map(|message| message.countable)
            .collect::<Vec<_>>();
        let values = countable
            .iter()
            .map(|countable| i64::from(*countable))
            .collect::<Vec<_>>();

        Self {
            message_ids,
            countable,
            tree: FenwickTree::from_values(&values),
        }
    }

    pub(super) fn count_after(&self, last_read_message_id: Option<i64>) -> i64 {
        let read_len = last_read_message_id
            .map(|last_read| self.message_ids.partition_point(|id| *id <= last_read))
            .unwrap_or(0);

        self.tree.total() - self.tree.prefix_sum(read_len)
    }

    pub(super) fn observe_message(&mut self, message_id: i64, countable: bool) -> bool {
        match self.message_ids.binary_search(&message_id) {
            Ok(index) => {
                self.set_countability_at(index, countable);
                true
            }
            Err(index) if index == self.message_ids.len() => {
                self.message_ids.push(message_id);
                self.countable.push(countable);
                self.tree.push(i64::from(countable));
                true
            }
            Err(_) => false,
        }
    }

    pub(super) fn set_countability(&mut self, message_id: i64, countable: bool) -> bool {
        match self.message_ids.binary_search(&message_id) {
            Ok(index) => {
                self.set_countability_at(index, countable);
                true
            }
            Err(_) => false,
        }
    }

    fn set_countability_at(&mut self, index: usize, countable: bool) {
        if self.countable[index] == countable {
            return;
        }

        let delta = if countable { 1 } else { -1 };
        self.countable[index] = countable;
        self.tree.add(index, delta);
    }
}

#[cfg(test)]
mod tests {
    use super::{ChatUnreadIndex, ChatUnreadMessageSnapshot};

    fn snapshot(id: i64, countable: bool) -> ChatUnreadMessageSnapshot {
        ChatUnreadMessageSnapshot { id, countable }
    }

    #[test]
    fn counts_sparse_message_ids_after_read_pointer() {
        let index = ChatUnreadIndex::from_snapshot(vec![
            snapshot(100, true),
            snapshot(500, false),
            snapshot(900, true),
            snapshot(1200, true),
        ]);

        assert_eq!(index.count_after(None), 3);
        assert_eq!(index.count_after(Some(0)), 3);
        assert_eq!(index.count_after(Some(100)), 2);
        assert_eq!(index.count_after(Some(499)), 2);
        assert_eq!(index.count_after(Some(900)), 1);
        assert_eq!(index.count_after(Some(1200)), 0);
    }

    #[test]
    fn flips_countability_for_recall_and_late_publish() {
        let mut index = ChatUnreadIndex::from_snapshot(vec![
            snapshot(10, true),
            snapshot(20, false),
            snapshot(30, true),
        ]);

        assert!(index.set_countability(20, true));
        assert_eq!(index.count_after(None), 3);

        assert!(index.set_countability(30, false));
        assert_eq!(index.count_after(None), 2);
        assert_eq!(index.count_after(Some(20)), 0);
    }

    #[test]
    fn duplicate_observation_is_idempotent() {
        let mut index =
            ChatUnreadIndex::from_snapshot(vec![snapshot(10, true), snapshot(20, true)]);

        assert!(index.observe_message(20, true));
        assert_eq!(index.count_after(None), 2);

        assert!(index.observe_message(20, false));
        assert_eq!(index.count_after(None), 1);
    }

    #[test]
    fn appends_newer_messages_but_rejects_unknown_older_messages() {
        let mut index =
            ChatUnreadIndex::from_snapshot(vec![snapshot(10, true), snapshot(30, true)]);

        assert!(index.observe_message(40, true));
        assert_eq!(index.count_after(None), 3);

        assert!(!index.observe_message(20, true));
        assert_eq!(index.count_after(None), 3);
        assert!(!index.set_countability(99, false));
    }
}
