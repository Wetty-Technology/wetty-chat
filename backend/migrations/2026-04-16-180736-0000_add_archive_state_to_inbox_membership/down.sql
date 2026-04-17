-- This file should undo anything in `up.sql`
DROP INDEX IF EXISTS idx_thread_subs_uid;
CREATE INDEX idx_thread_subs_uid ON thread_subscriptions (uid);

DROP INDEX IF EXISTS idx_group_membership_uid_chat_last_read;
CREATE INDEX idx_group_membership_uid_chat_last_read
    ON group_membership(uid, chat_id, last_read_message_id, muted_until);

ALTER TABLE thread_subscriptions
    DROP COLUMN archived;

ALTER TABLE group_membership
    DROP COLUMN archived;
