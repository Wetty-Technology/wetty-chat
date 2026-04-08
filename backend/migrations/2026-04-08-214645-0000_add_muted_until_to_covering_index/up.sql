DROP INDEX idx_group_membership_uid_chat_last_read;
CREATE INDEX idx_group_membership_uid_chat_last_read
ON group_membership(uid, chat_id, last_read_message_id, muted_until);
