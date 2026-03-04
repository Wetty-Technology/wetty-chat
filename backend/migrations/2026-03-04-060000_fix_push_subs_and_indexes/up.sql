-- Issue 5: user_id BIGINT -> INTEGER to match users.uid
ALTER TABLE push_subscriptions ALTER COLUMN user_id TYPE INTEGER;

-- Issue 4: Prevent duplicate subscriptions
CREATE UNIQUE INDEX idx_push_subscriptions_user_endpoint ON push_subscriptions(user_id, endpoint);

-- Composite index for thread queries (get_messages filters on chat_id, reply_root_id, created_at)
CREATE INDEX idx_messages_chat_reply_root_created ON messages(chat_id, reply_root_id, created_at);
