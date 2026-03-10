use axum::{extract::State, http::StatusCode, Json};
use diesel::prelude::*;

use crate::models::User;
use crate::schema::users;
use crate::utils::auth::CurrentUid;
use crate::AppState;

/// GET /api/users/me — Get the current logged in user's information
pub async fn get_me(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
) -> Result<Json<User>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    use crate::schema::users::dsl as users_dsl;

    let user = users::table
        .filter(users_dsl::uid.eq(uid))
        .first::<User>(conn)
        .optional()
        .map_err(|e| {
            tracing::error!("get user: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;

    match user {
        Some(u) => Ok(Json(u)),
        None => Err((StatusCode::NOT_FOUND, "User not found")),
    }
}
