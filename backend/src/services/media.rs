use aws_sdk_s3::presigning::PresigningConfig;
use aws_sdk_s3::primitives::ByteStream;
use axum::http::StatusCode;
use chrono::Duration;
use std::collections::BTreeMap;

use crate::AppState;

pub(crate) const PUBLIC_MEDIA_CACHE_CONTROL: &str = "public,max-age=31536000,immutable";

pub struct PresignedUpload {
    pub upload_url: String,
    pub upload_headers: BTreeMap<String, String>,
}

fn collect_presigned_headers(
    presigned_request: &aws_sdk_s3::presigning::PresignedRequest,
) -> BTreeMap<String, String> {
    presigned_request
        .headers()
        .map(|(name, value)| (name.to_string(), value.to_string()))
        .collect()
}

pub fn build_public_object_url(state: &AppState, storage_key: &str) -> String {
    let base_url = state
        .s3_base_url
        .clone()
        .unwrap_or_else(|| format!("https://{}.s3.amazonaws.com", state.s3_bucket_name));
    format!("{}/{}", base_url, storage_key)
}

pub fn build_storage_key(prefix: &str, filename: &str, object_id: &str) -> String {
    let extension = std::path::Path::new(filename)
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("bin");
    format!("{}/{}.{}", prefix, object_id, extension)
}

pub async fn presign_public_upload(
    s3_client: &aws_sdk_s3::Client,
    bucket: &str,
    storage_key: &str,
    content_type: &str,
    expires_in: Duration,
) -> Result<PresignedUpload, (StatusCode, &'static str)> {
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
        .key(storage_key)
        .content_type(content_type)
        .cache_control(PUBLIC_MEDIA_CACHE_CONTROL)
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

    Ok(PresignedUpload {
        upload_url: presigned_request.uri().to_string(),
        upload_headers: collect_presigned_headers(&presigned_request),
    })
}

pub async fn upload_public_object(
    s3_client: &aws_sdk_s3::Client,
    bucket: &str,
    storage_key: &str,
    content_type: &str,
    body: ByteStream,
) -> Result<(), (StatusCode, &'static str)> {
    s3_client
        .put_object()
        .bucket(bucket)
        .key(storage_key)
        .content_type(content_type)
        .cache_control(PUBLIC_MEDIA_CACHE_CONTROL)
        .acl(aws_sdk_s3::types::ObjectCannedAcl::PublicRead)
        .body(body)
        .send()
        .await
        .map_err(|e| {
            tracing::error!("Failed to upload object: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to upload media")
        })?;

    Ok(())
}
