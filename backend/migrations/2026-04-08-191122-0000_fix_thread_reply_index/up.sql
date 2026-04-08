-- Replace the covering index to match actual query patterns:
-- DISTINCT ON (reply_root_id) ORDER BY reply_root_id, id DESC
-- and unread count: WHERE reply_root_id = X AND id > Y
DROP INDEX IF EXISTS idx_messages_thread_reply_stats;
CREATE INDEX idx_messages_thread_reply_stats
    ON messages(reply_root_id, id DESC)
    WHERE deleted_at IS NULL;
