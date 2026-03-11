pub mod attachments;
pub mod chats;
pub mod groups;
pub mod members;
pub mod messages;
pub mod push;
pub mod users;
pub mod ws;

use crate::AppState;
use axum::Router;

pub fn api_router() -> Router<AppState> {
    Router::new()
        .nest("/ws", ws::router())
        .nest("/chats", chats::router())
        .nest("/group", groups::router())
        .nest("/push", push::router())
        .nest("/users", users::router())
        .nest("/attachments", attachments::router())
}
