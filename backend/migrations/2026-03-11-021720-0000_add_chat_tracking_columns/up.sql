ALTER TABLE groups ADD COLUMN last_message_id BIGINT REFERENCES messages(id);
ALTER TABLE groups ADD COLUMN last_message_at TIMESTAMPTZ;

-- For existing chats, backfill last_message_id and last_message_at
UPDATE groups
SET last_message_id = (SELECT id FROM messages WHERE chat_id = groups.id ORDER BY created_at DESC LIMIT 1),
    last_message_at = (SELECT created_at FROM messages WHERE chat_id = groups.id ORDER BY created_at DESC LIMIT 1);

-- For tracking unread messages
ALTER TABLE group_membership ADD COLUMN last_read_message_id BIGINT REFERENCES messages(id);

-- Initialize last_read_message_id for existing memberships to the latest message, so they don't suddenly have thousands of unread messages.
UPDATE group_membership
SET last_read_message_id = (SELECT id FROM messages WHERE chat_id = group_membership.chat_id ORDER BY created_at DESC LIMIT 1);

-- Index for counting unread messages efficiently
CREATE INDEX idx_messages_chat_id_id_desc ON messages(chat_id, id DESC);
