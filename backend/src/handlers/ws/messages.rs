use crate::handlers::chats::{MessageResponse, ReactionSummary};
use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
#[serde(tag = "type", content = "payload")]
pub enum ServerWsMessage {
    #[serde(rename = "message")]
    Message(MessageResponse),
    #[serde(rename = "message_updated")]
    MessageUpdated(MessageResponse),
    #[serde(rename = "message_deleted")]
    MessageDeleted(MessageResponse),
    #[serde(rename = "reaction_updated")]
    ReactionUpdated(ReactionUpdatePayload),
    #[serde(rename = "presence_update")]
    PresenceUpdate(PresenceUpdatePayload),
}

impl ServerWsMessage {
    pub fn message_type(&self) -> &'static str {
        match self {
            Self::Message(_) => "message",
            Self::MessageUpdated(_) => "message_updated",
            Self::MessageDeleted(_) => "message_deleted",
            Self::ReactionUpdated(_) => "reaction_updated",
            Self::PresenceUpdate(_) => "presence_update",
        }
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct ReactionUpdatePayload {
    #[serde(with = "crate::serde_i64_string")]
    pub message_id: i64,
    #[serde(with = "crate::serde_i64_string")]
    pub chat_id: i64,
    pub reactions: Vec<ReactionSummary>,
}

#[derive(Debug, Clone, Serialize)]
pub struct PresenceUpdatePayload {
    pub active_connections: u32,
}
