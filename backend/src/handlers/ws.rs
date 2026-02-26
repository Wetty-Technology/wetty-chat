//! WebSocket handler: auth via uid query, ping/pong keepalive, connection registry, 300s stale timeout.

use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{Query, State};
use axum::response::{IntoResponse, Response};
use serde::Deserialize;
use std::sync::atomic::Ordering;
use std::sync::Arc;
use tracing::trace;

use crate::ws_registry;
use crate::AppState;

#[derive(Deserialize)]
pub struct WsQuery {
    uid: Option<String>,
}

#[derive(Deserialize)]
struct WsMessage {
    #[serde(rename = "type")]
    type_: String,
}

const PONG_JSON: &str = r#"{"type":"pong"}"#;
const PING_TIMEOUT_SECS: u64 = 300;

/// Upgrades the connection to WebSocket after validating uid query param. Registers the connection
/// and runs recv/send until close or 300s without ping.
pub async fn ws_handler(
    State(state): State<AppState>,
    Query(q): Query<WsQuery>,
    ws: WebSocketUpgrade,
) -> Response {
    let uid: i32 = match q.uid.as_deref() {
        None => {
            return (axum::http::StatusCode::UNAUTHORIZED, "Missing uid query param").into_response();
        }
        Some(s) => match s.trim().parse() {
            Ok(n) => n,
            Err(_) => {
                return (axum::http::StatusCode::UNAUTHORIZED, "uid must be a valid i32")
                    .into_response();
            }
        },
    };

    let registry = state.ws_registry.clone();
    let (entry, rx) = registry.register(uid);
    let conn_id = entry.conn_id;

    ws.on_upgrade(move |socket| handle_socket(socket, uid, conn_id, registry, entry, rx))
}

async fn handle_socket(
    mut socket: WebSocket,
    uid: i32,
    conn_id: u64,
    registry: Arc<ws_registry::ConnectionRegistry>,
    entry: Arc<ws_registry::ConnectionEntry>,
    mut rx: tokio::sync::mpsc::Receiver<String>,
) {
    loop {
        tokio::select! {
            msg = rx.recv() => {
                match msg {
                    Some(text) => {
                        if socket.send(Message::Text(text.into())).await.is_err() {
                            break;
                        }
                    }
                    None => break,
                }
            }
            msg = socket.recv() => {
                match msg {
                    Some(Ok(Message::Text(text))) => {
                        if let Ok(parsed) = serde_json::from_str::<WsMessage>(&text) {
                            if parsed.type_ == "ping" {
                                entry
                                    .last_ping_at
                                    .store(ws_registry::now_secs(), Ordering::Relaxed);
                                trace!("ws ping received uid={} conn_id={}", uid, conn_id);
                                if socket.send(Message::Text(PONG_JSON.into())).await.is_err() {
                                    break;
                                }
                            }
                        }
                    }
                    Some(Err(_)) | None => break,
                    _ => {}
                }
            }
        }
    }
    registry.remove_connection(uid, conn_id);
}

/// Expose for use in tests or other modules if needed.
pub fn ping_timeout_secs() -> u64 {
    PING_TIMEOUT_SECS
}
