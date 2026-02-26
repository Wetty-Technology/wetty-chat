// @generated automatically by Diesel CLI.

diesel::table! {
    attachments (id) {
        id -> Int8,
        message_id -> Int8,
        #[max_length = 20]
        kind -> Varchar,
        external_reference -> Text,
        size -> Int8,
        created_at -> Timestamptz,
        deleted_at -> Nullable<Timestamptz>,
    }
}

diesel::table! {
    group_membership (chat_id, uid) {
        chat_id -> Int8,
        uid -> Int4,
        #[max_length = 20]
        role -> Varchar,
        joined_at -> Timestamptz,
    }
}

diesel::table! {
    groups (id) {
        id -> Int8,
        #[max_length = 255]
        name -> Varchar,
        description -> Nullable<Text>,
        avatar -> Nullable<Text>,
        created_at -> Timestamptz,
    }
}

diesel::table! {
    messages (id) {
        id -> Int8,
        message -> Nullable<Text>,
        #[max_length = 20]
        message_type -> Varchar,
        reply_to_id -> Nullable<Int8>,
        reply_root_id -> Nullable<Int8>,
        client_generated_id -> Varchar,
        sender_uid -> Int4,
        chat_id -> Int8,
        created_at -> Timestamptz,
        updated_at -> Nullable<Timestamptz>,
        deleted_at -> Nullable<Timestamptz>,
        has_attachments -> Bool,
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
diesel::joinable!(group_membership -> users (uid));
diesel::joinable!(messages -> groups (chat_id));

diesel::allow_tables_to_appear_in_same_query!(
    attachments,
    group_membership,
    groups,
    messages,
    users,
);
