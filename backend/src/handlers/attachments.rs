use aws_sdk_s3::presigning::PresigningConfig;
use axum::{
    extract::{Json, State},
    http::StatusCode,
    response::IntoResponse,
};
use chrono::{Duration, Utc};
use diesel::prelude::*;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

use crate::errors::AppError;
use crate::extractors::DbConn;
use crate::services::media::{build_storage_key, presign_public_upload};
use crate::utils::auth::CurrentUid;
use crate::utils::ids;
use crate::{models::NewAttachment, schema::attachments, AppState};

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UploadUrlRequest {
    filename: String,
    content_type: String,
    size: i64,
    width: Option<i32>,
    height: Option<i32>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UploadUrlResponse {
    attachment_id: String,
    upload_url: String,
    upload_headers: BTreeMap<String, String>,
}

// Kept for potential future use or non-public buckets
#[allow(dead_code)]
pub async fn get_presigned_url(
    s3_client: &aws_sdk_s3::Client,
    bucket: &str,
    key: &str,
    expires_in: Duration,
) -> Result<String, AppError> {
    let presigning_config =
        PresigningConfig::expires_in(expires_in.to_std().unwrap()).map_err(|e| {
            tracing::error!("presigning config error: {:?}", e);
            AppError::Internal("Failed to configure presigned URL")
        })?;

    let presigned_request = s3_client
        .get_object()
        .bucket(bucket)
        .key(key)
        .presigned(presigning_config)
        .await
        .map_err(|e| {
            tracing::error!("Failed to generate presigned GET URL: {:?}", e);
            AppError::Internal("Failed to generate attachment URL")
        })?;

    Ok(presigned_request.uri().to_string())
}

async fn post_upload_url(
    CurrentUid(_uid): CurrentUid,
    State(state): State<AppState>,
    mut conn: DbConn,
    Json(payload): Json<UploadUrlRequest>,
) -> Result<impl IntoResponse, AppError> {
    let conn = &mut *conn;

    let s3_client = &state.s3_client;
    let bucket = &state.s3_bucket_name;
    let prefix = &state.s3_attachment_prefix;

    let id = ids::next_message_id(state.id_gen.as_ref())
        .await
        .map_err(|e| {
            tracing::error!("next_message_id for attachment: {:?}", e);
            AppError::Internal("Failed to generate ID")
        })?;

    let s3_item_id = uuid::Uuid::new_v4().to_string();

    let key = build_storage_key(prefix, &payload.filename, &s3_item_id);
    let expires_in = Duration::minutes(15);
    let presigned_upload =
        presign_public_upload(s3_client, bucket, &key, &payload.content_type, expires_in).await?;

    let new_attachment = NewAttachment {
        id,
        message_id: None,
        file_name: payload.filename.clone(),
        kind: payload.content_type.clone(),
        external_reference: key.clone(),
        size: payload.size,
        created_at: Utc::now(),
        deleted_at: None,
        width: payload.width,
        height: payload.height,
    };

    diesel::insert_into(attachments::table)
        .values(&new_attachment)
        .execute(conn)?;

    let response = UploadUrlResponse {
        attachment_id: id.to_string(),
        upload_url: presigned_upload.upload_url,
        upload_headers: presigned_upload.upload_headers,
    };

    Ok((StatusCode::CREATED, Json(response)))
}

pub fn router() -> axum::Router<crate::AppState> {
    axum::Router::new().route("/upload-url", axum::routing::post(post_upload_url))
}
