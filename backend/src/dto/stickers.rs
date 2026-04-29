use chrono::{DateTime, Utc};
use serde::Serialize;

#[derive(Debug, Serialize, Clone, utoipa::ToSchema)]
#[schema(as = StickersStickerMediaResponse)]
#[serde(rename_all = "camelCase")]
pub struct StickerMediaResponse {
    #[serde(with = "crate::serde_i64_string")]
    #[schema(value_type = String)]
    pub id: i64,
    pub url: String,
    pub content_type: String,
    pub size: i64,
    pub width: Option<i32>,
    pub height: Option<i32>,
}

#[derive(Debug, Serialize, Clone, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct StickerSummary {
    #[serde(with = "crate::serde_i64_string")]
    #[schema(value_type = String)]
    pub id: i64,
    pub media: StickerMediaResponse,
    pub emoji: String,
    pub name: Option<String>,
    pub description: Option<String>,
    pub created_at: DateTime<Utc>,
    pub is_favorited: bool,
}

#[derive(Debug, Serialize, Clone, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct StickerPackPreviewSticker {
    #[serde(with = "crate::serde_i64_string")]
    #[schema(value_type = String)]
    pub id: i64,
    pub media: StickerMediaResponse,
    pub emoji: String,
}

#[derive(Debug, Serialize, Clone, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct StickerPackSummary {
    #[serde(with = "crate::serde_i64_string")]
    #[schema(value_type = String)]
    pub id: i64,
    pub owner_uid: i32,
    pub owner_name: Option<String>,
    pub name: String,
    pub description: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub sticker_count: i64,
    pub is_subscribed: bool,
    pub preview_sticker: Option<StickerPackPreviewSticker>,
}

#[derive(Debug, Serialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct StickerPackDetailResponse {
    #[serde(flatten)]
    #[schema(inline)]
    pub pack: StickerPackSummary,
    pub stickers: Vec<StickerSummary>,
}

#[derive(Debug, Serialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct StickerDetailResponse {
    #[serde(flatten)]
    #[schema(inline)]
    pub sticker: StickerSummary,
    pub packs: Vec<StickerPackSummary>,
}

#[derive(Debug, Serialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct StickerPackListResponse {
    pub packs: Vec<StickerPackSummary>,
}

#[derive(Debug, Serialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct FavoriteStickerListResponse {
    pub stickers: Vec<StickerSummary>,
}
