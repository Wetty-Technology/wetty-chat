INSERT INTO policies (id, name, metadata, created_at, updated_at)
VALUES (
    2,
    'developer',
    jsonb_build_object(
        'reserved', true,
        'description', 'Reserved policy for developer feature access'
    ),
    NOW(),
    NOW()
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    metadata = EXCLUDED.metadata,
    updated_at = NOW();

INSERT INTO policy_permissions (id, policy_id, action, resource_type, resource_id, created_at)
VALUES (2, 2, 'developer.access', 'global', NULL, NOW())
ON CONFLICT (id) DO UPDATE SET
    policy_id = EXCLUDED.policy_id,
    action = EXCLUDED.action,
    resource_type = EXCLUDED.resource_type,
    resource_id = EXCLUDED.resource_id,
    created_at = EXCLUDED.created_at;
