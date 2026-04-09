DELETE FROM push_subscriptions
WHERE provider <> 'web_push';

ALTER TABLE push_subscriptions
    ADD COLUMN p256dh TEXT,
    ADD COLUMN auth TEXT;

UPDATE push_subscriptions
SET
    p256dh = provider_data ->> 'p256dh',
    auth = provider_data ->> 'auth'
WHERE provider = 'web_push';

ALTER TABLE push_subscriptions
    DROP CONSTRAINT IF EXISTS push_subscriptions_provider_shape_check;

DROP INDEX IF EXISTS idx_push_subscriptions_user_provider;
DROP INDEX IF EXISTS idx_push_subscriptions_apns_user_token_environment;
DROP INDEX IF EXISTS idx_push_subscriptions_web_user_endpoint;

ALTER TABLE push_subscriptions
    ALTER COLUMN endpoint SET NOT NULL,
    ALTER COLUMN p256dh SET NOT NULL,
    ALTER COLUMN auth SET NOT NULL;

CREATE UNIQUE INDEX idx_push_subscriptions_user_endpoint
    ON push_subscriptions(user_id, endpoint);

ALTER TABLE push_subscriptions
    DROP COLUMN provider_data,
    DROP COLUMN apns_environment,
    DROP COLUMN device_token,
    DROP COLUMN provider;

DROP TYPE push_environment;
DROP TYPE push_provider;
