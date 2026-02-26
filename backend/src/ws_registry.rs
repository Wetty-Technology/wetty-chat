//! WebSocket connection registry: maps user id to active connections, supports broadcast and stale-connection pruning.

use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::sync::mpsc;

/// Per-connection state: sender to push messages to the socket task, last ping time for timeout.
#[derive(Debug)]
pub struct ConnectionEntry {
    pub conn_id: u64,
    pub tx: mpsc::Sender<String>,
    /// Unix timestamp (seconds) when we last received a ping from the client.
    pub last_ping_at: AtomicU64,
}

static NEXT_CONN_ID: AtomicU64 = AtomicU64::new(0);

fn next_conn_id() -> u64 {
    NEXT_CONN_ID.fetch_add(1, Ordering::Relaxed)
}

pub(crate) fn now_secs() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

/// Registry of active WebSocket connections per user id. Thread-safe; shared via Arc.
pub struct ConnectionRegistry {
    /// uid -> list of connection entries (multiple tabs/devices per user).
    inner: dashmap::DashMap<i32, Vec<Arc<ConnectionEntry>>>,
}

impl ConnectionRegistry {
    pub fn new() -> Self {
        Self {
            inner: dashmap::DashMap::new(),
        }
    }

    /// Register a new connection for the given user. Returns the entry (to update last_ping_at)
    /// and the receiver for the send task. Caller must call `remove_connection(uid, conn_id)` when the socket closes.
    pub fn register(&self, uid: i32) -> (Arc<ConnectionEntry>, mpsc::Receiver<String>) {
        let conn_id = next_conn_id();
        let (tx, rx) = mpsc::channel(64);
        let now = now_secs();
        let entry = Arc::new(ConnectionEntry {
            conn_id,
            tx,
            last_ping_at: AtomicU64::new(now),
        });
        self.inner
            .entry(uid)
            .or_default()
            .push(entry.clone());
        (entry, rx)
    }

    /// Remove a single connection. Call when the socket closes.
    pub fn remove_connection(&self, uid: i32, conn_id: u64) {
        let mut empty = false;
        if let Some(mut vec) = self.inner.get_mut(&uid) {
            vec.retain(|e| e.conn_id != conn_id);
            empty = vec.is_empty();
        }
        if empty {
            self.inner.remove(&uid);
        }
    }

    /// Broadcast a JSON string to all connections for the given user ids. Each uid may have multiple connections.
    /// Failures to send (e.g. full buffer) are logged but do not remove the connection here.
    pub fn broadcast_to_uids(&self, uids: &[i32], message: &str) {
        for &uid in uids {
            if let Some(vec) = self.inner.get(&uid) {
                for entry in vec.iter() {
                    if entry.tx.try_send(message.to_string()).is_err() {
                        tracing::debug!(uid, conn_id = entry.conn_id, "ws broadcast try_send full");
                    }
                }
            }
        }
    }

    /// Remove connections that have not sent a ping in more than `max_age` seconds.
    /// Call periodically (e.g. every 60s) from a background task.
    pub fn prune_stale(&self, max_age_secs: u64) {
        let now = now_secs();
        let mut uids_to_trim: Vec<(i32, Vec<u64>)> = Vec::new();
        for ref_entry in self.inner.iter() {
            let uid = *ref_entry.key();
            let stale: Vec<u64> = ref_entry
                .iter()
                .filter(|e| now.saturating_sub(e.last_ping_at.load(Ordering::Relaxed)) > max_age_secs)
                .map(|e| e.conn_id)
                .collect();
            if !stale.is_empty() {
                uids_to_trim.push((uid, stale));
            }
        }
        for (uid, conn_ids) in uids_to_trim {
            if let Some(mut vec) = self.inner.get_mut(&uid) {
                vec.retain(|e| !conn_ids.contains(&e.conn_id));
                if vec.is_empty() {
                    drop(vec);
                    self.inner.remove(&uid);
                }
            }
        }
    }
}

impl Default for ConnectionRegistry {
    fn default() -> Self {
        Self::new()
    }
}
