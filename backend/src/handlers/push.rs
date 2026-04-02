use axum::{
    extract::{Query, State},
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use chrono::Utc;
use diesel::prelude::*;
use serde::{Deserialize, Serialize};

use crate::errors::AppError;
use crate::extractors::DbConn;
use crate::models::NewPushSubscription;
use crate::schema::push_subscriptions;
use crate::utils::auth::{ClientId, CurrentUid};
use crate::utils::ids;
use crate::AppState;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct VapidPublicKeyResponse {
    pub public_key: String,
}

async fn get_vapid_public_key(State(state): State<AppState>) -> Json<VapidPublicKeyResponse> {
    Json(VapidPublicKeyResponse {
        public_key: state.push_service.vapid_public_key.clone(),
    })
}

#[derive(Deserialize)]
pub struct SubscribeBody {
    pub endpoint: String,
    pub keys: SubscribeKeys,
}

#[derive(Deserialize)]
pub struct SubscribeKeys {
    pub p256dh: String,
    pub auth: String,
}

async fn post_subscribe(
    CurrentUid(uid): CurrentUid,
    ClientId(client_id): ClientId,
    State(state): State<AppState>,
    mut conn: DbConn,
    Json(body): Json<SubscribeBody>,
) -> Result<impl IntoResponse, AppError> {
    let conn = &mut *conn;

    let sub_id = ids::next_message_id(state.id_gen.as_ref())
        .await
        .map_err(|_| AppError::Internal("ID generation failed"))?;

    let new_sub = NewPushSubscription {
        id: sub_id,
        user_id: uid,
        endpoint: body.endpoint,
        p256dh: body.keys.p256dh,
        auth: body.keys.auth,
        created_at: Utc::now().naive_utc(),
        client_id: Some(client_id.clone()),
    };

    conn.transaction::<_, diesel::result::Error, _>(|conn| {
        diesel::delete(
            push_subscriptions::table
                .filter(push_subscriptions::dsl::user_id.eq(uid))
                .filter(push_subscriptions::dsl::client_id.eq(Some(client_id.clone())))
                .filter(push_subscriptions::dsl::endpoint.ne(&new_sub.endpoint)),
        )
        .execute(conn)?;

        diesel::insert_into(push_subscriptions::table)
            .values(&new_sub)
            .on_conflict((push_subscriptions::user_id, push_subscriptions::endpoint))
            .do_update()
            .set((
                push_subscriptions::p256dh.eq(&new_sub.p256dh),
                push_subscriptions::auth.eq(&new_sub.auth),
                push_subscriptions::created_at.eq(&new_sub.created_at),
                push_subscriptions::client_id.eq(&new_sub.client_id),
            ))
            .execute(conn)?;

        Ok(())
    })?;

    Ok(StatusCode::CREATED)
}

#[derive(Deserialize)]
pub struct UnsubscribeBody {
    #[allow(dead_code)]
    pub endpoint: String,
}

async fn post_unsubscribe(
    CurrentUid(uid): CurrentUid,
    ClientId(client_id): ClientId,
    mut conn: DbConn,
    Json(_body): Json<UnsubscribeBody>,
) -> Result<impl IntoResponse, AppError> {
    let conn = &mut *conn;

    diesel::delete(
        push_subscriptions::table
            .filter(push_subscriptions::dsl::user_id.eq(uid))
            .filter(push_subscriptions::dsl::client_id.eq(Some(client_id))),
    )
    .execute(conn)?;

    Ok(StatusCode::OK)
}

#[derive(Deserialize)]
pub struct SubscriptionStatusQuery {
    pub endpoint: Option<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SubscriptionStatusResponse {
    pub has_active_subscription: bool,
    pub has_matching_endpoint: Option<bool>,
}

async fn get_subscription_status(
    CurrentUid(uid): CurrentUid,
    ClientId(client_id): ClientId,
    mut conn: DbConn,
    Query(query): Query<SubscriptionStatusQuery>,
) -> Result<Json<SubscriptionStatusResponse>, AppError> {
    let conn = &mut *conn;

    let has_active_subscription = diesel::select(diesel::dsl::exists(
        push_subscriptions::table
            .filter(push_subscriptions::dsl::user_id.eq(uid))
            .filter(push_subscriptions::dsl::client_id.eq(Some(client_id.clone()))),
    ))
    .get_result::<bool>(conn)?;

    let has_matching_endpoint = query
        .endpoint
        .as_ref()
        .map(|endpoint| {
            diesel::select(diesel::dsl::exists(
                push_subscriptions::table
                    .filter(push_subscriptions::dsl::user_id.eq(uid))
                    .filter(push_subscriptions::dsl::client_id.eq(Some(client_id.clone())))
                    .filter(push_subscriptions::dsl::endpoint.eq(endpoint)),
            ))
            .get_result::<bool>(conn)
        })
        .transpose()?;

    Ok(Json(SubscriptionStatusResponse {
        has_active_subscription,
        has_matching_endpoint,
    }))
}

pub fn router() -> axum::Router<crate::AppState> {
    axum::Router::new()
        .route(
            "/vapid-public-key",
            axum::routing::get(get_vapid_public_key),
        )
        .route(
            "/subscription-status",
            axum::routing::get(get_subscription_status),
        )
        .route("/subscribe", axum::routing::post(post_subscribe))
        .route("/unsubscribe", axum::routing::post(post_unsubscribe))
}
