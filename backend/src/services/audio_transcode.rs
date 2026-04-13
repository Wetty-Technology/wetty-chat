use std::path::{Path, PathBuf};
use std::sync::OnceLock;

use aws_sdk_s3::primitives::ByteStream;
use chrono::Utc;
use dashmap::DashSet;
use diesel::prelude::*;
use diesel::PgConnection;
use tokio::sync::Semaphore;
use tokio::task::JoinHandle;
use uuid::Uuid;

use crate::errors::AppError;
use crate::handlers::chats::{
    attach_metadata, build_message_side_effects, recalculate_group_last_message,
};
use crate::handlers::ws::messages::ServerWsMessage;
use crate::models::{Attachment, Message, MessageType, NewAttachment, TranscodeStatus};
use crate::schema::{attachments, messages};
use crate::services::media::{build_storage_key, upload_public_object};
use crate::AppState;

fn inflight() -> &'static DashSet<i64> {
    static INFLIGHT: OnceLock<DashSet<i64>> = OnceLock::new();
    INFLIGHT.get_or_init(DashSet::new)
}

fn processing_semaphore() -> &'static Semaphore {
    static PROCESSING_SEMAPHORE: OnceLock<Semaphore> = OnceLock::new();
    PROCESSING_SEMAPHORE.get_or_init(|| Semaphore::new(4))
}

pub fn start(state: AppState) -> JoinHandle<()> {
    tokio::spawn(async move { scan_and_enqueue(state.clone()).await })
}

pub fn enqueue_message(state: AppState, message_id: i64) {
    if inflight().insert(message_id) {
        tokio::spawn(async move {
            let _permit = processing_semaphore()
                .acquire()
                .await
                .expect("audio transcode semaphore should not be closed");
            tracing::debug!(message_id, "audio transcode processing started");
            if let Err(err) = process_message(state.clone(), message_id).await {
                tracing::warn!(message_id, ?err, "audio transcode processing failed");
            }
            inflight().remove(&message_id);
        });
    }
}

async fn scan_and_enqueue(state: AppState) {
    let mut conn = match state.db.get() {
        Ok(conn) => conn,
        Err(err) => {
            tracing::error!(
                ?err,
                "audio transcode scan: failed to acquire db connection"
            );
            return;
        }
    };
    let conn = &mut *conn;

    use crate::schema::messages::dsl as m_dsl;

    let legacy_ids: Vec<i64> = match messages::table
        .filter(m_dsl::message_type.eq(MessageType::Audio))
        .filter(m_dsl::deleted_at.is_null())
        .filter(m_dsl::is_published.eq(true))
        .filter(m_dsl::transcode_status.eq(TranscodeStatus::None))
        .select(m_dsl::id)
        .limit(200)
        .load(conn)
    {
        Ok(ids) => ids,
        Err(err) => {
            tracing::error!(
                ?err,
                "audio transcode scan: failed to load legacy audio ids"
            );
            return;
        }
    };

    if !legacy_ids.is_empty() {
        if let Err(err) = diesel::update(messages::table.filter(m_dsl::id.eq_any(&legacy_ids)))
            .set(m_dsl::transcode_status.eq(TranscodeStatus::Pending))
            .execute(conn)
        {
            tracing::error!(
                ?err,
                "audio transcode scan: failed to mark legacy rows pending"
            );
            return;
        }
    }

    let pending_ids: Vec<i64> = match messages::table
        .filter(m_dsl::message_type.eq(MessageType::Audio))
        .filter(m_dsl::deleted_at.is_null())
        .filter(m_dsl::transcode_status.eq(TranscodeStatus::Pending))
        .select(m_dsl::id)
        .limit(200)
        .load(conn)
    {
        Ok(ids) => ids,
        Err(err) => {
            tracing::error!(
                ?err,
                "audio transcode scan: failed to load pending audio ids"
            );
            return;
        }
    };

    for message_id in pending_ids {
        tracing::debug!(
            message_id,
            "audio transcode startup backlog: queued pending audio message"
        );
        enqueue_message(state.clone(), message_id);
    }
}

async fn process_message(state: AppState, message_id: i64) -> Result<(), AppError> {
    let started_at = std::time::Instant::now();
    let (message, current_attachment) = {
        let conn = &mut state.db.get()?;
        let message: Message = messages::table
            .filter(messages::id.eq(message_id))
            .select(Message::as_select())
            .first(conn)
            .optional()?
            .ok_or(AppError::NotFound("Message not found"))?;
        let current_attachment = load_primary_attachment(conn, message.id)?;
        (message, current_attachment)
    };

    if message.deleted_at.is_some() || message.message_type != MessageType::Audio {
        return Ok(());
    }
    if matches!(
        message.transcode_status,
        TranscodeStatus::Done | TranscodeStatus::Failed
    ) {
        return Ok(());
    }

    let was_published = message.is_published;
    if let Some(ref attachment) = current_attachment {
        state
            .metrics
            .record_audio_transcode_source(&attachment.kind);
    }
    let mut metric_guard = AudioTranscodeMetricGuard::new(state.clone(), started_at);

    let outcome = match current_attachment {
        Some(ref attachment) if is_canonical_attachment(attachment) => AudioPublishOutcome::Done {
            swap_attachment: None,
        },
        Some(ref attachment) => match transcode_attachment(&state, attachment).await {
            Ok(new_attachment) => AudioPublishOutcome::Done {
                swap_attachment: Some(new_attachment),
            },
            Err(err) => {
                tracing::warn!(message_id, attachment_id = attachment.id, error = %err, "audio transcode failed, publishing original attachment");
                AudioPublishOutcome::Failed
            }
        },
        None => {
            tracing::warn!(
                message_id,
                "audio message has no attachment, publishing original state"
            );
            AudioPublishOutcome::Failed
        }
    };

    let updated_message = {
        let conn = &mut state.db.get()?;
        conn.transaction::<_, AppError, _>(|conn| {
            use crate::schema::attachments::dsl as a_dsl;
            use crate::schema::messages::dsl as m_dsl;

            if let AudioPublishOutcome::Done {
                swap_attachment: Some(ref new_attachment),
            } = outcome
            {
                let mut linked_attachment = new_attachment.clone();
                linked_attachment.message_id = Some(message.id);

                diesel::update(attachments::table.filter(a_dsl::message_id.eq(message.id)))
                    .set(a_dsl::message_id.eq::<Option<i64>>(None))
                    .execute(conn)?;

                diesel::insert_into(attachments::table)
                    .values(&linked_attachment)
                    .execute(conn)?;
            }

            let updated_message: Message =
                diesel::update(messages::table.filter(m_dsl::id.eq(message.id)))
                    .set((
                        m_dsl::is_published.eq(true),
                        m_dsl::transcode_status.eq(match outcome {
                            AudioPublishOutcome::Done { .. } => TranscodeStatus::Done,
                            AudioPublishOutcome::Failed => TranscodeStatus::Failed,
                        }),
                    ))
                    .returning(Message::as_returning())
                    .get_result(conn)?;

            if !was_published && updated_message.reply_root_id.is_none() {
                recalculate_group_last_message(conn, updated_message.chat_id)?;
            }

            if !was_published {
                if let Some(reply_root_id) = updated_message.reply_root_id {
                    crate::services::threads::increment_thread_meta(
                        conn,
                        updated_message.chat_id,
                        reply_root_id,
                        updated_message.created_at,
                    )?;
                    diesel::update(messages::table.filter(m_dsl::id.eq(reply_root_id)))
                        .set(m_dsl::has_thread.eq(true))
                        .execute(conn)?;
                }
            }

            Ok(updated_message)
        })?
    };

    let conn = &mut state.db.get()?;
    let response = attach_metadata(conn, vec![updated_message], &state, message.sender_uid)
        .await
        .into_iter()
        .next()
        .ok_or(AppError::Internal("Failed to build message response"))?;

    if was_published {
        if matches!(
            outcome,
            AudioPublishOutcome::Done {
                swap_attachment: Some(_)
            }
        ) {
            broadcast_message_update(&state, &response);
        }
        metric_guard.finish(outcome.metrics_label());
        log_audio_transcode_job(
            &message,
            current_attachment.as_ref(),
            &outcome,
            started_at.elapsed(),
        );
        return Ok(());
    }

    let conn = &mut state.db.get()?;
    let side_effects = build_message_side_effects(
        conn,
        &response,
        &state,
        message.sender_uid,
        message.chat_id,
        true,
    )?;
    let member_uids = side_effects.broadcast_uids.clone();
    side_effects.fire(&state);

    if let Some(thread_root_id) = response.reply_root_id {
        if let Some(root_msg) = messages::table
            .filter(messages::id.eq(thread_root_id))
            .filter(messages::deleted_at.is_null())
            .filter(messages::is_published.eq(true))
            .select(Message::as_select())
            .first(conn)
            .optional()?
        {
            let root_response = attach_metadata(conn, vec![root_msg], &state, message.sender_uid)
                .await
                .into_iter()
                .next()
                .ok_or(AppError::Internal("Failed to build thread root response"))?;
            let ws_msg = std::sync::Arc::new(ServerWsMessage::MessageUpdated(root_response));
            state.ws_registry.broadcast_to_uids(&member_uids, ws_msg);
        }

        if let Err(err) = crate::services::threads::broadcast_thread_update_to_subscribers(
            conn,
            &state.ws_registry,
            message.chat_id,
            thread_root_id,
        ) {
            tracing::warn!(
                chat_id = message.chat_id,
                thread_root_id,
                ?err,
                "failed to broadcast thread update after audio publish"
            );
        }
    }

    metric_guard.finish(outcome.metrics_label());
    log_audio_transcode_job(
        &message,
        current_attachment.as_ref(),
        &outcome,
        started_at.elapsed(),
    );

    Ok(())
}

fn broadcast_message_update(state: &AppState, response: &crate::handlers::chats::MessageResponse) {
    let mut conn = match state.db.get() {
        Ok(conn) => conn,
        Err(err) => {
            tracing::error!(
                ?err,
                message_id = response.id,
                "failed to acquire db connection for message update broadcast"
            );
            return;
        }
    };
    let conn = &mut *conn;
    let member_uids: Vec<i32> = match crate::schema::group_membership::table
        .filter(crate::schema::group_membership::chat_id.eq(response.chat_id))
        .select(crate::schema::group_membership::uid)
        .load(conn)
    {
        Ok(uids) => uids,
        Err(err) => {
            tracing::error!(
                ?err,
                message_id = response.id,
                "failed to load member uids for message update broadcast"
            );
            return;
        }
    };
    let ws_msg = std::sync::Arc::new(ServerWsMessage::MessageUpdated(response.clone()));
    state.ws_registry.broadcast_to_uids(&member_uids, ws_msg);
}

fn load_primary_attachment(
    conn: &mut PgConnection,
    message_id: i64,
) -> Result<Option<Attachment>, AppError> {
    use crate::schema::attachments::dsl as a_dsl;

    attachments::table
        .filter(a_dsl::message_id.eq(message_id))
        .filter(a_dsl::deleted_at.is_null())
        .order((a_dsl::order.asc(), a_dsl::id.asc()))
        .select(Attachment::as_select())
        .first(conn)
        .optional()
        .map_err(Into::into)
}

fn is_canonical_attachment(attachment: &Attachment) -> bool {
    attachment.kind == "audio/ogg"
        && Path::new(&attachment.file_name)
            .extension()
            .and_then(|ext| ext.to_str())
            .is_some_and(|ext| ext.eq_ignore_ascii_case("ogg"))
}

async fn transcode_attachment(
    state: &AppState,
    attachment: &Attachment,
) -> Result<NewAttachment, String> {
    let object = state
        .s3_client
        .get_object()
        .bucket(&state.s3_bucket_name)
        .key(&attachment.external_reference)
        .send()
        .await
        .map_err(|err| format!("download source object: {err:?}"))?;

    let source_bytes = object
        .body
        .collect()
        .await
        .map_err(|err| format!("read source object: {err:?}"))?
        .into_bytes();

    let output_bytes = transcode_with_ffmpeg(&attachment.file_name, source_bytes.to_vec()).await?;

    let object_id = Uuid::new_v4().to_string();
    let canonical_file_name = canonical_file_name(&attachment.file_name);
    let storage_key = build_storage_key(
        &state.s3_attachment_prefix,
        &canonical_file_name,
        &object_id,
    );
    upload_public_object(
        &state.s3_client,
        &state.s3_bucket_name,
        &storage_key,
        "audio/ogg",
        ByteStream::from(output_bytes.clone()),
    )
    .await
    .map_err(|err| format!("upload canonical object: {err:?}"))?;

    let new_attachment_id = crate::utils::ids::next_message_id(state.id_gen.as_ref())
        .await
        .map_err(|err| format!("generate canonical attachment id: {err:?}"))?;

    Ok(NewAttachment {
        id: new_attachment_id,
        message_id: None,
        file_name: canonical_file_name,
        kind: "audio/ogg".to_string(),
        external_reference: storage_key,
        size: output_bytes.len() as i64,
        created_at: Utc::now(),
        deleted_at: None,
        width: None,
        height: None,
        order: attachment.order,
    })
}

async fn transcode_with_ffmpeg(file_name: &str, source_bytes: Vec<u8>) -> Result<Vec<u8>, String> {
    let file_name = file_name.to_string();
    tokio::task::spawn_blocking(move || {
        let ext = Path::new(&file_name)
            .extension()
            .and_then(|ext| ext.to_str())
            .unwrap_or("bin");
        let input_path = temp_path("wetty-audio-input", ext);
        let output_path = temp_path("wetty-audio-output", "ogg");

        std::fs::write(&input_path, &source_bytes)
            .map_err(|err| format!("write temp input: {err}"))?;

        let output = std::process::Command::new("ffmpeg")
            .arg("-y")
            .arg("-i")
            .arg(&input_path)
            .arg("-c:a")
            .arg("libopus")
            .arg("-f")
            .arg("ogg")
            .arg(&output_path)
            .output()
            .map_err(|err| format!("spawn ffmpeg: {err}"))?;

        let _ = std::fs::remove_file(&input_path);

        if !output.status.success() {
            let _ = std::fs::remove_file(&output_path);
            return Err(format!(
                "ffmpeg failed: {}",
                String::from_utf8_lossy(&output.stderr).trim()
            ));
        }

        let bytes =
            std::fs::read(&output_path).map_err(|err| format!("read ffmpeg output: {err}"))?;
        let _ = std::fs::remove_file(&output_path);
        Ok(bytes)
    })
    .await
    .map_err(|err| format!("join ffmpeg task: {err}"))?
}

fn temp_path(prefix: &str, extension: &str) -> PathBuf {
    std::env::temp_dir().join(format!("{prefix}-{}.{}", Uuid::new_v4(), extension))
}

fn canonical_file_name(original_file_name: &str) -> String {
    let stem = Path::new(original_file_name)
        .file_stem()
        .and_then(|stem| stem.to_str())
        .filter(|stem| !stem.is_empty())
        .unwrap_or("audio");
    format!("{stem}.ogg")
}

enum AudioPublishOutcome {
    Done {
        swap_attachment: Option<NewAttachment>,
    },
    Failed,
}

impl AudioPublishOutcome {
    fn metrics_label(&self) -> Option<&'static str> {
        match self {
            Self::Done {
                swap_attachment: Some(_),
            } => Some("success"),
            Self::Done {
                swap_attachment: None,
            } => None,
            Self::Failed => Some("failure"),
        }
    }
}

fn log_audio_transcode_job(
    message: &Message,
    input_attachment: Option<&Attachment>,
    outcome: &AudioPublishOutcome,
    elapsed: std::time::Duration,
) {
    let action = match outcome {
        AudioPublishOutcome::Done {
            swap_attachment: Some(_),
        } => "transcoded",
        AudioPublishOutcome::Done {
            swap_attachment: None,
        } => "already_canonical",
        AudioPublishOutcome::Failed => "published_original",
    };

    let input_attachment_id = input_attachment.map(|attachment| attachment.id);
    let input_kind = input_attachment
        .map(|attachment| attachment.kind.as_str())
        .unwrap_or("none");
    let input_file_name = input_attachment
        .map(|attachment| attachment.file_name.as_str())
        .unwrap_or("");
    let input_size = input_attachment
        .map(|attachment| attachment.size)
        .unwrap_or(0);

    let output_attachment_id = match outcome {
        AudioPublishOutcome::Done {
            swap_attachment: Some(new_attachment),
        } => Some(new_attachment.id),
        AudioPublishOutcome::Done {
            swap_attachment: None,
        }
        | AudioPublishOutcome::Failed => input_attachment_id,
    };
    let output_kind = match outcome {
        AudioPublishOutcome::Done {
            swap_attachment: Some(new_attachment),
        } => new_attachment.kind.as_str(),
        AudioPublishOutcome::Done {
            swap_attachment: None,
        }
        | AudioPublishOutcome::Failed => input_kind,
    };
    let output_file_name = match outcome {
        AudioPublishOutcome::Done {
            swap_attachment: Some(new_attachment),
        } => new_attachment.file_name.as_str(),
        AudioPublishOutcome::Done {
            swap_attachment: None,
        }
        | AudioPublishOutcome::Failed => input_file_name,
    };
    let output_size = match outcome {
        AudioPublishOutcome::Done {
            swap_attachment: Some(new_attachment),
        } => new_attachment.size,
        AudioPublishOutcome::Done {
            swap_attachment: None,
        }
        | AudioPublishOutcome::Failed => input_size,
    };

    tracing::debug!(
        message_id = message.id,
        chat_id = message.chat_id,
        reply_root_id = message.reply_root_id,
        was_published = message.is_published,
        action,
        input_attachment_id,
        input_kind,
        input_file_name,
        input_size,
        output_attachment_id,
        output_kind,
        output_file_name,
        output_size,
        duration_ms = elapsed.as_millis() as u64,
        "audio transcode job completed"
    );
}

struct AudioTranscodeMetricGuard {
    state: AppState,
    started_at: std::time::Instant,
    finished: bool,
}

impl AudioTranscodeMetricGuard {
    fn new(state: AppState, started_at: std::time::Instant) -> Self {
        Self {
            state,
            started_at,
            finished: false,
        }
    }

    fn finish(&mut self, result: Option<&'static str>) {
        self.finished = true;
        if let Some(result) = result {
            self.state
                .metrics
                .record_audio_transcode_job(result, self.started_at.elapsed().as_secs_f64());
        }
    }
}

impl Drop for AudioTranscodeMetricGuard {
    fn drop(&mut self) {
        if !self.finished {
            self.state
                .metrics
                .record_audio_transcode_job("failure", self.started_at.elapsed().as_secs_f64());
        }
    }
}
