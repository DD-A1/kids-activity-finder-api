
-- ============================================
-- DOMAIN 2: PROVIDERS & ORGANIZATIONS
-- ============================================

CREATE TABLE providers (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    provider_type VARCHAR(50) NOT NULL
        CHECK (
            provider_type IN (
                'ORGANIZATION',
                'INDEPENDENT_INSTRUCTOR'
            )
        ),

    display_name VARCHAR(255) NOT NULL,

    description TEXT,

    website_url VARCHAR(500),

    approval_status VARCHAR(30) NOT NULL DEFAULT 'PENDING'
        CHECK (
            approval_status IN (
                'PENDING',
                'APPROVED',
                'REJECTED',
                'SUSPENDED'
            )
        ),

    submitted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    reviewed_at TIMESTAMPTZ,

    reviewed_by_user_id INTEGER
        REFERENCES users(id) ON DELETE RESTRICT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
