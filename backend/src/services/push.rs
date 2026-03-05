use diesel::prelude::*;
use diesel::r2d2::{ConnectionManager, Pool};
use diesel::PgConnection;
use futures::stream::{self, StreamExt};
use std::sync::Arc;
use tokio::sync::mpsc;
use tracing::{debug, error, info, warn};
use web_push::{HyperWebPushClient, WebPushClient};

use crate::models::PushSubscription;
use crate::schema::push_subscriptions;
use crate::services::ws_registry::ConnectionRegistry;

/// Maximum characters kept in the push notification body preview.
const MESSAGE_PREVIEW_MAX: usize = 100;

/// Number of concurrent outbound push HTTP requests.
const PUSH_CONCURRENCY: usize = 10;

/// Channel buffer size for pending push jobs.
const CHANNEL_BUFFER: usize = 1024;

/// A push notification job enqueued when a new message is created.
#[derive(Debug, Clone)]
pub struct PushJob {
    pub chat_id: i64,
    pub sender_uid: i32,
    pub sender_username: String,
    pub chat_name: String,
    pub message_preview: Option<String>,
    pub message_id: i64,
}

pub struct PushService {
    pub client: HyperWebPushClient,
    pub vapid_public_key: String,
    pub vapid_private_key: String,
    pub vapid_subject: String,
    job_tx: mpsc::Sender<PushJob>,
}

impl PushService {
    /// Create the push service and spawn the background worker.
    ///
    /// The worker pulls `PushJob`s from the channel and delivers push notifications
    /// to all subscribed, offline members of the relevant chat.
    pub fn start(
        db: Pool<ConnectionManager<PgConnection>>,
        ws_registry: Arc<ConnectionRegistry>,
    ) -> Arc<Self> {
        let public_key = std::env::var("VAPID_PUBLIC_KEY")
            .expect("VAPID_PUBLIC_KEY environment variable must be set");
        let private_key = std::env::var("VAPID_PRIVATE_KEY")
            .expect("VAPID_PRIVATE_KEY environment variable must be set");
        let subject =
            std::env::var("VAPID_SUBJECT").expect("VAPID_SUBJECT environment variable must be set");

        // Validate the private key parses correctly.
        let _ = web_push::VapidSignatureBuilder::from_base64_no_sub(&private_key)
            .expect("Failed to create VapidSignatureBuilder from VAPID_PRIVATE_KEY");

        let (tx, rx) = mpsc::channel(CHANNEL_BUFFER);

        let service = Arc::new(Self {
            client: HyperWebPushClient::new(),
            vapid_public_key: public_key,
            vapid_private_key: private_key,
            vapid_subject: subject,
            job_tx: tx,
        });

        // Spawn the background worker.
        let worker_service = service.clone();
        tokio::spawn(async move {
            run_push_worker(rx, worker_service, db, ws_registry).await;
        });

        service
    }

    /// Enqueue a push job. Non-blocking; logs a warning if the channel is full.
    pub fn enqueue(&self, job: PushJob) {
        if let Err(e) = self.job_tx.try_send(job) {
            warn!("Push job channel full, dropping notification: {}", e);
        }
    }

    /// Send a push notification to a single subscription. Returns `Ok(())` on success,
    /// or the endpoint string if it should be removed (stale).
    pub async fn send_to_subscription(
        &self,
        sub: &PushSubscription,
        payload: &[u8],
    ) -> Result<(), Option<String>> {
        let subscription_info = web_push::SubscriptionInfo::new(
            sub.endpoint.clone(),
            sub.p256dh.clone(),
            sub.auth.clone(),
        );

        let sig_builder =
            match web_push::VapidSignatureBuilder::from_base64_no_sub(&self.vapid_private_key) {
                Ok(b) => b,
                Err(e) => {
                    error!(
                        "Vapid config error (should have been caught on startup): {:?}",
                        e
                    );
                    return Err(None);
                }
            };

        let mut b = sig_builder.add_sub_info(&subscription_info);
        b.add_claim("sub", self.vapid_subject.clone());
        let signature = match b.build() {
            Ok(sig) => sig,
            Err(e) => {
                error!("Failed to build VAPID signature: {:?}", e);
                return Err(None);
            }
        };

        let mut builder = web_push::WebPushMessageBuilder::new(&subscription_info);
        builder.set_payload(web_push::ContentEncoding::Aes128Gcm, payload);
        builder.set_vapid_signature(signature);

        match builder.build() {
            Ok(message) => match self.client.send(message).await {
                Ok(_) => Ok(()),
                Err(e) => {
                    if matches!(
                        e,
                        web_push::WebPushError::EndpointNotValid(_)
                            | web_push::WebPushError::EndpointNotFound(_)
                    ) {
                        warn!("Stale push subscription for endpoint {}", sub.endpoint);
                        Err(Some(sub.endpoint.clone()))
                    } else {
                        error!("Failed to send push notification: {:?}", e);
                        Err(None)
                    }
                }
            },
            Err(e) => {
                error!("Failed to build push message: {:?}", e);
                Err(None)
            }
        }
    }
}

/// Background worker that processes push notification jobs.
async fn run_push_worker(
    mut rx: mpsc::Receiver<PushJob>,
    service: Arc<PushService>,
    db: Pool<ConnectionManager<PgConnection>>,
    ws_registry: Arc<ConnectionRegistry>,
) {
    info!("Push notification worker started");

    while let Some(job) = rx.recv().await {
        debug!(
            "Processing push job: chat_id={} sender_uid={} message_id={}",
            job.chat_id, job.sender_uid, job.message_id
        );

        let conn = match db.get() {
            Ok(c) => c,
            Err(e) => {
                error!("Push worker: failed to get DB connection: {:?}", e);
                continue;
            }
        };

        if let Err(e) = process_push_job(&service, conn, &ws_registry, &job).await {
            error!(
                "Push worker: job failed for message_id={}: {}",
                job.message_id, e
            );
        }
    }

    info!("Push notification worker stopped (channel closed)");
}

/// Process a single push job: load subscriptions, filter online users, send, cleanup.
async fn process_push_job(
    service: &Arc<PushService>,
    mut conn: diesel::r2d2::PooledConnection<ConnectionManager<PgConnection>>,
    ws_registry: &ConnectionRegistry,
    job: &PushJob,
) -> Result<(), String> {
    use crate::schema::group_membership;
    use crate::schema::group_membership::dsl as gm_dsl;

    // 1. Get all member UIDs for the chat.
    let member_uids: Vec<i32> = group_membership::table
        .filter(gm_dsl::chat_id.eq(job.chat_id))
        .select(group_membership::uid)
        .load(&mut conn)
        .map_err(|e| format!("Failed to load member UIDs: {:?}", e))?;

    // 2. Filter out the sender and users with active WS connections.
    let target_uids: Vec<i32> = member_uids
        .into_iter()
        .filter(|&uid| uid != job.sender_uid)
        .filter(|&uid| !ws_registry.has_active_connections(uid))
        .collect();

    if target_uids.is_empty() {
        debug!(
            "Push job: no offline recipients for message_id={}",
            job.message_id
        );
        return Ok(());
    }

    // 3. Load push subscriptions for the target users.
    let subs: Vec<PushSubscription> = push_subscriptions::table
        .filter(push_subscriptions::dsl::user_id.eq_any(&target_uids))
        .select(PushSubscription::as_select())
        .load(&mut conn)
        .map_err(|e| format!("Failed to load push subscriptions: {:?}", e))?;

    if subs.is_empty() {
        debug!(
            "Push job: no subscriptions for message_id={}",
            job.message_id
        );
        return Ok(());
    }

    debug!(
        "Push job: sending to {} subscriptions for message_id={}",
        subs.len(),
        job.message_id
    );

    // 4. Build the push payload.
    let body_text = match &job.message_preview {
        Some(preview) => {
            let truncated = if preview.len() > MESSAGE_PREVIEW_MAX {
                format!("{}…", &preview[..MESSAGE_PREVIEW_MAX])
            } else {
                preview.clone()
            };
            format!("{}: {}", job.sender_username, truncated)
        }
        None => format!("{} sent a message", job.sender_username),
    };

    let payload = serde_json::to_vec(&serde_json::json!({
        "type": "new_message",
        "title": job.chat_name,
        "body": body_text,
        "data": {
            "chat_id": job.chat_id.to_string(),
            "message_id": job.message_id.to_string(),
        }
    }))
    .map_err(|e| format!("Failed to serialize push payload: {:?}", e))?;

    // 5. Send concurrently with bounded parallelism.
    let stale_endpoints: Vec<String> = stream::iter(subs.into_iter())
        .map(|sub| {
            let service = service.clone();
            let payload = payload.clone();
            async move {
                match service.send_to_subscription(&sub, &payload).await {
                    Ok(()) => None,
                    Err(Some(endpoint)) => Some(endpoint),
                    Err(None) => None,
                }
            }
        })
        .buffer_unordered(PUSH_CONCURRENCY)
        .filter_map(|result| async move { result })
        .collect()
        .await;

    // 6. Clean up stale subscriptions.
    if !stale_endpoints.is_empty() {
        debug!(
            "Cleaning up {} stale push subscriptions",
            stale_endpoints.len()
        );
        let _ = diesel::delete(
            push_subscriptions::table
                .filter(push_subscriptions::dsl::endpoint.eq_any(&stale_endpoints)),
        )
        .execute(&mut conn)
        .map_err(|e| {
            error!("Failed to clean up stale subscriptions: {:?}", e);
        });
    }

    Ok(())
}
