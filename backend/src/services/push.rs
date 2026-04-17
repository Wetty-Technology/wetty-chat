use a2::{
    request::payload::PayloadLike, Client as ApnsClient, ClientConfig as ApnsClientConfig,
    DefaultNotificationBuilder, Endpoint as ApnsEndpoint, ErrorReason as ApnsErrorReason,
    NotificationBuilder, NotificationOptions, Priority as ApnsPriority, PushType as ApnsPushType,
};
use diesel::prelude::*;
use diesel::r2d2::{ConnectionManager, Pool};
use diesel::PgConnection;
use futures::future::FutureExt;
use futures::stream::{self, StreamExt};
use serde::Serialize;
use std::fs::File;
use std::sync::Arc;
use std::time::Duration;
use std::time::Instant;
use tokio::sync::mpsc;
use tracing::{debug, error, info, warn};
use web_push::{HyperWebPushClient, WebPushClient};

use crate::metrics::Metrics;
use crate::models::{MessageType, PushEnvironment, PushProvider, PushSubscription};
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
const APNS_TITLE_LOC_KEY: &str = "push.chat.title";
const APNS_BODY_LOC_KEY_WITH_PREVIEW: &str = "push.message.body";
const APNS_BODY_LOC_KEY_NO_PREVIEW: &str = "push.message.body.generic";
const APNS_CUSTOM_DATA_ROOT: &str = "wettyChat";
const APNS_BODY_LOC_KEY_AUDIO: &str = "push.message.body.audio";
const APNS_BODY_LOC_KEY_AUDIO_WITH_PREVIEW: &str = "push.message.body.audio.with_preview";
const APNS_BODY_LOC_KEY_IMAGE: &str = "push.message.body.image";
const APNS_BODY_LOC_KEY_IMAGE_WITH_PREVIEW: &str = "push.message.body.image.with_preview";
const APNS_BODY_LOC_KEY_VIDEO: &str = "push.message.body.video";
const APNS_BODY_LOC_KEY_VIDEO_WITH_PREVIEW: &str = "push.message.body.video.with_preview";
const APNS_BODY_LOC_KEY_STICKER: &str = "push.message.body.sticker";
const APNS_BODY_LOC_KEY_STICKER_EMOJI: &str = "push.message.body.sticker.emoji";
const APNS_BODY_LOC_KEY_INVITE: &str = "push.message.body.invite";
const APNS_BODY_LOC_KEY_ATTACHMENT: &str = "push.message.body.attachment";
const APNS_BODY_LOC_KEY_ATTACHMENT_WITH_PREVIEW: &str = "push.message.body.attachment.with_preview";
const APNS_BODY_LOC_KEY_DELETED: &str = "push.message.body.deleted";

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

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
struct ApnsCustomData {
    #[serde(rename = "type")]
    type_: PushPayloadType,
    chat_id: String,
    message_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    thread_root_id: Option<String>,
    sender_name: String,
    message_preview: PushMessagePreview,
    unread_count: i64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct ApnsNotification {
    title_loc_key: &'static str,
    title_loc_args: Vec<String>,
    body_loc_key: &'static str,
    body_loc_args: Vec<String>,
    badge: u32,
    thread_id: String,
    custom_data: ApnsCustomData,
}

/// Wraps an a2 `Payload` to inject `thread-id` into the APS dictionary.
/// The `a2` crate's APS struct does not support this field natively.
#[derive(Debug)]
struct PayloadWithThreadId<'a> {
    inner: a2::request::payload::Payload<'a>,
    thread_id: String,
}

impl serde::Serialize for PayloadWithThreadId<'_> {
    fn serialize<S: serde::Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        use serde::ser::Error as _;
        let mut value = serde_json::to_value(&self.inner).map_err(S::Error::custom)?;
        if let Some(aps) = value
            .as_object_mut()
            .and_then(|o| o.get_mut("aps"))
            .and_then(|v| v.as_object_mut())
        {
            aps.insert(
                "thread-id".to_string(),
                serde_json::Value::String(self.thread_id.clone()),
            );
        }
        value.serialize(serializer)
    }
}

impl PayloadLike for PayloadWithThreadId<'_> {
    fn get_device_token(&self) -> &str {
        self.inner.get_device_token()
    }
    fn get_options(&self) -> &NotificationOptions<'_> {
        self.inner.get_options()
    }
}

#[derive(Debug, Clone)]
pub struct PushJob {
    pub chat_id: i64,
    pub sender_uid: i32,
    pub sender_username: String,
    pub chat_name: String,
    pub message_preview: PushMessagePreview,
    pub body_preview: Option<String>,
    pub message_id: i64,
    pub thread_root_id: Option<i64>,
    pub mentioned_uids: Vec<i32>,
}

struct ApnsSender {
    sandbox_client: ApnsClient,
    production_client: ApnsClient,
    topic: String,
}

pub struct PushService {
    pub client: HyperWebPushClient,
    pub vapid_public_key: String,
    pub vapid_private_key: String,
    pub vapid_subject: String,
    apns_sender: Option<ApnsSender>,
    metrics: Arc<Metrics>,
    job_tx: mpsc::Sender<PushJob>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
enum SendFailure {
    Stale(i64),
    Transient,
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

        let apns_sender =
            ApnsSender::from_env().expect("invalid APNS configuration; set all vars or none");

        let (tx, rx) = mpsc::channel(CHANNEL_BUFFER);

        let service = Arc::new(Self {
            client: HyperWebPushClient::new(),
            vapid_public_key: public_key,
            vapid_private_key: private_key,
            vapid_subject: subject,
            apns_sender,
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

    pub fn supports_provider(&self, provider: &PushProvider) -> bool {
        match provider {
            PushProvider::WebPush => true,
            PushProvider::Apns => self.apns_sender.is_some(),
        }
    }

    /// Enqueue a push job. Non-blocking; logs a warning if the channel is full.
    pub fn enqueue(&self, job: PushJob) {
        if let Err(e) = self.job_tx.try_send(job) {
            warn!("Push job channel full, dropping notification: {}", e);
        }
    }

    async fn send_to_subscription(
        &self,
        sub: &PushSubscription,
        web_payload: &[u8],
        apns_notification: &ApnsNotification,
    ) -> Result<(), SendFailure> {
        match sub.provider {
            PushProvider::WebPush => self.send_web_push(sub, web_payload).await,
            PushProvider::Apns => self.send_apns_push(sub, apns_notification).await,
        }
    }

    async fn send_web_push(
        &self,
        sub: &PushSubscription,
        payload: &[u8],
    ) -> Result<(), SendFailure> {
        let endpoint = match &sub.endpoint {
            Some(endpoint) => endpoint.clone(),
            None => {
                self.metrics
                    .record_push_notification(PushProvider::WebPush.as_metrics_label(), false);
                warn!("web push subscription {} missing endpoint", sub.id);
                return Err(SendFailure::Stale(sub.id));
            }
        };
        let data = match sub.web_push_data() {
            Ok(data) => data,
            Err(e) => {
                self.metrics
                    .record_push_notification(PushProvider::WebPush.as_metrics_label(), false);
                warn!(
                    "web push subscription {} has invalid provider data: {:?}",
                    sub.id, e
                );
                return Err(SendFailure::Stale(sub.id));
            }
        };

        let subscription_info =
            web_push::SubscriptionInfo::new(endpoint.clone(), data.p256dh, data.auth);

        let sig_builder =
            match web_push::VapidSignatureBuilder::from_base64_no_sub(&self.vapid_private_key) {
                Ok(b) => b,
                Err(e) => {
                    error!(
                        "Vapid config error (should have been caught on startup): {:?}",
                        e
                    );
                    self.metrics
                        .record_push_notification(PushProvider::WebPush.as_metrics_label(), false);
                    return Err(SendFailure::Transient);
                }
            };

        let mut b = sig_builder.add_sub_info(&subscription_info);
        b.add_claim("sub", self.vapid_subject.clone());
        let signature = match b.build() {
            Ok(sig) => sig,
            Err(e) => {
                error!("Failed to build VAPID signature: {:?}", e);
                self.metrics
                    .record_push_notification(PushProvider::WebPush.as_metrics_label(), false);
                return Err(SendFailure::Transient);
            }
        };

        let mut builder = web_push::WebPushMessageBuilder::new(&subscription_info);
        builder.set_payload(web_push::ContentEncoding::Aes128Gcm, payload);
        builder.set_vapid_signature(signature);

        match builder.build() {
            Ok(message) => match self.client.send(message).await {
                Ok(_) => {
                    self.metrics
                        .record_push_notification(PushProvider::WebPush.as_metrics_label(), true);
                    Ok(())
                }
                Err(e) => {
                    self.metrics
                        .record_push_notification(PushProvider::WebPush.as_metrics_label(), false);
                    if matches!(
                        e,
                        web_push::WebPushError::EndpointNotValid(_)
                            | web_push::WebPushError::EndpointNotFound(_)
                    ) {
                        warn!("stale web push subscription for endpoint {}", endpoint);
                        Err(SendFailure::Stale(sub.id))
                    } else {
                        error!("Failed to send web push notification: {:?}", e);
                        Err(SendFailure::Transient)
                    }
                }
            },
            Err(e) => {
                error!("Failed to build web push message: {:?}", e);
                self.metrics
                    .record_push_notification(PushProvider::WebPush.as_metrics_label(), false);
                Err(SendFailure::Transient)
            }
        }
    }

    async fn send_apns_push(
        &self,
        sub: &PushSubscription,
        notification: &ApnsNotification,
    ) -> Result<(), SendFailure> {
        let sender = match &self.apns_sender {
            Some(sender) => sender,
            None => {
                warn!(
                    "received APNs subscription {} without APNs sender configured",
                    sub.id
                );
                self.metrics
                    .record_push_notification(PushProvider::Apns.as_metrics_label(), false);
                return Err(SendFailure::Transient);
            }
        };
        let device_token = match &sub.device_token {
            Some(token) => token.as_str(),
            None => {
                warn!("APNs subscription {} missing device token", sub.id);
                self.metrics
                    .record_push_notification(PushProvider::Apns.as_metrics_label(), false);
                return Err(SendFailure::Stale(sub.id));
            }
        };
        if let Err(e) = sub.apns_data() {
            warn!(
                "APNs subscription {} has invalid provider data: {:?}",
                sub.id, e
            );
            self.metrics
                .record_push_notification(PushProvider::Apns.as_metrics_label(), false);
            return Err(SendFailure::Stale(sub.id));
        }
        let environment = match sub.apns_environment {
            Some(environment) => environment,
            None => {
                warn!("APNs subscription {} missing environment", sub.id);
                self.metrics
                    .record_push_notification(PushProvider::Apns.as_metrics_label(), false);
                return Err(SendFailure::Stale(sub.id));
            }
        };

        match sender.send(device_token, &environment, notification).await {
            Ok(()) => {
                self.metrics
                    .record_push_notification(PushProvider::Apns.as_metrics_label(), true);
                Ok(())
            }
            Err(ApnsSendError::Stale(reason)) => {
                warn!(
                    "stale APNs subscription {} for token {}: {:?}",
                    sub.id, device_token, reason
                );
                self.metrics
                    .record_push_notification(PushProvider::Apns.as_metrics_label(), false);
                Err(SendFailure::Stale(sub.id))
            }
            Err(ApnsSendError::Transient(reason)) => {
                error!(
                    "failed to send APNs notification for subscription {}: {}",
                    sub.id, reason
                );
                self.metrics
                    .record_push_notification(PushProvider::Apns.as_metrics_label(), false);
                Err(SendFailure::Transient)
            }
        }
    }
}

#[derive(Debug)]
enum ApnsSendError {
    Stale(ApnsErrorReason),
    Transient(String),
}

impl ApnsSender {
    fn from_env() -> Result<Option<Self>, String> {
        let key_id = std::env::var("APNS_KEY_ID").ok();
        let team_id = std::env::var("APNS_TEAM_ID").ok();
        let private_key_path = std::env::var("APNS_PRIVATE_KEY_PATH").ok();
        let topic = std::env::var("APNS_TOPIC").ok();

        if key_id.is_none() && team_id.is_none() && private_key_path.is_none() && topic.is_none() {
            return Ok(None);
        }

        let key_id = key_id.ok_or_else(|| "APNS_KEY_ID must be set".to_string())?;
        let team_id = team_id.ok_or_else(|| "APNS_TEAM_ID must be set".to_string())?;
        let private_key_path =
            private_key_path.ok_or_else(|| "APNS_PRIVATE_KEY_PATH must be set".to_string())?;
        let topic = topic.ok_or_else(|| "APNS_TOPIC must be set".to_string())?;

        let sandbox_client =
            Self::build_client(&private_key_path, &key_id, &team_id, ApnsEndpoint::Sandbox)?;
        let production_client = Self::build_client(
            &private_key_path,
            &key_id,
            &team_id,
            ApnsEndpoint::Production,
        )?;

        Ok(Some(Self {
            sandbox_client,
            production_client,
            topic,
        }))
    }

    fn build_client(
        private_key_path: &str,
        key_id: &str,
        team_id: &str,
        endpoint: ApnsEndpoint,
    ) -> Result<ApnsClient, String> {
        let mut file = File::open(private_key_path)
            .map_err(|e| format!("failed to open APNS private key: {:?}", e))?;
        let config = ApnsClientConfig {
            endpoint,
            ..Default::default()
        };
        ApnsClient::token(&mut file, key_id, team_id, config)
            .map_err(|e| format!("failed to initialize APNS client: {:?}", e))
    }

    async fn send(
        &self,
        device_token: &str,
        environment: &PushEnvironment,
        notification: &ApnsNotification,
    ) -> Result<(), ApnsSendError> {
        let title_loc_args = [notification.title_loc_args[0].as_str()];
        let body_loc_args: Vec<&str> = notification
            .body_loc_args
            .iter()
            .map(String::as_str)
            .collect();
        let builder = DefaultNotificationBuilder::new()
            .set_title_loc_key(notification.title_loc_key)
            .set_title_loc_args(&title_loc_args)
            .set_loc_key(notification.body_loc_key)
            .set_loc_args(&body_loc_args)
            .set_badge(notification.badge)
            .set_sound("default");
        let options = NotificationOptions {
            apns_push_type: Some(ApnsPushType::Alert),
            apns_priority: Some(ApnsPriority::High),
            apns_topic: Some(self.topic.as_str()),
            ..Default::default()
        };

        let mut inner_payload = builder.build(device_token, options);
        inner_payload
            .add_custom_data(APNS_CUSTOM_DATA_ROOT, &notification.custom_data)
            .map_err(|e| {
                ApnsSendError::Transient(format!("failed to serialize APNs payload: {:?}", e))
            })?;
        let payload = PayloadWithThreadId {
            inner: inner_payload,
            thread_id: notification.thread_id.clone(),
        };

        let client = match environment {
            PushEnvironment::Sandbox => &self.sandbox_client,
            PushEnvironment::Production => &self.production_client,
        };
        let response = client
            .send(payload)
            .await
            .map_err(|e| ApnsSendError::Transient(format!("{:?}", e)))?;

        if response.code == 200 {
            Ok(())
        } else if let Some(error) = response.error {
            if is_stale_apns_error_reason(&error.reason) {
                Err(ApnsSendError::Stale(error.reason))
            } else {
                Err(ApnsSendError::Transient(format!("{:?}", error.reason)))
            }
        } else {
            Err(ApnsSendError::Transient(format!(
                "APNs request failed with status {}",
                response.code
            )))
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
                .filter(ts_dsl::archived.eq(false))
                .filter(gm_dsl::archived.eq(false))
                .select((ts_dsl::uid, group_membership::muted_until))
                .load(&mut conn)
                .map_err(|e| format!("Failed to load thread subscriber UIDs: {:?}", e))?
        } else {
            group_membership::table
                .filter(gm_dsl::chat_id.eq(job.chat_id))
                .filter(gm_dsl::archived.eq(false))
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

    // 3.5 Calculate unread counts only for users with push subscriptions
    let sub_uids: Vec<i32> = {
        let mut seen = std::collections::HashSet::with_capacity(subs.len());
        subs.iter()
            .filter_map(|s| seen.insert(s.user_id).then_some(s.user_id))
            .collect()
    };
    let unread_counts = crate::services::chat::get_unread_counts(&mut conn, &sub_uids)
        .unwrap_or_else(|e| {
            warn!("Failed to load unread counts for push job: {:?}", e);
            std::collections::HashMap::new()
        });

    // 4. Build the push payload base text.
    let body_text = format_push_body(&job.sender_username, job.body_preview.as_deref());

    // 5. Send concurrently with bounded parallelism.
    let stale_ids: Vec<i64> = stream::iter(subs.into_iter())
        .map(|sub| {
            let service = service.clone();

            let unread = unread_counts.get(&sub.user_id).copied().unwrap_or(0);
            let web_payload = serde_json::to_vec(&build_push_payload(job, unread, &body_text))
                .unwrap_or_default();
            let apns_notification = build_apns_notification(job, unread);

            async move {
                match service
                    .send_to_subscription(&sub, &web_payload, &apns_notification)
                    .await
                {
                    Ok(()) => None,
                    Err(SendFailure::Stale(id)) => Some(id),
                    Err(SendFailure::Transient) => None,
                }
            }
        })
        .buffer_unordered(PUSH_CONCURRENCY)
        .filter_map(|result| async move { result })
        .collect()
        .await;

    // 6. Clean up stale subscriptions.
    if !stale_ids.is_empty() {
        debug!("Cleaning up {} stale push subscriptions", stale_ids.len());
        let _ = diesel::delete(
            push_subscriptions::table.filter(push_subscriptions::dsl::id.eq_any(&stale_ids)),
        )
        .execute(&mut conn)
        .map_err(|e| {
            error!("Failed to clean up stale push subscriptions: {:?}", e);
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

fn build_apns_notification(job: &PushJob, unread_count: i64) -> ApnsNotification {
    let badge = unread_count.clamp(0, u32::MAX as i64) as u32;
    let preview = &job.message_preview;

    let (body_loc_key, body_loc_args) = if preview.is_deleted {
        (APNS_BODY_LOC_KEY_DELETED, vec![job.sender_username.clone()])
    } else {
        match preview.message_type {
            MessageType::Audio => (APNS_BODY_LOC_KEY_AUDIO, vec![job.sender_username.clone()]),
            MessageType::Sticker => match &preview.sticker {
                Some(s) if !s.emoji.trim().is_empty() => (
                    APNS_BODY_LOC_KEY_STICKER_EMOJI,
                    vec![job.sender_username.clone(), s.emoji.clone()],
                ),
                _ => (APNS_BODY_LOC_KEY_STICKER, vec![job.sender_username.clone()]),
            },
            MessageType::Invite => (APNS_BODY_LOC_KEY_INVITE, vec![job.sender_username.clone()]),
            _ => {
                if let Some(ref kind) = preview.first_attachment_kind {
                    if let Some(ref msg) = preview.message {
                        (
                            attachment_kind_loc_key_with_preview(kind),
                            vec![job.sender_username.clone(), truncate_preview(msg)],
                        )
                    } else {
                        (
                            attachment_kind_loc_key(kind),
                            vec![job.sender_username.clone()],
                        )
                    }
                } else if let Some(ref msg) = preview.message {
                    (
                        APNS_BODY_LOC_KEY_WITH_PREVIEW,
                        vec![job.sender_username.clone(), truncate_preview(msg)],
                    )
                } else {
                    (
                        APNS_BODY_LOC_KEY_NO_PREVIEW,
                        vec![job.sender_username.clone()],
                    )
                }
            }
        }
    };

    let thread_id = match job.thread_root_id {
        Some(root_id) => format!("chat_{}_thread_{}", job.chat_id, root_id),
        None => format!("chat_{}", job.chat_id),
    };

    ApnsNotification {
        title_loc_key: APNS_TITLE_LOC_KEY,
        title_loc_args: vec![job.chat_name.clone()],
        body_loc_key,
        body_loc_args,
        badge,
        thread_id,
        custom_data: ApnsCustomData {
            type_: PushPayloadType::NewMessage,
            chat_id: job.chat_id.to_string(),
            message_id: job.message_id.to_string(),
            thread_root_id: job.thread_root_id.map(|id| id.to_string()),
            sender_name: job.sender_username.clone(),
            message_preview: job.message_preview.clone(),
            unread_count,
        },
    }
}

fn attachment_kind_loc_key(kind: &str) -> &'static str {
    if kind.starts_with("image/") {
        APNS_BODY_LOC_KEY_IMAGE
    } else if kind.starts_with("video/") {
        APNS_BODY_LOC_KEY_VIDEO
    } else if kind.starts_with("audio/") {
        APNS_BODY_LOC_KEY_AUDIO
    } else {
        APNS_BODY_LOC_KEY_ATTACHMENT
    }
}

fn attachment_kind_loc_key_with_preview(kind: &str) -> &'static str {
    if kind.starts_with("image/") {
        APNS_BODY_LOC_KEY_IMAGE_WITH_PREVIEW
    } else if kind.starts_with("video/") {
        APNS_BODY_LOC_KEY_VIDEO_WITH_PREVIEW
    } else if kind.starts_with("audio/") {
        APNS_BODY_LOC_KEY_AUDIO_WITH_PREVIEW
    } else {
        APNS_BODY_LOC_KEY_ATTACHMENT_WITH_PREVIEW
    }
}

fn is_stale_apns_error_reason(reason: &ApnsErrorReason) -> bool {
    matches!(
        reason,
        ApnsErrorReason::BadDeviceToken
            | ApnsErrorReason::DeviceTokenNotForTopic
            | ApnsErrorReason::Unregistered
    )
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
            body_preview: Some("[Sticker] 🙂".to_string()),
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

    #[test]
    fn build_apns_notification_uses_localized_keys_and_custom_data() {
        let job = PushJob {
            chat_id: 10,
            sender_uid: 42,
            sender_username: "alice".to_string(),
            chat_name: "General".to_string(),
            message_preview: PushMessagePreview {
                message: Some("Hello".to_string()),
                message_type: MessageType::Text,
                sticker: None,
                first_attachment_kind: None,
                is_deleted: false,
            },
            body_preview: Some("hello there".to_string()),
            message_id: 99,
            thread_root_id: Some(77),
            mentioned_uids: Vec::new(),
        };

        let n = build_apns_notification(&job, 7);
        assert_eq!(n.title_loc_key, APNS_TITLE_LOC_KEY);
        assert_eq!(n.title_loc_args, vec!["General".to_string()]);
        assert_eq!(n.body_loc_key, APNS_BODY_LOC_KEY_WITH_PREVIEW);
        assert_eq!(
            n.body_loc_args,
            vec!["alice".to_string(), "Hello".to_string()]
        );
        assert_eq!(n.badge, 7);
        assert_eq!(n.thread_id, "chat_10_thread_77");
        assert_eq!(n.custom_data.chat_id, "10");
        assert_eq!(n.custom_data.thread_root_id, Some("77".to_string()));
        assert_eq!(n.custom_data.unread_count, 7);
    }

    #[test]
    fn build_apns_notification_falls_back_when_preview_missing() {
        let job = PushJob {
            chat_id: 10,
            sender_uid: 42,
            sender_username: "alice".to_string(),
            chat_name: "General".to_string(),
            message_preview: PushMessagePreview {
                message: None,
                message_type: MessageType::Text,
                sticker: None,
                first_attachment_kind: None,
                is_deleted: false,
            },
            body_preview: None,
            message_id: 99,
            thread_root_id: None,
            mentioned_uids: Vec::new(),
        };

        let payload = build_apns_notification(&job, 0);
        assert_eq!(payload.body_loc_key, APNS_BODY_LOC_KEY_NO_PREVIEW);
        assert_eq!(payload.body_loc_args, vec!["alice".to_string()]);
        assert_eq!(payload.badge, 0);
        assert_eq!(payload.thread_id, "chat_10");
    }

    #[test]
    fn build_apns_notification_audio_message() {
        let job = PushJob {
            chat_id: 5,
            sender_uid: 1,
            sender_username: "bob".to_string(),
            chat_name: "DMs".to_string(),
            message_preview: PushMessagePreview {
                message: None,
                message_type: MessageType::Audio,
                sticker: None,
                first_attachment_kind: None,
                is_deleted: false,
            },
            body_preview: None,
            message_id: 50,
            thread_root_id: None,
            mentioned_uids: Vec::new(),
        };

        let n = build_apns_notification(&job, 2);
        assert_eq!(n.body_loc_key, APNS_BODY_LOC_KEY_AUDIO);
        assert_eq!(n.body_loc_args, vec!["bob".to_string()]);
    }

    #[test]
    fn build_apns_notification_sticker_with_emoji() {
        let job = PushJob {
            chat_id: 5,
            sender_uid: 1,
            sender_username: "bob".to_string(),
            chat_name: "DMs".to_string(),
            message_preview: PushMessagePreview {
                message: None,
                message_type: MessageType::Sticker,
                sticker: Some(PushMessagePreviewSticker {
                    emoji: "🎉".to_string(),
                }),
                first_attachment_kind: None,
                is_deleted: false,
            },
            body_preview: Some("[Sticker] 🎉".to_string()),
            message_id: 51,
            thread_root_id: None,
            mentioned_uids: Vec::new(),
        };

        let n = build_apns_notification(&job, 0);
        assert_eq!(n.body_loc_key, APNS_BODY_LOC_KEY_STICKER_EMOJI);
        assert_eq!(n.body_loc_args, vec!["bob".to_string(), "🎉".to_string()]);
    }

    #[test]
    fn build_apns_notification_image_attachment() {
        let job = PushJob {
            chat_id: 5,
            sender_uid: 1,
            sender_username: "bob".to_string(),
            chat_name: "DMs".to_string(),
            message_preview: PushMessagePreview {
                message: None,
                message_type: MessageType::File,
                sticker: None,
                first_attachment_kind: Some("image/jpeg".to_string()),
                is_deleted: false,
            },
            body_preview: None,
            message_id: 52,
            thread_root_id: None,
            mentioned_uids: Vec::new(),
        };

        let n = build_apns_notification(&job, 1);
        assert_eq!(n.body_loc_key, APNS_BODY_LOC_KEY_IMAGE);
        assert_eq!(n.body_loc_args, vec!["bob".to_string()]);
    }

    #[test]
    fn build_apns_notification_prefers_attachment_key_over_caption_preview() {
        let job = PushJob {
            chat_id: 5,
            sender_uid: 1,
            sender_username: "bob".to_string(),
            chat_name: "DMs".to_string(),
            message_preview: PushMessagePreview {
                message: Some("look at this".to_string()),
                message_type: MessageType::File,
                sticker: None,
                first_attachment_kind: Some("image/jpeg".to_string()),
                is_deleted: false,
            },
            body_preview: Some("[Image]".to_string()),
            message_id: 54,
            thread_root_id: None,
            mentioned_uids: Vec::new(),
        };

        let n = build_apns_notification(&job, 0);
        assert_eq!(n.body_loc_key, APNS_BODY_LOC_KEY_IMAGE_WITH_PREVIEW);
        assert_eq!(
            n.body_loc_args,
            vec!["bob".to_string(), "look at this".to_string()]
        );
    }

    #[test]
    fn build_apns_notification_video_attachment() {
        let job = PushJob {
            chat_id: 5,
            sender_uid: 1,
            sender_username: "bob".to_string(),
            chat_name: "DMs".to_string(),
            message_preview: PushMessagePreview {
                message: None,
                message_type: MessageType::File,
                sticker: None,
                first_attachment_kind: Some("video/mp4".to_string()),
                is_deleted: false,
            },
            body_preview: None,
            message_id: 53,
            thread_root_id: None,
            mentioned_uids: Vec::new(),
        };

        let n = build_apns_notification(&job, 0);
        assert_eq!(n.body_loc_key, APNS_BODY_LOC_KEY_VIDEO);
    }

    #[test]
    fn build_apns_notification_invite() {
        let job = PushJob {
            chat_id: 5,
            sender_uid: 1,
            sender_username: "bob".to_string(),
            chat_name: "DMs".to_string(),
            message_preview: PushMessagePreview {
                message: None,
                message_type: MessageType::Invite,
                sticker: None,
                first_attachment_kind: None,
                is_deleted: false,
            },
            body_preview: Some("sent an invite".to_string()),
            message_id: 54,
            thread_root_id: None,
            mentioned_uids: Vec::new(),
        };

        let n = build_apns_notification(&job, 0);
        assert_eq!(n.body_loc_key, APNS_BODY_LOC_KEY_INVITE);
        assert_eq!(n.body_loc_args, vec!["bob".to_string()]);
    }

    #[test]
    fn stale_apns_error_reason_classification_matches_expected_errors() {
        assert!(is_stale_apns_error_reason(&ApnsErrorReason::BadDeviceToken));
        assert!(is_stale_apns_error_reason(
            &ApnsErrorReason::DeviceTokenNotForTopic
        ));
        assert!(is_stale_apns_error_reason(&ApnsErrorReason::Unregistered));
        assert!(!is_stale_apns_error_reason(
            &ApnsErrorReason::TooManyRequests
        ));
        assert!(!is_stale_apns_error_reason(
            &ApnsErrorReason::InternalServerError
        ));
    }

    #[test]
    fn apns_support_requires_sender_configuration() {
        let service = PushService {
            client: HyperWebPushClient::new(),
            vapid_public_key: "public".to_string(),
            vapid_private_key: "private".to_string(),
            vapid_subject: "mailto:test@example.com".to_string(),
            apns_sender: None,
            metrics: Arc::new(Metrics::new()),
            job_tx: mpsc::channel(1).0,
        };

        assert!(service.supports_provider(&PushProvider::WebPush));
        assert!(!service.supports_provider(&PushProvider::Apns));
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
            .expect("channel should receive attempt number");
        assert_eq!(attempt, 2);
    }
}
