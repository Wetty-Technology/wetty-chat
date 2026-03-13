//! WebSocket handler: auth via uid query, ping/pong keepalive, connection registry, 300s stale timeout.

pub mod messages;

use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::State;
use axum::response::Response;
use axum::Json;
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use std::sync::atomic::Ordering;
use std::sync::Arc;
use tokio::time::timeout;
use tracing::trace;

use crate::services::ws_registry;
use crate::utils::auth::CurrentUid;
use crate::AppState;
use messages::ServerWsMessage;

#[derive(Debug, Serialize, Deserialize)]
pub struct WsClaims {
    pub uid: i32,
    pub exp: usize,
}

#[derive(Serialize)]
pub struct TicketResponse {
    pub ticket: String,
}

async fn get_ws_ticket(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
) -> Result<Json<TicketResponse>, (axum::http::StatusCode, &'static str)> {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs();

    // 7 days expiration
    let exp = now as usize + 7 * 24 * 60 * 60;

    let claims = WsClaims { uid, exp };
    let ticket = encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(&state.ws_secret),
    )
    .map_err(|_| {
        (
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            "Failed to create ticket",
        )
    })?;

    Ok(Json(TicketResponse { ticket }))
}

#[derive(Deserialize)]
struct WsAuthMessage {
    #[serde(rename = "type")]
    type_: String,
    ticket: String,
}

#[derive(Deserialize)]
struct WsMessage {
    #[serde(rename = "type")]
    type_: String,
}

const PONG_JSON: &str = r#"{"type":"pong"}"#;

/// Upgrades the connection to WebSocket and initiates auth handshake.
async fn ws_handler(State(state): State<AppState>, ws: WebSocketUpgrade) -> Response {
    ws.on_upgrade(move |socket| handle_auth_and_socket(socket, state))
}

async fn handle_auth_and_socket(mut socket: WebSocket, state: AppState) {
    // Wait for auth message, timeout after 5 seconds
    let auth_result = timeout(std::time::Duration::from_secs(5), socket.recv()).await;

    let uid = match auth_result {
        Ok(Some(Ok(Message::Text(text)))) => {
            if let Ok(parsed) = serde_json::from_str::<WsAuthMessage>(&text) {
                if parsed.type_ == "auth" {
                    match decode::<WsClaims>(
                        &parsed.ticket,
                        &DecodingKey::from_secret(&state.ws_secret),
                        &Validation::default(),
                    ) {
                        Ok(token_data) => token_data.claims.uid,
                        Err(e) => {
                            trace!("ws auth rejected (invalid ticket): {:?}", e);
                            return;
                        } // Invalid ticket
                    }
                } else {
                    return; // First message not auth
                }
            } else {
                return; // Invalid JSON or wrong structure
            }
        }
        _ => return, // Timeout, connection closed, or non-text message
    };

    let registry = state.ws_registry.clone();
    let (entry, rx) = registry.register(uid);
    let conn_id = entry.conn_id;

    handle_socket(socket, uid, conn_id, registry, entry, rx).await;
}

async fn handle_socket(
    mut socket: WebSocket,
    uid: i32,
    conn_id: u64,
    registry: Arc<ws_registry::ConnectionRegistry>,
    entry: Arc<ws_registry::ConnectionEntry>,
    mut rx: tokio::sync::mpsc::Receiver<Arc<ServerWsMessage>>,
) {
    loop {
        tokio::select! {
            msg = rx.recv() => {
                match msg {
                    Some(ws_msg) => {
                        if let Ok(text) = serde_json::to_string(&*ws_msg) {
                            if socket.send(Message::Text(text.into())).await.is_err() {
                                break;
                            }
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

pub fn router() -> axum::Router<crate::AppState> {
    axum::Router::new()
        .route("/", axum::routing::get(ws_handler))
        .route("/ticket", axum::routing::get(get_ws_ticket))
}
