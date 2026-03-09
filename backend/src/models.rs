use crate::schema;
use chrono::{DateTime, Utc};
use diesel::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(diesel_derive_enum::DbEnum, Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[ExistingTypePath = "crate::schema::sql_types::GroupVisibility"]
pub enum GroupVisibility {
    Public,
    SemiPublic,
    Private,
}

#[derive(diesel_derive_enum::DbEnum, Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[ExistingTypePath = "crate::schema::sql_types::GroupRole"]
pub enum GroupRole {
    Member,
    Admin,
}

#[derive(diesel_derive_enum::DbEnum, Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[ExistingTypePath = "crate::schema::sql_types::MessageType"]
pub enum MessageType {
    Text,
    Audio,
    File,
}

#[derive(Debug, Clone, Queryable, Selectable, Serialize, Insertable)]
#[diesel(table_name = schema::users)]
pub struct User {
    pub uid: i32,
    pub username: String,
}

#[derive(Debug, Clone, Queryable, Selectable, Serialize, Insertable)]
#[diesel(table_name = schema::groups)]
pub struct Group {
    pub id: i64,
    pub name: String,
    pub description: Option<String>,
    pub avatar: Option<String>,
    pub created_at: DateTime<Utc>,
    pub visibility: GroupVisibility,
}

/// For inserting a group. Set `id` and `created_at` (e.g. `Utc::now()`) when not relying on DB defaults.
#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = schema::groups)]
pub struct NewGroup {
    pub id: i64,
    pub name: String,
    pub description: Option<String>,
    pub avatar: Option<String>,
    pub created_at: DateTime<Utc>,
    pub visibility: GroupVisibility,
}

#[derive(Debug, Clone, Queryable, Selectable, Serialize, Insertable)]
#[diesel(table_name = schema::group_membership)]
pub struct GroupMembership {
    pub chat_id: i64,
    pub uid: i32,
    pub role: GroupRole,
    pub joined_at: DateTime<Utc>,
}

/// For inserting a membership. Use `"member"` and `Utc::now()` for `role` and `joined_at` to match DB defaults.
#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = schema::group_membership)]
pub struct NewGroupMembership {
    pub chat_id: i64,
    pub uid: i32,
    pub role: GroupRole,
    pub joined_at: DateTime<Utc>,
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
}

#[derive(Debug, Clone, Serialize)]
pub struct AttachmentResponse {
    #[serde(with = "crate::serde_i64_string")]
    pub id: i64,
    pub url: String,
    pub kind: String,
    pub size: i64,
    pub file_name: String,
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
}

#[derive(Debug, Clone, AsChangeset)]
#[diesel(table_name = schema::groups)]
pub struct UpdateGroup {
    pub name: Option<String>,
    pub description: Option<String>,
    pub avatar: Option<String>,
    pub visibility: Option<GroupVisibility>,
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
}
