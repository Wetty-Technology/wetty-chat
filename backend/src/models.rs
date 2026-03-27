use crate::schema;
use chrono::{DateTime, Utc};
use diesel::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(diesel_derive_enum::DbEnum, Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[ExistingTypePath = "crate::schema::sql_types::GroupVisibility"]
#[serde(rename_all = "snake_case")]
pub enum GroupVisibility {
    Public,
    SemiPublic,
    Private,
}

#[derive(diesel_derive_enum::DbEnum, Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[ExistingTypePath = "crate::schema::sql_types::MediaPurpose"]
#[serde(rename_all = "snake_case")]
pub enum MediaPurpose {
    Avatar,
    Sticker,
    Generic,
}

#[derive(diesel_derive_enum::DbEnum, Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[ExistingTypePath = "crate::schema::sql_types::GroupJoinReason"]
#[serde(rename_all = "snake_case")]
pub enum GroupJoinReason {
    Other,
    Creator,
    InviteCode,
    DirectInvite,
}

#[derive(diesel_derive_enum::DbEnum, Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[ExistingTypePath = "crate::schema::sql_types::GroupRole"]
#[serde(rename_all = "snake_case")]
pub enum GroupRole {
    Member,
    Admin,
}

#[derive(diesel_derive_enum::DbEnum, Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[ExistingTypePath = "crate::schema::sql_types::InviteType"]
#[serde(rename_all = "snake_case")]
pub enum InviteType {
    Generic,
    Targeted,
    Membership,
}

#[derive(diesel_derive_enum::DbEnum, Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[ExistingTypePath = "crate::schema::sql_types::MessageType"]
#[serde(rename_all = "snake_case")]
pub enum MessageType {
    Text,
    Audio,
    File,
    System,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserGroupInfo {
    pub group_id: i32,
    pub name: Option<String>,
    pub chat_group_color: Option<String>,
    pub chat_group_color_dark: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Sender {
    pub uid: i32,
    pub avatar_url: Option<String>,
    pub name: Option<String>,
    pub gender: i16,
    pub user_group: Option<UserGroupInfo>,
}

#[derive(Debug, Clone, Queryable, Selectable, Serialize, Insertable)]
#[diesel(table_name = schema::groups)]
pub struct Group {
    pub id: i64,
    pub name: String,
    pub description: Option<String>,
    pub avatar_image_id: Option<i64>,
    pub created_at: DateTime<Utc>,
    pub visibility: GroupVisibility,
    pub last_message_id: Option<i64>,
    pub last_message_at: Option<DateTime<Utc>>,
}

/// For inserting a group. Set `id` and `created_at` (e.g. `Utc::now()`) when not relying on DB defaults.
#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = schema::groups)]
pub struct NewGroup {
    pub id: i64,
    pub name: String,
    pub description: Option<String>,
    pub avatar_image_id: Option<i64>,
    pub created_at: DateTime<Utc>,
    pub visibility: GroupVisibility,
}

#[derive(Debug, Clone, Queryable, Selectable, Serialize, Insertable)]
#[diesel(table_name = schema::media)]
pub struct Media {
    pub id: i64,
    pub content_type: String,
    pub storage_key: String,
    pub size: i64,
    pub created_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
    pub file_name: String,
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub purpose: MediaPurpose,
    pub reference: Option<String>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = schema::media)]
pub struct NewMedia {
    pub id: i64,
    pub content_type: String,
    pub storage_key: String,
    pub size: i64,
    pub created_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
    pub file_name: String,
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub purpose: MediaPurpose,
    pub reference: Option<String>,
}

#[derive(Debug, Clone, Queryable, Selectable, Serialize, Insertable)]
#[diesel(table_name = schema::sticker_packs)]
pub struct StickerPack {
    pub id: i64,
    pub owner_uid: i32,
    pub name: String,
    pub description: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = schema::sticker_packs)]
pub struct NewStickerPack {
    pub id: i64,
    pub owner_uid: i32,
    pub name: String,
    pub description: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, AsChangeset)]
#[diesel(table_name = schema::sticker_packs)]
pub struct UpdateStickerPack {
    pub name: Option<String>,
    pub description: Option<String>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Queryable, Selectable, Serialize, Insertable)]
#[diesel(table_name = schema::stickers)]
pub struct Sticker {
    pub id: i64,
    pub media_id: i64,
    pub emoji: String,
    pub name: Option<String>,
    pub description: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = schema::stickers)]
pub struct NewSticker {
    pub id: i64,
    pub media_id: i64,
    pub emoji: String,
    pub name: Option<String>,
    pub description: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Queryable, Selectable, Insertable)]
#[diesel(table_name = schema::sticker_pack_stickers)]
pub struct StickerPackSticker {
    pub pack_id: i64,
    pub sticker_id: i64,
    pub added_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Queryable, Selectable, Insertable)]
#[diesel(table_name = schema::user_sticker_pack_subscriptions)]
pub struct UserStickerPackSubscription {
    pub uid: i32,
    pub pack_id: i64,
    pub subscribed_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Queryable, Selectable, Insertable)]
#[diesel(table_name = schema::user_favorite_stickers)]
pub struct UserFavoriteSticker {
    pub uid: i32,
    pub sticker_id: i64,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Queryable, Selectable, Serialize, Insertable)]
#[diesel(table_name = schema::group_membership)]
pub struct GroupMembership {
    pub chat_id: i64,
    pub uid: i32,
    pub role: GroupRole,
    pub joined_at: DateTime<Utc>,
    pub last_read_message_id: Option<i64>,
    pub muted_until: Option<DateTime<Utc>>,
    pub join_reason: GroupJoinReason,
    pub join_reason_extra: Option<serde_json::Value>,
}

/// For inserting a membership. Use `"member"` and `Utc::now()` for `role` and `joined_at` to match DB defaults.
#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = schema::group_membership)]
pub struct NewGroupMembership {
    pub chat_id: i64,
    pub uid: i32,
    pub role: GroupRole,
    pub joined_at: DateTime<Utc>,
    pub join_reason: GroupJoinReason,
    pub join_reason_extra: Option<serde_json::Value>,
}

#[derive(Debug, Clone, Queryable, Selectable, Serialize)]
#[diesel(table_name = schema::invites)]
pub struct Invite {
    pub id: i64,
    pub code: String,
    pub chat_id: i64,
    pub invite_type: InviteType,
    pub creator_uid: Option<i32>,
    pub target_uid: Option<i32>,
    pub required_chat_id: Option<i64>,
    pub created_at: DateTime<Utc>,
    pub expires_at: Option<DateTime<Utc>>,
    pub revoked_at: Option<DateTime<Utc>>,
    pub used_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = schema::invites)]
pub struct NewInvite {
    pub id: i64,
    pub code: String,
    pub chat_id: i64,
    pub invite_type: InviteType,
    pub creator_uid: Option<i32>,
    pub target_uid: Option<i32>,
    pub required_chat_id: Option<i64>,
    pub created_at: DateTime<Utc>,
    pub expires_at: Option<DateTime<Utc>>,
    pub revoked_at: Option<DateTime<Utc>>,
    pub used_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Queryable, Selectable, Serialize)]
#[diesel(table_name = schema::messages)]
pub struct Message {
    pub id: i64,
    pub message: Option<String>,
    pub message_type: MessageType,
    pub reply_to_id: Option<i64>,
    pub reply_root_id: Option<i64>,
    pub client_generated_id: String,
    pub sender_uid: i32,
    pub chat_id: i64,
    pub created_at: DateTime<Utc>,
    pub updated_at: Option<DateTime<Utc>>,
    pub deleted_at: Option<DateTime<Utc>>,
    pub has_attachments: bool,
    pub has_thread: bool,
    pub has_reactions: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct ThreadInfo {
    pub reply_count: i64,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = schema::messages)]
pub struct NewMessage {
    pub id: i64,
    pub message: Option<String>,
    pub message_type: MessageType,
    pub reply_to_id: Option<i64>,
    pub reply_root_id: Option<i64>,
    pub client_generated_id: String,
    pub sender_uid: i32,
    pub chat_id: i64,
    pub created_at: DateTime<Utc>,
    pub updated_at: Option<DateTime<Utc>>,
    pub deleted_at: Option<DateTime<Utc>>,
    pub has_attachments: bool,
    pub has_thread: bool,
    pub has_reactions: bool,
}

#[derive(Debug, Clone, Queryable, Selectable, Insertable)]
#[diesel(table_name = schema::message_reactions)]
pub struct MessageReaction {
    pub message_id: i64,
    pub user_uid: i32,
    pub emoji: String,
    pub created_at: DateTime<Utc>,
}

#[cfg(test)]
mod tests {
    use super::MessageType;

    #[test]
    fn message_type_serializes_as_snake_case() {
        let json = serde_json::to_string(&MessageType::System).expect("serialize message type");
        assert_eq!(json, "\"system\"");
    }

    #[test]
    fn message_type_deserializes_system_variant() {
        let value: MessageType =
            serde_json::from_str("\"system\"").expect("deserialize message type");
        assert_eq!(value, MessageType::System);
    }
}

#[derive(Debug, Clone, Queryable, Selectable, Serialize, Insertable)]
#[diesel(table_name = schema::attachments)]
pub struct Attachment {
    pub id: i64,
    pub message_id: Option<i64>,
    pub file_name: String,
    pub kind: String,
    pub external_reference: String,
    pub size: i64,
    pub created_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
    pub width: Option<i32>,
    pub height: Option<i32>,
}

#[derive(Debug, Clone, Serialize)]
pub struct AttachmentResponse {
    #[serde(with = "crate::serde_i64_string")]
    pub id: i64,
    pub url: String,
    pub kind: String,
    pub size: i64,
    pub file_name: String,
    pub width: Option<i32>,
    pub height: Option<i32>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = schema::attachments)]
pub struct NewAttachment {
    pub id: i64,
    pub message_id: Option<i64>,
    pub file_name: String,
    pub kind: String,
    pub external_reference: String,
    pub size: i64,
    pub created_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
    pub width: Option<i32>,
    pub height: Option<i32>,
}

#[derive(Debug, Clone, AsChangeset)]
#[diesel(table_name = schema::groups)]
pub struct UpdateGroup {
    pub name: Option<String>,
    pub description: Option<String>,
    pub visibility: Option<GroupVisibility>,
}

#[derive(Debug, Clone, Queryable, Selectable, Serialize, Insertable)]
#[diesel(table_name = schema::activity_daily_metrics)]
pub struct ActivityDailyMetric {
    pub day: chrono::NaiveDate,
    pub active_users: i64,
    pub new_users: i64,
    pub active_clients: i64,
    pub new_clients: i64,
    pub client_rebinds: i64,
    pub stale_clients_purged: i64,
    pub legacy_subscriptions_purged: i64,
    pub updated_at: chrono::NaiveDateTime,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = schema::activity_daily_metrics)]
pub struct NewActivityDailyMetric {
    pub day: chrono::NaiveDate,
    pub active_users: i64,
    pub new_users: i64,
    pub active_clients: i64,
    pub new_clients: i64,
    pub client_rebinds: i64,
    pub stale_clients_purged: i64,
    pub legacy_subscriptions_purged: i64,
    pub updated_at: chrono::NaiveDateTime,
}

#[derive(Debug, Clone, Queryable, Selectable, Serialize, Insertable)]
#[diesel(table_name = schema::clients)]
pub struct ClientRecord {
    pub client_id: String,
    pub created_at: chrono::NaiveDateTime,
    pub last_active: chrono::NaiveDateTime,
    pub last_active_uid: i32,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = schema::clients)]
pub struct NewClientRecord {
    pub client_id: String,
    pub created_at: chrono::NaiveDateTime,
    pub last_active: chrono::NaiveDateTime,
    pub last_active_uid: i32,
}

#[derive(Debug, Clone, Queryable, Selectable, Serialize, Insertable)]
#[diesel(table_name = schema::user_extra)]
pub struct UserExtra {
    pub uid: i32,
    pub first_seen_at: chrono::NaiveDateTime,
    pub last_seen_at: chrono::NaiveDateTime,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = schema::user_extra)]
pub struct NewUserExtra {
    pub uid: i32,
    pub first_seen_at: chrono::NaiveDateTime,
    pub last_seen_at: chrono::NaiveDateTime,
}

#[derive(Debug, Clone, Queryable, Selectable, Serialize, Insertable)]
#[diesel(table_name = schema::usergroup_extra)]
pub struct UserGroupExtra {
    pub groupid: i32,
    pub chat_group_color: Option<String>,
    pub chat_group_color_dark: Option<String>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = schema::usergroup_extra)]
pub struct NewUserGroupExtra {
    pub groupid: i32,
    pub chat_group_color: Option<String>,
    pub chat_group_color_dark: Option<String>,
}

#[derive(Debug, Clone, Queryable, Selectable, Serialize, Insertable)]
#[diesel(table_name = schema::push_subscriptions)]
pub struct PushSubscription {
    pub id: i64,
    pub user_id: i32,
    pub endpoint: String,
    pub p256dh: String,
    pub auth: String,
    pub created_at: chrono::NaiveDateTime,
    pub client_id: Option<String>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = schema::push_subscriptions)]
pub struct NewPushSubscription {
    pub id: i64,
    pub user_id: i32,
    pub endpoint: String,
    pub p256dh: String,
    pub auth: String,
    pub created_at: chrono::NaiveDateTime,
    pub client_id: Option<String>,
}
