
-- ============================================
-- DOMAIN 3: ACTIVITY SESSIONS
-- ============================================

CREATE TABLE activity_sessions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    activity_id BIGINT NOT NULL
        REFERENCES activities(id) ON DELETE CASCADE,

    schedule_rule_id BIGINT
        REFERENCES activity_schedule_rules(id) ON DELETE SET NULL,

    provider_location_id BIGINT
        REFERENCES provider_locations(id) ON DELETE RESTRICT,

    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,

    session_status VARCHAR(30) NOT NULL DEFAULT 'SCHEDULED'
        CHECK (
            session_status IN (
                'DRAFT',
                'SCHEDULED',
                'CANCELLED',
                'COMPLETED'
            )
        ),

    capacity INTEGER
        CHECK (capacity IS NULL OR capacity > 0),

    registration_deadline TIMESTAMPTZ,

    registration_url VARCHAR(1000),

    session_notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT activity_sessions_valid_time
        CHECK (ends_at > starts_at),

    CONSTRAINT activity_sessions_valid_registration_deadline
        CHECK (
            registration_deadline IS NULL
            OR registration_deadline <= starts_at
        )
);

CREATE INDEX activity_sessions_activity_idx
ON activity_sessions (activity_id);

CREATE INDEX activity_sessions_schedule_rule_idx
ON activity_sessions (schedule_rule_id);

CREATE INDEX activity_sessions_location_idx
ON activity_sessions (provider_location_id);

CREATE INDEX activity_sessions_start_time_idx
ON activity_sessions (starts_at);

CREATE INDEX activity_sessions_status_idx
ON activity_sessions (session_status);
