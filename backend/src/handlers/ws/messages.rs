use crate::handlers::chats::{MessageResponse, ReactionSummary};
use chrono::{DateTime, Utc};
use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
#[serde(tag = "type", content = "payload", rename_all = "camelCase")]
pub enum ServerWsMessage {
    Message(MessageResponse),
    MessageUpdated(MessageResponse),
    MessageDeleted(MessageResponse),
    ReactionUpdated(ReactionUpdatePayload),
    PresenceUpdate(PresenceUpdatePayload),
    ThreadUpdate(ThreadUpdatePayload),
}

impl ServerWsMessage {
    pub fn message_type(&self) -> &'static str {
        match self {
            Self::Message(_) => "message",
            Self::MessageUpdated(_) => "messageUpdated",
            Self::MessageDeleted(_) => "messageDeleted",
            Self::ReactionUpdated(_) => "reactionUpdated",
            Self::PresenceUpdate(_) => "presenceUpdate",
            Self::ThreadUpdate(_) => "threadUpdate",
        }
    }
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ReactionUpdatePayload {
    #[serde(with = "crate::serde_i64_string")]
    pub message_id: i64,
    #[serde(with = "crate::serde_i64_string")]
    pub chat_id: i64,
    pub reactions: Vec<ReactionSummary>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PresenceUpdatePayload {
    pub active_connections: u32,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ThreadUpdatePayload {
    #[serde(with = "crate::serde_i64_string")]
    pub thread_root_id: i64,
    #[serde(with = "crate::serde_i64_string")]
    pub chat_id: i64,
    pub last_reply_at: DateTime<Utc>,
    pub reply_count: i64,
}

#[cfg(test)]
mod tests {
    use super::{PresenceUpdatePayload, ServerWsMessage};
    use serde_json::json;

    #[test]
    fn serializes_ws_event_types_and_payload_keys_as_camel_case() {
        let value = serde_json::to_value(ServerWsMessage::PresenceUpdate(PresenceUpdatePayload {
            active_connections: 3,
        }))
        .expect("serialize ws event");

        assert_eq!(value["type"], json!("presenceUpdate"));
        assert_eq!(value["payload"]["activeConnections"], json!(3));
        assert!(value["payload"].get("active_connections").is_none());
    }
}
