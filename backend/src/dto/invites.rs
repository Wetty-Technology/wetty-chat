use chrono::{DateTime, Utc};
use serde::Serialize;
use utoipa::ToSchema;

use crate::{
    dto::{groups::GroupInfoResponse, messages::MessageResponse},
    models::InviteType,
};

#[derive(Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct InviteResponse {
    #[serde(with = "crate::serde_i64_string")]
    #[schema(value_type = String)]
    pub id: i64,
    pub code: String,
    #[serde(with = "crate::serde_i64_string")]
    #[schema(value_type = String)]
    pub chat_id: i64,
    pub invite_type: InviteType,
    pub creator_uid: Option<i32>,
    pub target_uid: Option<i32>,
    #[serde(with = "crate::serde_i64_string::opt")]
    #[schema(value_type = Option<String>)]
    pub required_chat_id: Option<i64>,
    pub created_at: DateTime<Utc>,
    pub expires_at: Option<DateTime<Utc>>,
    pub revoked_at: Option<DateTime<Utc>>,
    pub used_at: Option<DateTime<Utc>>,
}

#[derive(Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ListInvitesResponse {
    pub invites: Vec<InviteResponse>,
}

#[derive(Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct InvitePreviewResponse {
    pub invite: InviteResponse,
    pub chat: GroupInfoResponse,
    pub already_member: bool,
}

#[derive(Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct RedeemInviteResponse {
    pub chat: GroupInfoResponse,
}

#[derive(Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct SendInviteMessageResponse {
    pub invite: InviteResponse,
    pub message: MessageResponse,
}
