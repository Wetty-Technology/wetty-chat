use serde::Serialize;
use utoipa::ToSchema;

#[derive(Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct VapidPublicKeyResponse {
    pub public_key: String,
}

#[derive(Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct SubscriptionStatusResponse {
    pub has_active_subscription: bool,
    pub has_matching_subscription: Option<bool>,
    pub has_matching_endpoint: Option<bool>,
}
