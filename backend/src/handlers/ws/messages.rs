use crate::handlers::chats::MessageResponse;
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
}
