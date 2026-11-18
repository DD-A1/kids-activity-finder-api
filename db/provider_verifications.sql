
-- ============================================
-- DOMAIN 2: PROVIDER VERIFICATIONS
-- ============================================

CREATE TABLE provider_verifications (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    provider_id BIGINT NOT NULL
        REFERENCES providers(id) ON DELETE RESTRICT,

    verification_type VARCHAR(50) NOT NULL
        CHECK (
            verification_type IN (
                'BUSINESS_REGISTRATION',
                'IDENTITY',
                'INSURANCE',
                'CREDENTIAL',
                'WEBSITE',
                'SAFETY_REVIEW',
                'OTHER'
            )
        ),

    verification_method VARCHAR(20) NOT NULL
        CHECK (
            verification_method IN (
                'AUTOMATED',
                'MANUAL'
            )
        ),

    verification_status VARCHAR(30) NOT NULL DEFAULT 'PENDING'
        CHECK (
            verification_status IN (
                'PENDING',
                'IN_PROGRESS',
                'PASSED',
                'FAILED',
                'NEEDS_REVIEW',
                'EXPIRED'
            )
        ),

    verified_by_user_id INTEGER
        REFERENCES users(id) ON DELETE RESTRICT,

    reference_number VARCHAR(255),

    reviewer_notes TEXT,

    checked_at TIMESTAMPTZ,

    expires_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Provider lookup
CREATE INDEX provider_verifications_provider_id_idx
ON provider_verifications (provider_id);

-- Filter verification results by status
CREATE INDEX provider_verifications_status_idx
ON provider_verifications (verification_status);

-- Find verification records by type
CREATE INDEX provider_verifications_type_idx
ON provider_verifications (verification_type);
