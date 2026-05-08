ALTER TYPE policy_subject_type ADD VALUE IF NOT EXISTS 'service_token';

CREATE TABLE service_tokens (
    id BIGINT PRIMARY KEY,
    token TEXT NOT NULL UNIQUE,
    secret_hash TEXT NOT NULL,
    name TEXT NOT NULL,
    created_by_uid INTEGER NOT NULL,
    revoked_at TIMESTAMPTZ,
    last_used_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_service_tokens_created_at
ON service_tokens(created_at DESC, id DESC);

CREATE INDEX idx_service_tokens_active
ON service_tokens(id)
WHERE revoked_at IS NULL;
