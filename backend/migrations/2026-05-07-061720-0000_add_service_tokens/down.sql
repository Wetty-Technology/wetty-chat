DELETE FROM policy_assignments
WHERE subject_type = 'service_token';

DROP INDEX IF EXISTS idx_service_tokens_active;
DROP INDEX IF EXISTS idx_service_tokens_created_at;
DROP TABLE IF EXISTS service_tokens;

ALTER TABLE policy_assignments
    ALTER COLUMN subject_type TYPE TEXT
    USING subject_type::TEXT;

DROP TYPE policy_subject_type;

CREATE TYPE policy_subject_type AS ENUM ('user', 'discuz_group');

ALTER TABLE policy_assignments
    ALTER COLUMN subject_type TYPE policy_subject_type
    USING subject_type::policy_subject_type;
