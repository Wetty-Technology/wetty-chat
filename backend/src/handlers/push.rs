use axum::{extract::State, http::StatusCode, response::IntoResponse, Json};
use chrono::Utc;
use diesel::prelude::*;
use serde::{Deserialize, Serialize};

use crate::models::{NewPushSubscription, PushSubscription};
use crate::schema::push_subscriptions;
use crate::utils::auth::CurrentUid;
use crate::utils::ids;
use crate::AppState;
use web_push::WebPushClient;

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
        user_id: uid as i64,
        endpoint: body.endpoint,
        p256dh: body.keys.p256dh,
        auth: body.keys.auth,
        created_at: Utc::now().naive_utc(),
    };

    diesel::insert_into(push_subscriptions::table)
        .values(&new_sub)
        .execute(conn)
        .map_err(|e| {
            tracing::error!("insert subscription: {:?}", e);
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
            .filter(push_subscriptions::dsl::user_id.eq(uid as i64))
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
        .filter(push_subscriptions::dsl::user_id.eq(uid as i64))
        .select(PushSubscription::as_select())
        .load(conn)
        .map_err(|_| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to find subscriptions",
            )
        })?;

    let mut success_count = 0;

    let payload = serde_json::to_vec(&serde_json::json!({
        "title": payload_body.title,
        "body": payload_body.body
    }))
    .unwrap();

    for sub in subs {
        let subscription_info = web_push::SubscriptionInfo::new(
            sub.endpoint.clone(),
            sub.p256dh.clone(),
            sub.auth.clone(),
        );

        let sig_builder = match web_push::VapidSignatureBuilder::from_base64_no_sub(
            &state.push_service.vapid_private_key,
        ) {
            Ok(b) => b,
            Err(_) => {
                tracing::error!("Vapid config error, should have been caught on startup");
                continue;
            }
        };

        let mut b = sig_builder.add_sub_info(&subscription_info);
        b.add_claim("sub", state.push_service.vapid_subject.clone());
        let signature = match b.build() {
            Ok(sig) => sig,
            Err(e) => {
                tracing::error!("Failed to build signature for sub: {:?}", e);
                continue;
            }
        };

        let mut builder = web_push::WebPushMessageBuilder::new(&subscription_info);
        builder.set_payload(web_push::ContentEncoding::Aes128Gcm, &payload);
        builder.set_vapid_signature(signature);

        match builder.build() {
            Ok(message) => match state.push_service.client.send(message).await {
                Ok(_) => {
                    success_count += 1;
                }
                Err(e) => {
                    tracing::error!("Failed to send push: {:?}", e);
                }
            },
            Err(e) => {
                tracing::error!("Failed to build push message: {:?}", e);
            }
        }
    }

    Ok(Json(serde_json::json!({
        "success_count": success_count,
    })))
}
