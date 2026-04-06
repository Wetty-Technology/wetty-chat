use axum::{extract::State, http::HeaderMap, Json};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use utoipa_axum::router::OpenApiRouter;
use utoipa_axum::routes;

use crate::errors::AppError;
use crate::extractors::DbConn;
use crate::handlers::ws::messages::{ServerWsMessage, UserSettingsUpdatedPayload};
use crate::models::UserSettings;
use crate::schema::primary::user_settings;
use crate::services::user::{lookup_user_avatars, lookup_user_profiles};
use crate::utils::auth::{
    encode_auth_token, extract_auth_context, required_client_id, AuthClaims, AuthSource, CurrentUid,
};
use crate::AppState;
use diesel::{ExpressionMethods, OptionalExtension, QueryDsl, RunQueryDsl};
use std::sync::Arc;

#[derive(Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct MeResponse {
    pub uid: i32,
    pub username: String,
    pub avatar_url: Option<String>,
    pub gender: i16,
}

#[derive(Serialize, ToSchema)]
pub struct AuthTokenResponse {
    pub token: String,
}

/// GET /users/me — Get the current logged in user's information
#[utoipa::path(
    get,
    path = "/me",
    tag = "users",
    responses(
        (status = 200, description = "Current user info", body = MeResponse)
    ),
    security(("uid_header" = []), ("bearer_jwt" = []))
)]
async fn get_me(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    mut conn: DbConn,
) -> Result<Json<MeResponse>, AppError> {
    let conn = &mut *conn;

    let profiles = lookup_user_profiles(conn, &[uid])?;
    let profile = profiles.get(&uid);
    let username = profile
        .and_then(|profile| profile.username.clone())
        .unwrap_or_else(|| "Unknown".to_string());

    let mut avatars = lookup_user_avatars(&state, &[uid]);
    let avatar_url = avatars.remove(&uid).flatten();

    Ok(Json(MeResponse {
        uid,
        username,
        avatar_url,
        gender: profile.map(|profile| profile.gender).unwrap_or(0),
    }))
}

#[utoipa::path(
    get,
    path = "/auth-token",
    tag = "users",
    responses(
        (status = 200, description = "Auth token", body = AuthTokenResponse)
    )
)]
async fn get_auth_token(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<AuthTokenResponse>, AppError> {
    let auth = extract_auth_context(&headers, &state)?;
    let client_id = match auth.client_id {
        Some(client_id) => client_id,
        None if auth.source == AuthSource::Legacy => required_client_id(&headers)?,
        None => return Err(AppError::BadRequest("Missing X-Client-Id header")),
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

#[derive(Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct PatchSettingsRequest {
    pub preferences: serde_json::Value,
}

#[utoipa::path(
    get,
    path = "/me/settings",
    tag = "users",
    responses(
        (status = 200, description = "Current user settings", body = serde_json::Value)
    ),
    security(("uid_header" = []), ("bearer_jwt" = []))
)]
async fn get_settings(
    CurrentUid(current_uid): CurrentUid,
    mut conn: DbConn,
) -> Result<Json<serde_json::Value>, AppError> {
    let conn = &mut *conn;
    let settings = user_settings::table
        .filter(user_settings::uid.eq(current_uid))
        .first::<UserSettings>(conn)
        .optional()?;

    if let Some(settings) = settings {
        Ok(Json(settings.preferences))
    } else {
        Ok(Json(serde_json::json!({})))
    }
}

#[utoipa::path(
    patch,
    path = "/me/settings",
    tag = "users",
    request_body = PatchSettingsRequest,
    responses(
        (status = 200, description = "Updated user settings", body = serde_json::Value)
    ),
    security(("uid_header" = []), ("bearer_jwt" = []))
)]
async fn patch_settings(
    CurrentUid(current_uid): CurrentUid,
    State(state): State<AppState>,
    mut conn: DbConn,
    Json(payload): Json<PatchSettingsRequest>,
) -> Result<Json<serde_json::Value>, AppError> {
    let conn = &mut *conn;

    // First, fetch existing settings
    let existing = user_settings::table
        .filter(user_settings::uid.eq(current_uid))
        .first::<UserSettings>(conn)
        .optional()?;

    let mut final_prefs = existing
        .map(|s| s.preferences)
        .unwrap_or_else(|| serde_json::json!({}));

    // Merge new preferences into existing using json-patch
    json_patch::merge(&mut final_prefs, &payload.preferences);

    // Upsert the merged settings
    let updated = diesel::insert_into(user_settings::table)
        .values((
            user_settings::uid.eq(current_uid),
            user_settings::preferences.eq(&final_prefs),
        ))
        .on_conflict(user_settings::uid)
        .do_update()
        .set(user_settings::preferences.eq(&final_prefs))
        .get_result::<UserSettings>(conn)?;

    // Broadcast the updated settings to all other connections of this user
    let msg = Arc::new(ServerWsMessage::UserSettingsUpdated(
        UserSettingsUpdatedPayload {
            settings: updated.preferences.clone(),
        },
    ));
    state.ws_registry.broadcast_to_uids(&[current_uid], msg);

    Ok(Json(updated.preferences))
}

pub fn router() -> OpenApiRouter<crate::AppState> {
    OpenApiRouter::new()
        .routes(routes!(get_me))
        .routes(routes!(get_auth_token))
        .routes(routes!(get_settings))
        .routes(routes!(patch_settings))
}
