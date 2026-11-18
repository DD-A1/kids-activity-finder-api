
-- ============================================
-- DOMAIN 2: PROVIDER MEMBERSHIPS
-- ============================================

CREATE TABLE provider_memberships (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    provider_id BIGINT NOT NULL
        REFERENCES providers(id) ON DELETE RESTRICT,

    user_id INTEGER NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT,

    membership_role VARCHAR(30) NOT NULL
        CHECK (
            membership_role IN (
                'OWNER',
                'ADMIN',
                'EDITOR',
                'VIEWER'
            )
        ),

    membership_status VARCHAR(30) NOT NULL DEFAULT 'INVITED'
        CHECK (
            membership_status IN (
                'INVITED',
                'ACTIVE',
                'DECLINED',
                'REVOKED'
            )
        ),

    invited_by_user_id INTEGER
        REFERENCES users(id) ON DELETE RESTRICT,

    invited_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    accepted_at TIMESTAMPTZ,

    revoked_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Prevent duplicate pending or active memberships
CREATE UNIQUE INDEX unique_active_provider_membership
ON provider_memberships (provider_id, user_id)
WHERE membership_status IN ('INVITED', 'ACTIVE');
