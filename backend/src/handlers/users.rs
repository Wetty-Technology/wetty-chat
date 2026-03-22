use axum::{
    extract::State,
    http::{HeaderMap, StatusCode},
    Json,
};
use diesel::prelude::*;
use serde::Serialize;

use crate::services::user::lookup_user_avatars;
use crate::utils::auth::{
    encode_auth_token, extract_auth_context, required_client_id, AuthClaims, AuthSource, CurrentUid,
};
use crate::AppState;

#[derive(Serialize)]
pub struct MeResponse {
    pub uid: i32,
    pub username: String,
    pub avatar_url: Option<String>,
}

#[derive(Serialize)]
pub struct AuthTokenResponse {
    pub token: String,
}

/// GET /users/me — Get the current logged in user's information
async fn get_me(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
) -> Result<Json<MeResponse>, (StatusCode, &'static str)> {
    use crate::schema::discuz::discuz::common_member::dsl as cm_dsl;

    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    let username = cm_dsl::common_member
        .filter(cm_dsl::uid.eq(uid))
        .select(cm_dsl::username)
        .first::<String>(conn)
        .optional()
        .map_err(|e| {
            tracing::error!("get me username: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?
        .unwrap_or_else(|| "Unknown".to_string());

    let mut avatars = lookup_user_avatars(&state, &[uid]);
    let avatar_url = avatars.remove(&uid).flatten();

    Ok(Json(MeResponse {
        uid,
        username,
        avatar_url,
    }))
}

async fn get_auth_token(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<AuthTokenResponse>, (StatusCode, &'static str)> {
    let auth = extract_auth_context(&headers, &state)?;
    let client_id = match auth.client_id {
        Some(client_id) => client_id,
        None if auth.source == AuthSource::Legacy => required_client_id(&headers)?,
        None => return Err((StatusCode::BAD_REQUEST, "Missing X-Client-Id header")),
    };

    let token = encode_auth_token(
        &AuthClaims {
            uid: auth.uid,
            cid: client_id,
            gen: 0,
        },
        &state.jwt_signing_key,
    )?;

    Ok(Json(AuthTokenResponse { token }))
}

pub fn router() -> axum::Router<crate::AppState> {
    axum::Router::new()
        .route("/me", axum::routing::get(get_me))
        .route("/auth-token", axum::routing::get(get_auth_token))
}
