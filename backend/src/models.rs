use crate::schema;
use chrono::{DateTime, Utc};
use diesel::prelude::*;
use serde::Serialize;

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
    pub visibility: String,
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
    pub visibility: String,
}

#[derive(Debug, Clone, Queryable, Selectable, Serialize, Insertable)]
#[diesel(table_name = schema::group_membership)]
pub struct GroupMembership {
    pub chat_id: i64,
    pub uid: i32,
    pub role: String,
    pub joined_at: DateTime<Utc>,
}

/// For inserting a membership. Use `"member"` and `Utc::now()` for `role` and `joined_at` to match DB defaults.
#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = schema::group_membership)]
pub struct NewGroupMembership {
    pub chat_id: i64,
    pub uid: i32,
    pub role: String,
    pub joined_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Queryable, Selectable, Serialize)]
#[diesel(table_name = schema::messages)]
pub struct Message {
    pub id: i64,
    pub message: Option<String>,
    pub message_type: String,
    pub reply_to_id: Option<i64>,
    pub reply_root_id: Option<i64>,
    pub client_generated_id: String,
    pub sender_uid: i32,
    pub chat_id: i64,
    pub created_at: DateTime<Utc>,
    pub updated_at: Option<DateTime<Utc>>,
    pub deleted_at: Option<DateTime<Utc>>,
    pub has_attachments: bool,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = schema::messages)]
pub struct NewMessage {
    pub id: i64,
    pub message: Option<String>,
    pub message_type: String,
    pub reply_to_id: Option<i64>,
    pub reply_root_id: Option<i64>,
    pub client_generated_id: String,
    pub sender_uid: i32,
    pub chat_id: i64,
    pub created_at: DateTime<Utc>,
    pub updated_at: Option<DateTime<Utc>>,
    pub deleted_at: Option<DateTime<Utc>>,
    pub has_attachments: bool,
}

#[derive(Debug, Clone, Queryable, Selectable, Serialize)]
#[diesel(table_name = schema::attachments)]
pub struct Attachment {
    pub id: i64,
    pub message_id: i64,
    pub kind: String,
    pub external_reference: String,
    pub size: i64,
    pub created_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = schema::attachments)]
pub struct NewAttachment {
    pub id: i64,
    pub message_id: i64,
    pub kind: String,
    pub external_reference: String,
    pub size: i64,
    pub created_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
}
