
-- ============================================
-- DOMAIN 3: ACTIVITY REQUIREMENTS
-- ============================================

CREATE TABLE activity_requirements (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    activity_id BIGINT NOT NULL
        REFERENCES activities(id) ON DELETE CASCADE,

    requirement_type VARCHAR(40) NOT NULL
        CHECK (
            requirement_type IN (
                'WHAT_TO_BRING',
                'PREREQUISITE',
                'CLOTHING',
                'EQUIPMENT',
                'REGISTRATION',
                'OTHER'
            )
        ),

    title VARCHAR(255) NOT NULL,

    description TEXT,

    is_mandatory BOOLEAN NOT NULL DEFAULT FALSE,

    display_order INTEGER NOT NULL DEFAULT 0
        CHECK (display_order >= 0),

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX activity_requirements_activity_idx
ON activity_requirements (activity_id);

CREATE INDEX activity_requirements_type_idx
ON activity_requirements (requirement_type);
