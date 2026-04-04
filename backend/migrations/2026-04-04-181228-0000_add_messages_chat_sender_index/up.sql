CREATE INDEX idx_messages_chat_sender_active
    ON messages (chat_id, sender_uid, created_at DESC)
    WHERE deleted_at IS NULL;
