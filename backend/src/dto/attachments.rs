use serde::Serialize;
use std::collections::BTreeMap;
use utoipa::ToSchema;

#[derive(Debug, Clone, Serialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AttachmentResponse {
    #[serde(with = "crate::serde_i64_string")]
    #[schema(value_type = String)]
    pub id: i64,
    pub url: String,
    pub kind: String,
    pub size: i64,
    pub file_name: String,
    pub width: Option<i32>,
    pub height: Option<i32>,
}

#[derive(Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct UploadUrlResponse {
    pub attachment_id: String,
    pub upload_url: String,
    pub upload_headers: BTreeMap<String, String>,
}
