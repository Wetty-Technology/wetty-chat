use axum::{extract::State, http::StatusCode, Json};

use crate::models::User;
use crate::services;
use crate::utils::auth::CurrentUid;
use crate::AppState;

/// GET /users/me — Get the current logged in user's information
pub async fn get_me(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
) -> Result<Json<User>, (StatusCode, &'static str)> {
    let mut names = services::user::lookup_users(&state, &[uid]).await;
    let username = names
        .remove(&uid)
        .flatten()
        .unwrap_or_else(|| "Unknown".to_string());

    Ok(Json(User { uid, username }))
}
