use axum::{extract::State, http::StatusCode, response::IntoResponse, Json};
use chrono::Utc;
use diesel::prelude::*;
use serde::{Deserialize, Serialize};

use crate::models::{NewPushSubscription, PushSubscription};
use crate::schema::push_subscriptions;
use crate::utils::auth::CurrentUid;
use crate::utils::ids;
use crate::AppState;

#[derive(Serialize)]
pub struct VapidPublicKeyResponse {
    pub public_key: String,
}

pub async fn get_vapid_public_key(State(state): State<AppState>) -> Json<VapidPublicKeyResponse> {
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

pub async fn post_subscribe(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Json(body): Json<SubscribeBody>,
) -> Result<impl IntoResponse, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    let sub_id = ids::next_message_id(state.id_gen.as_ref())
        .await
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "ID generation failed"))?;

    let new_sub = NewPushSubscription {
        id: sub_id,
        user_id: uid,
        endpoint: body.endpoint,
        p256dh: body.keys.p256dh,
        auth: body.keys.auth,
        created_at: Utc::now().naive_utc(),
    };

    diesel::insert_into(push_subscriptions::table)
        .values(&new_sub)
        .on_conflict((push_subscriptions::user_id, push_subscriptions::endpoint))
        .do_update()
        .set((
            push_subscriptions::p256dh.eq(&new_sub.p256dh),
            push_subscriptions::auth.eq(&new_sub.auth),
            push_subscriptions::created_at.eq(&new_sub.created_at),
        ))
        .execute(conn)
        .map_err(|e| {
            tracing::error!("upsert subscription: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to save subscription",
            )
        })?;

    Ok(StatusCode::CREATED)
}

#[derive(Deserialize)]
pub struct UnsubscribeBody {
    pub endpoint: String,
}

pub async fn post_unsubscribe(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Json(body): Json<UnsubscribeBody>,
) -> Result<impl IntoResponse, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    diesel::delete(
        push_subscriptions::table
            .filter(push_subscriptions::dsl::user_id.eq(uid))
            .filter(push_subscriptions::dsl::endpoint.eq(&body.endpoint)),
    )
    .execute(conn)
    .map_err(|e| {
        tracing::error!("delete subscription: {:?}", e);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Failed to delete subscription",
        )
    })?;

    Ok(StatusCode::OK)
}

#[derive(Deserialize)]
pub struct TestNotificationBody {
    pub title: String,
    pub body: String,
}

pub async fn post_test(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Json(payload_body): Json<TestNotificationBody>,
) -> Result<impl IntoResponse, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    let subs: Vec<PushSubscription> = push_subscriptions::table
        .filter(push_subscriptions::dsl::user_id.eq(uid))
        .select(PushSubscription::as_select())
        .load(conn)
        .map_err(|_| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to find subscriptions",
            )
        })?;

    let payload = serde_json::to_vec(&serde_json::json!({
        "title": payload_body.title,
        "body": payload_body.body
    }))
    .unwrap();

    let mut success_count = 0;
    let mut stale_endpoints: Vec<String> = Vec::new();

    for sub in &subs {
        match state.push_service.send_to_subscription(sub, &payload).await {
            Ok(()) => success_count += 1,
            Err(Some(endpoint)) => stale_endpoints.push(endpoint),
            Err(None) => {}
        }
    }

    // Clean up stale subscriptions
    if !stale_endpoints.is_empty() {
        let _ = diesel::delete(
            push_subscriptions::table
                .filter(push_subscriptions::dsl::user_id.eq(uid))
                .filter(push_subscriptions::dsl::endpoint.eq_any(&stale_endpoints)),
        )
        .execute(conn)
        .map_err(|e| {
            tracing::error!("Failed to clean up stale subscriptions: {:?}", e);
        });
    }

    Ok(Json(serde_json::json!({
        "success_count": success_count,
    })))
}
