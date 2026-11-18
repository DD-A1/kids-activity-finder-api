
-- ============================================
-- DOMAIN 3: ACTIVITY VERIFICATIONS
-- ============================================

CREATE TABLE activity_verifications (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    activity_id BIGINT NOT NULL
        REFERENCES activities(id) ON DELETE RESTRICT,

    verification_type VARCHAR(50) NOT NULL
        CHECK (
            verification_type IN (
                'CONTENT_REVIEW',
                'AGE_APPROPRIATENESS',
                'SAFETY_REVIEW',
                'ACCESSIBILITY_REVIEW',
                'REGISTRATION_REVIEW',
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

CREATE INDEX activity_verifications_activity_id_idx
ON activity_verifications (activity_id);

CREATE INDEX activity_verifications_status_idx
ON activity_verifications (verification_status);

CREATE INDEX activity_verifications_type_idx
ON activity_verifications (verification_type);
