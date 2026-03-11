DROP INDEX IF EXISTS idx_messages_chat_id_id_desc;

ALTER TABLE group_membership DROP COLUMN IF EXISTS last_read_message_id;

ALTER TABLE groups DROP COLUMN IF EXISTS last_message_at;
ALTER TABLE groups DROP COLUMN IF EXISTS last_message_id;
