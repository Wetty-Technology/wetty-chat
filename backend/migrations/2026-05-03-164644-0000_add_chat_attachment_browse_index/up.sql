-- Your SQL goes here
CREATE INDEX idx_messages_chat_attachments_visible
ON messages(chat_id, id DESC)
WHERE deleted_at IS NULL
  AND is_published = true
  AND has_attachments = true;
