// @generated automatically by Diesel CLI.

pub mod sql_types {
    #[derive(diesel::sql_types::SqlType)]
    #[diesel(postgres_type(name = "group_role"))]
    pub struct GroupRole;

    #[derive(diesel::sql_types::SqlType)]
    #[diesel(postgres_type(name = "group_visibility"))]
    pub struct GroupVisibility;

    #[derive(diesel::sql_types::SqlType)]
    #[diesel(postgres_type(name = "message_type"))]
    pub struct MessageType;
}

diesel::table! {
    attachments (id) {
        id -> Int8,
        message_id -> Nullable<Int8>,
        #[max_length = 20]
        kind -> Varchar,
        external_reference -> Text,
        size -> Int8,
        created_at -> Timestamptz,
        deleted_at -> Nullable<Timestamptz>,
        #[max_length = 255]
        file_name -> Varchar,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::GroupRole;

    group_membership (chat_id, uid) {
        chat_id -> Int8,
        uid -> Int4,
        role -> GroupRole,
        joined_at -> Timestamptz,
        last_read_message_id -> Nullable<Int8>,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::GroupVisibility;

    groups (id) {
        id -> Int8,
        #[max_length = 255]
        name -> Varchar,
        description -> Nullable<Text>,
        avatar -> Nullable<Text>,
        created_at -> Timestamptz,
        visibility -> GroupVisibility,
        last_message_id -> Nullable<Int8>,
        last_message_at -> Nullable<Timestamptz>,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::MessageType;

    messages (id) {
        id -> Int8,
        message -> Nullable<Text>,
        message_type -> MessageType,
        reply_to_id -> Nullable<Int8>,
        reply_root_id -> Nullable<Int8>,
        client_generated_id -> Varchar,
        sender_uid -> Int4,
        chat_id -> Int8,
        created_at -> Timestamptz,
        updated_at -> Nullable<Timestamptz>,
        deleted_at -> Nullable<Timestamptz>,
        has_attachments -> Bool,
        has_thread -> Bool,
    }
}

diesel::table! {
    push_subscriptions (id) {
        id -> Int8,
        user_id -> Int4,
        endpoint -> Text,
        p256dh -> Text,
        auth -> Text,
        created_at -> Timestamp,
    }
}

diesel::table! {
    users (uid) {
        uid -> Int4,
        #[max_length = 15]
        username -> Varchar,
    }
}

diesel::joinable!(attachments -> messages (message_id));
diesel::joinable!(group_membership -> groups (chat_id));
diesel::joinable!(group_membership -> messages (last_read_message_id));

diesel::allow_tables_to_appear_in_same_query!(
    attachments,
    group_membership,
    groups,
    messages,
    push_subscriptions,
    users,
);
