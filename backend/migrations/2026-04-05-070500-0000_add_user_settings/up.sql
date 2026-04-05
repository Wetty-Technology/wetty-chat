CREATE TABLE user_settings (
    uid INT4 PRIMARY KEY REFERENCES user_extra(uid) ON DELETE CASCADE,
    preferences JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

SELECT diesel_manage_updated_at('user_settings');