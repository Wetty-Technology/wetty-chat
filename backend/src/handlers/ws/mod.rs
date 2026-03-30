//! WebSocket handler: auth handshake, lifecycle-aware presence updates, ping/pong keepalive,
//! connection registry, 300s stale timeout.

pub mod messages;

use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::State;
use axum::response::Response;
use axum::Json;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use std::time::Instant;
use tokio::time::timeout;
use tracing::{debug, trace};

use crate::services::ws_registry;
use crate::utils::auth::{decode_auth_token, encode_auth_token, AuthClaims, ClientId, CurrentUid};
use crate::AppState;
use messages::ServerWsMessage;
use ws_registry::AppPresenceState;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TicketResponse {
    pub ticket: String,
}

async fn get_ws_ticket(
    CurrentUid(uid): CurrentUid,
    ClientId(client_id): ClientId,
    State(state): State<AppState>,
) -> Result<Json<TicketResponse>, (axum::http::StatusCode, &'static str)> {
    let claims = AuthClaims {
        uid,
        cid: client_id,
        gen: 0,
    };
    let ticket = encode_auth_token(&claims, &state.jwt_signing_key)?;

    Ok(Json(TicketResponse { ticket }))
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct WsAuthMessage {
    #[serde(rename = "type")]
    type_: String,
    ticket: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct WsMessage {
    #[serde(rename = "type")]
    type_: String,
    state: Option<WsAppState>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
enum WsAppState {
    Active,
    Inactive,
}

impl From<WsAppState> for AppPresenceState {
    fn from(value: WsAppState) -> Self {
        match value {
            WsAppState::Active => AppPresenceState::Active,
            WsAppState::Inactive => AppPresenceState::Inactive,
        }
    }
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
                    match decode_auth_token(&parsed.ticket, &state.jwt_signing_key) {
                        Ok(claims) => claims.uid,
                        Err(e) => {
                            debug!("ws auth rejected (invalid ticket): {:?}", e);
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

    handle_socket(socket, state, uid, conn_id, registry, entry, rx).await;
}

async fn handle_socket(
    mut socket: WebSocket,
    state: AppState,
    uid: i32,
    conn_id: u64,
    registry: Arc<ws_registry::ConnectionRegistry>,
    entry: Arc<ws_registry::ConnectionEntry>,
    mut rx: tokio::sync::mpsc::Receiver<Arc<ServerWsMessage>>,
) {
    let started_at = Instant::now();
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
                                let state = parsed
                                    .state
                                    .map(AppPresenceState::from)
                                    .unwrap_or(AppPresenceState::Active);
                                entry.update_ping(state);
                                registry.refresh_metrics();
                                trace!("ws ping received uid={} conn_id={}", uid, conn_id);
                                if socket.send(Message::Text(PONG_JSON.into())).await.is_err() {
                                    break;
                                }
                            } else if parsed.type_ == "appState" {
                                let state = parsed
                                    .state
                                    .map(AppPresenceState::from)
                                    .unwrap_or(AppPresenceState::Inactive);
                                entry.update_app_state(state);
                                registry.refresh_metrics();
                                trace!(
                                    "ws app_state received uid={} conn_id={} state={:?}",
                                    uid,
                                    conn_id,
                                    state
                                );
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
    state
        .metrics
        .record_ws_connection_duration(started_at.elapsed().as_secs_f64());
}

pub fn router() -> axum::Router<crate::AppState> {
    axum::Router::new()
        .route("/", axum::routing::get(ws_handler))
        .route("/ticket", axum::routing::get(get_ws_ticket))
}
