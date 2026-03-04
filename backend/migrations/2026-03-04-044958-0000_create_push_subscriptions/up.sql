CREATE TABLE push_subscriptions (
    id BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    endpoint TEXT NOT NULL,
    p256dh TEXT NOT NULL,
    auth TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
