CREATE TABLE users (
    uid INTEGER PRIMARY KEY NOT NULL,
    username VARCHAR(15) NOT NULL
);

CREATE TABLE groups (
    id bigint PRIMARY KEY NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT DEFAULT NULL,
    avatar TEXT DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE group_membership (
    chat_id BIGINT NOT NULL REFERENCES groups(id),
    uid INTEGER NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'member',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (chat_id, uid)
);

CREATE INDEX idx_group_membership_uid ON group_membership(uid);

CREATE TABLE messages (
    id BIGINT PRIMARY KEY,
    message TEXT,
    message_type VARCHAR(20) NOT NULL,
    reply_to_id BIGINT REFERENCES messages(id),
    reply_root_id BIGINT REFERENCES messages(id),
    client_generated_id VARCHAR NOT NULL UNIQUE,
    sender_uid INTEGER NOT NULL,
    chat_id bigint NOT NULL REFERENCES groups(id),
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    has_attachments BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX idx_messages_chat_id_created_at ON messages(chat_id, created_at);
CREATE INDEX idx_messages_reply_root_id ON messages(reply_root_id);

CREATE TABLE attachments (
    id BIGINT PRIMARY KEY,
    message_id BIGINT NOT NULL REFERENCES messages(id),
    kind VARCHAR(20) NOT NULL,
    external_reference TEXT NOT NULL,
    
    size BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_attachments_message_id ON attachments(message_id);
