CREATE TYPE push_provider AS ENUM ('web_push', 'apns');
CREATE TYPE push_environment AS ENUM ('sandbox', 'production');

ALTER TABLE push_subscriptions
    ADD COLUMN provider push_provider NOT NULL DEFAULT 'web_push',
    ADD COLUMN device_token TEXT,
    ADD COLUMN apns_environment push_environment,
    ADD COLUMN provider_data JSONB NOT NULL DEFAULT '{}'::jsonb;

UPDATE push_subscriptions
SET provider_data = jsonb_build_object(
    'p256dh', p256dh,
    'auth', auth
);

ALTER TABLE push_subscriptions
    ALTER COLUMN endpoint DROP NOT NULL;

DROP INDEX IF EXISTS idx_push_subscriptions_user_endpoint;

CREATE UNIQUE INDEX idx_push_subscriptions_web_user_endpoint
    ON push_subscriptions(user_id, endpoint)
    WHERE provider = 'web_push';

CREATE UNIQUE INDEX idx_push_subscriptions_apns_user_token_environment
    ON push_subscriptions(user_id, device_token, apns_environment)
    WHERE provider = 'apns';

CREATE INDEX idx_push_subscriptions_user_provider
    ON push_subscriptions(user_id, provider);

ALTER TABLE push_subscriptions
    ADD CONSTRAINT push_subscriptions_provider_shape_check
    CHECK (
        (
            provider = 'web_push'
            AND endpoint IS NOT NULL
            AND device_token IS NULL
            AND apns_environment IS NULL
            AND provider_data ? 'p256dh'
            AND provider_data ? 'auth'
        )
        OR (
            provider = 'apns'
            AND endpoint IS NULL
            AND device_token IS NOT NULL
            AND apns_environment IS NOT NULL
        )
    );

ALTER TABLE push_subscriptions
    DROP COLUMN p256dh,
    DROP COLUMN auth;
