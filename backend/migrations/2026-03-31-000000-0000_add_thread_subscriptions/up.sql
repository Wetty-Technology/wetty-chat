CREATE TABLE thread_subscriptions (
    chat_id          BIGINT      NOT NULL REFERENCES groups(id),
    thread_root_id   BIGINT      NOT NULL REFERENCES messages(id),
    uid              INTEGER     NOT NULL,
    last_read_message_id BIGINT  NULL,
    subscribed_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (chat_id, thread_root_id, uid)
);

CREATE INDEX idx_thread_subs_uid ON thread_subscriptions (uid);
CREATE INDEX idx_thread_subs_thread ON thread_subscriptions (chat_id, thread_root_id);
