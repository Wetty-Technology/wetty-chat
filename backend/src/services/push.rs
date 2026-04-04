use diesel::prelude::*;
use diesel::r2d2::{ConnectionManager, Pool};
use diesel::PgConnection;
use futures::future::FutureExt;
use futures::stream::{self, StreamExt};
use serde::Serialize;
use std::sync::Arc;
use std::time::Duration;
use std::time::Instant;
use tokio::sync::mpsc;
use tracing::{debug, error, info, warn};
use web_push::{HyperWebPushClient, WebPushClient};

use crate::metrics::Metrics;
use crate::models::{MessageType, PushSubscription};
use crate::schema::push_subscriptions;
use crate::services::ws_registry::ConnectionRegistry;

/// Maximum characters kept in the push notification body preview.
const MESSAGE_PREVIEW_MAX: usize = 100;

/// Number of concurrent outbound push HTTP requests.
const PUSH_CONCURRENCY: usize = 10;

/// Channel buffer size for pending push jobs.
const CHANNEL_BUFFER: usize = 1024;
const PUSH_SUPPRESSION_FRESHNESS_SECS: u64 = 30;
const PUSH_WORKER_RESTART_DELAY: Duration = Duration::from_secs(1);

/// A push notification job enqueued when a new message is created.
#[derive(Debug, Clone, Copy, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
enum PushPayloadType {
    NewMessage,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct PushMessagePreviewSticker {
    pub emoji: String,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct PushMessagePreview {
    pub message: Option<String>,
    pub message_type: MessageType,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sticker: Option<PushMessagePreviewSticker>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub first_attachment_kind: Option<String>,
    pub is_deleted: bool,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
struct PushPayloadData {
    chat_id: String,
    message_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    thread_root_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
struct PushPayload {
    #[serde(rename = "type")]
    type_: PushPayloadType,
    title: String,
    body: String,
    sender_name: String,
    message_preview: PushMessagePreview,
    unread_count: i64,
    data: PushPayloadData,
}

#[derive(Debug, Clone)]
pub struct PushJob {
    pub chat_id: i64,
    pub sender_uid: i32,
    pub sender_username: String,
    pub chat_name: String,
    pub message_preview: PushMessagePreview,
    pub legacy_message_preview: Option<String>,
    pub message_id: i64,
    pub thread_root_id: Option<i64>,
    pub mentioned_uids: Vec<i32>,
}

pub struct PushService {
    pub client: HyperWebPushClient,
    pub vapid_public_key: String,
    pub vapid_private_key: String,
    pub vapid_subject: String,
    metrics: Arc<Metrics>,
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
        metrics: Arc<Metrics>,
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
            metrics,
            job_tx: tx,
        });

        // Spawn the background worker supervisor.
        let worker_service = service.clone();
        tokio::spawn(async move {
            supervise_push_worker(rx, worker_service, db, ws_registry).await;
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
                Ok(_) => {
                    self.metrics.record_push_notification(true);
                    Ok(())
                }
                Err(e) => {
                    self.metrics.record_push_notification(false);
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
                self.metrics.record_push_notification(false);
                Err(None)
            }
        }
    }
}

async fn supervise_push_worker(
    mut rx: mpsc::Receiver<PushJob>,
    service: Arc<PushService>,
    db: Pool<ConnectionManager<PgConnection>>,
    ws_registry: Arc<ConnectionRegistry>,
) {
    loop {
        let worker_result =
            std::panic::AssertUnwindSafe(run_push_worker(&mut rx, &service, &db, &ws_registry))
                .catch_unwind()
                .await;

        match worker_result {
            Ok(()) => {
                info!("Push notification worker stopped (channel closed)");
                return;
            }
            Err(payload) => {
                let panic_message = panic_payload_message(payload.as_ref());
                error!(
                    "Push notification worker panicked; restarting in {}s: {}",
                    PUSH_WORKER_RESTART_DELAY.as_secs(),
                    panic_message
                );
                tokio::time::sleep(PUSH_WORKER_RESTART_DELAY).await;
            }
        }
    }
}

/// Background worker that processes push notification jobs.
async fn run_push_worker(
    rx: &mut mpsc::Receiver<PushJob>,
    service: &Arc<PushService>,
    db: &Pool<ConnectionManager<PgConnection>>,
    ws_registry: &Arc<ConnectionRegistry>,
) {
    info!("Push notification worker started");

    while let Some(job) = rx.recv().await {
        debug!(
            "Processing push job: chat_id={} sender_uid={} message_id={}",
            job.chat_id, job.sender_uid, job.message_id
        );
        let started_at = Instant::now();

        #[cfg(test)]
        maybe_panic_for_test(&job);

        let conn = match db.get() {
            Ok(c) => c,
            Err(e) => {
                error!("Push worker: failed to get DB connection: {:?}", e);
                service
                    .metrics
                    .record_push_job("failure", started_at.elapsed().as_secs_f64());
                continue;
            }
        };

        match process_push_job(service, conn, ws_registry, &job).await {
            Ok(()) => service
                .metrics
                .record_push_job("success", started_at.elapsed().as_secs_f64()),
            Err(e) => {
                error!(
                    "Push worker: job failed for message_id={}: {}",
                    job.message_id, e
                );
                service
                    .metrics
                    .record_push_job("failure", started_at.elapsed().as_secs_f64());
            }
        }
    }
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

    let now = chrono::Utc::now();

    // 1. Get candidate UIDs and their mute state.
    //    For thread replies: only thread subscribers.
    //    For top-level messages: all chat members.
    let members: Vec<(i32, Option<chrono::DateTime<chrono::Utc>>)> =
        if let Some(thread_root_id) = job.thread_root_id {
            use crate::schema::thread_subscriptions::dsl as ts_dsl;
            ts_dsl::thread_subscriptions
                .inner_join(
                    group_membership::table.on(gm_dsl::chat_id
                        .eq(ts_dsl::chat_id)
                        .and(gm_dsl::uid.eq(ts_dsl::uid))),
                )
                .filter(ts_dsl::thread_root_id.eq(thread_root_id))
                .select((ts_dsl::uid, group_membership::muted_until))
                .load(&mut conn)
                .map_err(|e| format!("Failed to load thread subscriber UIDs: {:?}", e))?
        } else {
            group_membership::table
                .filter(gm_dsl::chat_id.eq(job.chat_id))
                .select((group_membership::uid, group_membership::muted_until))
                .load(&mut conn)
                .map_err(|e| format!("Failed to load member UIDs: {:?}", e))?
        };

    // 2. Filter out the sender, muted users (unless mentioned), and users with fresh active app presence.
    let target_uids: Vec<i32> = members
        .into_iter()
        .filter(|(uid, _)| *uid != job.sender_uid)
        .filter(|(uid, muted_until)| {
            // Mentioned users bypass mute
            if job.mentioned_uids.contains(uid) {
                return true;
            }
            // Not muted, or mute has expired
            muted_until.is_none_or(|t| t <= now)
        })
        .map(|(uid, _)| uid)
        .filter(|&uid| {
            let suppress = ws_registry.should_suppress_push(uid, PUSH_SUPPRESSION_FRESHNESS_SECS);
            if suppress {
                service.metrics.record_push_suppressed();
            }
            !suppress
        })
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

    // 3.5 Calculate unread counts for target users
    let unread_counts = crate::services::chat::get_unread_counts(&mut conn, &target_uids)
        .unwrap_or_else(|e| {
            warn!("Failed to load unread counts for push job: {:?}", e);
            std::collections::HashMap::new()
        });

    // 4. Build the push payload base text.
    let body_text = format_push_body(&job.sender_username, job.legacy_message_preview.as_deref());

    // 5. Send concurrently with bounded parallelism.
    let stale_endpoints: Vec<String> = stream::iter(subs.into_iter())
        .map(|sub| {
            let service = service.clone();

            let unread = unread_counts.get(&sub.user_id).copied().unwrap_or(0);
            let payload = serde_json::to_vec(&build_push_payload(job, unread, &body_text))
                .unwrap_or_default();

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

fn build_push_payload(job: &PushJob, unread_count: i64, body_text: &str) -> PushPayload {
    PushPayload {
        type_: PushPayloadType::NewMessage,
        title: job.chat_name.clone(),
        body: body_text.to_string(),
        sender_name: job.sender_username.clone(),
        message_preview: job.message_preview.clone(),
        unread_count,
        data: PushPayloadData {
            chat_id: job.chat_id.to_string(),
            message_id: job.message_id.to_string(),
            thread_root_id: job.thread_root_id.map(|id| id.to_string()),
        },
    }
}

fn format_push_body(sender_username: &str, preview: Option<&str>) -> String {
    match preview {
        Some(preview) => format!("{}: {}", sender_username, truncate_preview(preview)),
        None => format!("{} sent a message", sender_username),
    }
}

fn truncate_preview(preview: &str) -> String {
    let truncated: String = preview.chars().take(MESSAGE_PREVIEW_MAX).collect();
    if preview.chars().count() > MESSAGE_PREVIEW_MAX {
        format!("{truncated}…")
    } else {
        truncated
    }
}

pub(crate) fn panic_payload_message(payload: &(dyn std::any::Any + Send)) -> String {
    if let Some(message) = payload.downcast_ref::<&'static str>() {
        (*message).to_string()
    } else if let Some(message) = payload.downcast_ref::<String>() {
        message.clone()
    } else {
        "non-string panic payload".to_string()
    }
}

#[cfg(test)]
fn maybe_panic_for_test(job: &PushJob) {
    if job.message_id == TEST_PANIC_MESSAGE_ID.load(std::sync::atomic::Ordering::SeqCst) {
        panic!("test-induced push worker panic");
    }
}

#[cfg(test)]
static TEST_PANIC_MESSAGE_ID: std::sync::atomic::AtomicI64 =
    std::sync::atomic::AtomicI64::new(i64::MIN);

pub(crate) async fn supervise_worker<F, Fut>(
    worker_name: &str,
    restart_delay: Duration,
    mut worker: F,
) where
    F: FnMut() -> Fut,
    Fut: std::future::Future<Output = ()>,
{
    loop {
        let worker_result = std::panic::AssertUnwindSafe(worker()).catch_unwind().await;

        match worker_result {
            Ok(()) => return,
            Err(payload) => {
                let panic_message = panic_payload_message(payload.as_ref());
                error!(
                    "{} panicked; restarting in {}s: {}",
                    worker_name,
                    restart_delay.as_secs_f32(),
                    panic_message
                );
                tokio::time::sleep(restart_delay).await;
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};

    #[test]
    fn truncate_preview_keeps_short_ascii() {
        assert_eq!(truncate_preview("hello"), "hello");
    }

    #[test]
    fn truncate_preview_adds_ellipsis_for_long_ascii() {
        let input = "a".repeat(MESSAGE_PREVIEW_MAX + 5);
        let expected = format!("{}…", "a".repeat(MESSAGE_PREVIEW_MAX));
        assert_eq!(truncate_preview(&input), expected);
    }

    #[test]
    fn truncate_preview_handles_multibyte_unicode_without_panicking() {
        let input = "不用注册tg之后感觉加群的奇怪的人会更多，感觉要考虑下禁止事项和惩罚措施了（）";
        assert_eq!(truncate_preview(input), input);
    }

    #[test]
    fn truncate_preview_exact_limit_has_no_ellipsis() {
        let input = "a".repeat(MESSAGE_PREVIEW_MAX);
        assert_eq!(truncate_preview(&input), input);
    }

    #[test]
    fn format_push_body_uses_fallback_for_missing_preview() {
        assert_eq!(format_push_body("alice", None), "alice sent a message");
    }

    #[test]
    fn build_push_payload_includes_structured_preview_and_legacy_body() {
        let job = PushJob {
            chat_id: 10,
            sender_uid: 42,
            sender_username: "alice".to_string(),
            chat_name: "General".to_string(),
            message_preview: PushMessagePreview {
                message: None,
                message_type: MessageType::Sticker,
                sticker: Some(PushMessagePreviewSticker {
                    emoji: "🙂".to_string(),
                }),
                first_attachment_kind: None,
                is_deleted: false,
            },
            legacy_message_preview: Some("[Sticker] 🙂".to_string()),
            message_id: 99,
            thread_root_id: None,
            mentioned_uids: Vec::new(),
        };

        let payload = build_push_payload(&job, 3, "alice: [Sticker] 🙂");
        assert_eq!(payload.sender_name, "alice");
        assert_eq!(payload.body, "alice: [Sticker] 🙂");
        assert_eq!(payload.message_preview.message_type, MessageType::Sticker);
        assert_eq!(
            payload.message_preview.sticker,
            Some(PushMessagePreviewSticker {
                emoji: "🙂".to_string(),
            })
        );
        assert_eq!(payload.data.chat_id, "10");
        assert_eq!(payload.data.message_id, "99");
        assert_eq!(payload.unread_count, 3);

        let serialized = serde_json::to_value(&payload).expect("serialize push payload");
        assert_eq!(serialized["type"], "newMessage");
        assert_eq!(serialized["senderName"], "alice");
        assert_eq!(serialized["messagePreview"]["messageType"], "sticker");
        assert_eq!(serialized["data"]["chatId"], "10");
        assert_eq!(serialized["data"]["messageId"], "99");
        assert!(serialized.get("sender_name").is_none());
        assert!(serialized["data"].get("chat_id").is_none());
    }

    #[tokio::test]
    async fn supervisor_restarts_after_panic() {
        let attempts = Arc::new(AtomicUsize::new(0));
        let worker_attempts = attempts.clone();
        let (done_tx, mut done_rx) = mpsc::channel::<usize>(1);

        tokio::spawn(async move {
            supervise_worker("test worker", Duration::from_millis(1), move || {
                let worker_attempts = worker_attempts.clone();
                let done_tx = done_tx.clone();
                async move {
                    let attempt = worker_attempts.fetch_add(1, Ordering::SeqCst) + 1;
                    if attempt == 1 {
                        panic!("boom");
                    }
                    done_tx.send(attempt).await.unwrap();
                }
            })
            .await;
        });

        let attempt = tokio::time::timeout(Duration::from_secs(1), done_rx.recv())
            .await
            .expect("supervisor should finish the restarted attempt")
            .expect("channel should remain open");

        assert_eq!(attempt, 2);
        assert_eq!(attempts.load(Ordering::SeqCst), 2);
    }
}
