CREATE TYPE group_visibility AS ENUM ('public', 'semi_public', 'private');
CREATE TYPE group_role AS ENUM ('member', 'admin');
CREATE TYPE message_type AS ENUM ('text', 'audio', 'file');

CREATE TABLE users (
    uid INTEGER PRIMARY KEY NOT NULL,
    username VARCHAR(15) NOT NULL
);

CREATE TABLE groups (
    id bigint PRIMARY KEY NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT DEFAULT NULL,
    avatar TEXT DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    visibility group_visibility NOT NULL DEFAULT 'public'
);

CREATE TABLE group_membership (
    chat_id BIGINT NOT NULL REFERENCES groups(id),
    uid INTEGER NOT NULL,
    role group_role NOT NULL DEFAULT 'member',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (chat_id, uid)
);

CREATE INDEX idx_group_membership_uid ON group_membership(uid);

CREATE TABLE messages (
    id BIGINT PRIMARY KEY,
    message TEXT,
    message_type message_type NOT NULL,
    reply_to_id BIGINT REFERENCES messages(id),
    reply_root_id BIGINT REFERENCES messages(id),
    client_generated_id VARCHAR NOT NULL UNIQUE,
    sender_uid INTEGER NOT NULL,
    chat_id bigint NOT NULL REFERENCES groups(id),
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    has_attachments BOOLEAN NOT NULL DEFAULT false,
    has_thread BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_messages_chat_id_created_at ON messages(chat_id, created_at);
CREATE INDEX idx_messages_reply_root_id ON messages(reply_root_id);
CREATE INDEX idx_messages_chat_reply_root_created ON messages(chat_id, reply_root_id, created_at);

CREATE TABLE attachments (
    id BIGINT PRIMARY KEY,
    message_id BIGINT REFERENCES messages(id),
    kind VARCHAR(20) NOT NULL,
    external_reference TEXT NOT NULL,

    size BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    deleted_at TIMESTAMPTZ,
    file_name VARCHAR(255) NOT NULL DEFAULT ''
);

CREATE INDEX idx_attachments_message_id ON attachments(message_id);

CREATE TABLE push_subscriptions (
    id BIGINT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    endpoint TEXT NOT NULL,
    p256dh TEXT NOT NULL,
    auth TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_push_subscriptions_user_endpoint ON push_subscriptions(user_id, endpoint);
