pub mod attachments;
pub mod chats;
pub mod groups;
pub mod invites;
pub mod members;
pub mod push;
pub mod stickers;
pub mod threads;
pub mod users;
pub mod ws;

use crate::AppState;
use axum::Router;

pub fn api_router() -> Router<AppState> {
    Router::new()
        .nest("/ws", ws::router())
        .nest("/chats", chats::router())
        .nest("/threads", threads::router())
        .nest("/group", groups::router())
        .nest("/invites", invites::router())
        .nest("/push", push::router())
        .nest("/stickers", stickers::router())
        .nest("/users", users::router())
        .nest("/attachments", attachments::router())
}
