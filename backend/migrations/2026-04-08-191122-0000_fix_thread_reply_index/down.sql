-- Restore original index
DROP INDEX IF EXISTS idx_messages_thread_reply_stats;
CREATE INDEX idx_messages_thread_reply_stats
    ON messages(reply_root_id, created_at DESC, id)
    WHERE deleted_at IS NULL;
