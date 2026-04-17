-- Your SQL goes here
ALTER TABLE group_membership
    ADD COLUMN archived BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE thread_subscriptions
    ADD COLUMN archived BOOLEAN NOT NULL DEFAULT FALSE;

DROP INDEX IF EXISTS idx_group_membership_uid_chat_last_read;
CREATE INDEX idx_group_membership_uid_chat_last_read
    ON group_membership(uid, archived, chat_id, last_read_message_id, muted_until);

DROP INDEX IF EXISTS idx_thread_subs_uid;
CREATE INDEX idx_thread_subs_uid
    ON thread_subscriptions(uid, archived);
