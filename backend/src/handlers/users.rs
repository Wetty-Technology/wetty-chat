use axum::{extract::State, http::HeaderMap, Json};
use serde::Serialize;
use utoipa::ToSchema;
use utoipa_axum::router::OpenApiRouter;
use utoipa_axum::routes;

use crate::errors::AppError;
use crate::extractors::DbConn;
use crate::handlers::ws::messages::{ServerWsMessage, StickerPackOrderUpdatePayload};
use crate::models::{NewUserExtra, UserExtra};
use crate::schema::{sticker_packs, user_extra, user_sticker_pack_subscriptions};
use crate::services::user::{lookup_user_avatars, lookup_user_profiles};
use crate::utils::auth::{
    encode_auth_token, extract_auth_context, required_client_id, AuthClaims, AuthSource, CurrentUid,
};
use crate::AppState;
use diesel::prelude::*;
use std::collections::HashSet;
use std::sync::Arc;

#[derive(Debug, Clone, serde::Deserialize, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct StickerPackOrderItem {
    pub sticker_pack_id: String,
    pub last_used_on: i64,
}

#[derive(serde::Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct UpdateStickerPackOrderItem {
    pub sticker_pack_id: String,
    pub last_used_on: i64,
    pub is_auto_sort: Option<bool>,
}

#[derive(serde::Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct UpdateStickerPackOrderRequest {
    pub order: Vec<UpdateStickerPackOrderItem>,
}

#[utoipa::path(
    put,
    path = "/me/stickerpack-order",
    tag = "users",
    request_body = UpdateStickerPackOrderRequest,
    responses(
        (status = 200, description = "Order updated successfully")
    ),
    security(("uid_header" = []), ("bearer_jwt" = []))
)]
async fn put_stickerpack_order(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    mut conn: DbConn,
    Json(req): Json<UpdateStickerPackOrderRequest>,
) -> Result<Json<()>, AppError> {
    let conn = &mut *conn;
    let requested_order = req.order;

    let requested_pack_ids: Vec<i64> = requested_order
        .iter()
        .filter_map(|item| item.sticker_pack_id.parse::<i64>().ok())
        .collect();
    let accessible_pack_ids = load_accessible_sticker_pack_ids(conn, uid, &requested_pack_ids)?;

    let extra = user_extra::table
        .filter(user_extra::uid.eq(uid))
        .first::<UserExtra>(conn)
        .optional()?;

    let mut current_order = extra
        .and_then(|e| {
            serde_json::from_value::<Vec<StickerPackOrderItem>>(e.sticker_pack_order).ok()
        })
        .unwrap_or_default();

    // Sort descending by last_used_on to safely determine position
    let mut sorted_order = current_order.clone();
    sorted_order.sort_by_key(|o| -o.last_used_on);

    use crate::MAX_AUTO_SORT_LIMIT;
    let auto_sort_limit = MAX_AUTO_SORT_LIMIT;

    for inc in requested_order {
        let Ok(pack_id) = inc.sticker_pack_id.parse::<i64>() else {
            continue;
        };

        if !accessible_pack_ids.contains(&pack_id) {
            continue;
        }

        if inc.is_auto_sort.unwrap_or(false) {
            let current_pos = sorted_order
                .iter()
                .position(|o| o.sticker_pack_id == inc.sticker_pack_id);
            let Some(pos) = current_pos else {
                continue;
            };
            if pos >= auto_sort_limit {
                continue;
            }
        }

        if let Some(existing) = current_order
            .iter_mut()
            .find(|o| o.sticker_pack_id == inc.sticker_pack_id)
        {
            existing.last_used_on = inc.last_used_on;
        } else {
            current_order.push(StickerPackOrderItem {
                sticker_pack_id: inc.sticker_pack_id,
                last_used_on: inc.last_used_on,
            });
        }

        sorted_order = current_order.clone();
        sorted_order.sort_by_key(|item| -item.last_used_on);
    }

    let order_json = serde_json::to_value(&current_order).unwrap_or(serde_json::json!([]));

    let affected = diesel::update(user_extra::table.filter(user_extra::uid.eq(uid)))
        .set(user_extra::sticker_pack_order.eq(&order_json))
        .execute(conn)?;

    if affected == 0 {
        let now = chrono::Utc::now().naive_utc();
        diesel::insert_into(user_extra::table)
            .values(NewUserExtra {
                uid,
                first_seen_at: now,
                last_seen_at: now,
                sticker_pack_order: order_json.clone(),
            })
            .execute(conn)?;
    }

    let msg = Arc::new(ServerWsMessage::StickerPackOrderUpdated(
        StickerPackOrderUpdatePayload {
            order: current_order,
        },
    ));
    state.ws_registry.broadcast_to_uids(&[uid], msg);

    Ok(Json(()))
}

#[derive(Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct MeResponse {
    pub uid: i32,
    pub username: String,
    pub avatar_url: Option<String>,
    pub gender: i16,
    pub sticker_pack_order: Vec<StickerPackOrderItem>,
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

    let extra = user_extra::table
        .filter(user_extra::uid.eq(uid))
        .select(UserExtra::as_select())
        .first::<UserExtra>(conn)
        .optional()?;

    let sticker_pack_order = extra
        .and_then(|e| {
            serde_json::from_value::<Vec<StickerPackOrderItem>>(e.sticker_pack_order).ok()
        })
        .unwrap_or_default();

    Ok(Json(MeResponse {
        uid,
        username,
        avatar_url,
        gender: profile.map(|profile| profile.gender).unwrap_or(0),
        sticker_pack_order,
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

pub fn router() -> OpenApiRouter<crate::AppState> {
    OpenApiRouter::new()
        .routes(routes!(get_me))
        .routes(routes!(get_auth_token))
        .routes(routes!(put_stickerpack_order))
}

fn load_accessible_sticker_pack_ids(
    conn: &mut PgConnection,
    uid: i32,
    pack_ids: &[i64],
) -> Result<HashSet<i64>, AppError> {
    if pack_ids.is_empty() {
        return Ok(HashSet::new());
    }

    let owned_pack_ids: Vec<i64> = sticker_packs::table
        .filter(sticker_packs::owner_uid.eq(uid))
        .filter(sticker_packs::id.eq_any(pack_ids))
        .select(sticker_packs::id)
        .load(conn)?;

    let subscribed_pack_ids: Vec<i64> = user_sticker_pack_subscriptions::table
        .filter(user_sticker_pack_subscriptions::uid.eq(uid))
        .filter(user_sticker_pack_subscriptions::pack_id.eq_any(pack_ids))
        .select(user_sticker_pack_subscriptions::pack_id)
        .load(conn)?;

    Ok(owned_pack_ids
        .into_iter()
        .chain(subscribed_pack_ids)
        .collect())
}
