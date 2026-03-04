DROP INDEX idx_messages_chat_reply_root_created;

DROP INDEX idx_push_subscriptions_user_endpoint;

ALTER TABLE push_subscriptions ALTER COLUMN user_id TYPE BIGINT;
