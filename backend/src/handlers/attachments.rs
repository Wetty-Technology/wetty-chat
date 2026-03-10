use aws_sdk_s3::presigning::PresigningConfig;
use axum::{
    extract::{Json, State},
    http::StatusCode,
    response::IntoResponse,
};
use chrono::{Duration, Utc};
use diesel::prelude::*;
use serde::{Deserialize, Serialize};

use crate::utils::auth::CurrentUid;
use crate::utils::ids;
use crate::{models::NewAttachment, schema::attachments, AppState};

#[derive(Deserialize)]
pub struct UploadUrlRequest {
    filename: String,
    content_type: String,
    size: i64,
}

#[derive(Serialize)]
pub struct UploadUrlResponse {
    attachment_id: String,
    upload_url: String,
}

// Kept for potential future use or non-public buckets
#[allow(dead_code)]
pub async fn get_presigned_url(
    s3_client: &aws_sdk_s3::Client,
    bucket: &str,
    key: &str,
    expires_in: Duration,
) -> Result<String, (StatusCode, &'static str)> {
    let presigning_config =
        PresigningConfig::expires_in(expires_in.to_std().unwrap()).map_err(|e| {
            tracing::error!("presigning config error: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to configure presigned URL",
            )
        })?;

    let presigned_request = s3_client
        .get_object()
        .bucket(bucket)
        .key(key)
        .presigned(presigning_config)
        .await
        .map_err(|e| {
            tracing::error!("Failed to generate presigned GET URL: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to generate attachment URL",
            )
        })?;

    Ok(presigned_request.uri().to_string())
}

pub async fn post_upload_url(
    CurrentUid(_uid): CurrentUid,
    State(state): State<AppState>,
    Json(payload): Json<UploadUrlRequest>,
) -> Result<impl IntoResponse, (StatusCode, &'static str)> {
    let s3_client = &state.s3_client;
    let bucket = &state.s3_bucket_name;
    let prefix = &state.s3_attachment_prefix;

    let id = ids::next_message_id(state.id_gen.as_ref())
        .await
        .map_err(|e| {
            tracing::error!("next_message_id for attachment: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to generate ID")
        })?;

    let s3_item_id = uuid::Uuid::new_v4().to_string();

    // Format: <prefix>/<snowflake_id>.<extension>
    let extension = std::path::Path::new(&payload.filename)
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("bin");

    let key = format!("{}/{}.{}", prefix, s3_item_id, extension);
    let expires_in = Duration::minutes(15);
    let presigning_config =
        PresigningConfig::expires_in(expires_in.to_std().unwrap()).map_err(|e| {
            tracing::error!("presigning config error: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to configure presigned URL",
            )
        })?;

    let presigned_request = s3_client
        .put_object()
        .bucket(bucket)
        .key(&key)
        .content_type(&payload.content_type)
        .acl(aws_sdk_s3::types::ObjectCannedAcl::PublicRead)
        .presigned(presigning_config)
        .await
        .map_err(|e| {
            tracing::error!("Failed to generate presigned URL: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to generate upload URL",
            )
        })?;

    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    let new_attachment = NewAttachment {
        id,
        message_id: None,
        file_name: payload.filename.clone(),
        kind: payload.content_type.clone(),
        external_reference: key.clone(),
        size: payload.size,
        created_at: Utc::now(),
        deleted_at: None,
    };

    diesel::insert_into(attachments::table)
        .values(&new_attachment)
        .execute(conn)
        .map_err(|e| {
            tracing::error!("Failed to insert attachment: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to create attachment record",
            )
        })?;

    let response = UploadUrlResponse {
        attachment_id: id.to_string(),
        upload_url: presigned_request.uri().to_string(),
    };

    Ok((StatusCode::CREATED, Json(response)))
}
