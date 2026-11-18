
-- ============================================
-- DOMAIN 3: ACTIVITY RECURRING SCHEDULE RULES
-- ============================================

CREATE TABLE activity_schedule_rules (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    activity_id BIGINT NOT NULL
        REFERENCES activities(id) ON DELETE CASCADE,

    provider_location_id BIGINT
        REFERENCES provider_locations(id) ON DELETE RESTRICT,

    -- 0 = Sunday, 1 = Monday, ... 6 = Saturday
    day_of_week SMALLINT NOT NULL
        CHECK (day_of_week BETWEEN 0 AND 6),

    period_order SMALLINT NOT NULL DEFAULT 1
        CHECK (period_order > 0),

    starts_at TIME NOT NULL,
    ends_at TIME NOT NULL,

    timezone_name VARCHAR(100) NOT NULL,

    effective_from DATE NOT NULL,
    effective_until DATE,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT activity_schedule_rules_valid_time
        CHECK (ends_at > starts_at),

    CONSTRAINT activity_schedule_rules_valid_dates
        CHECK (
            effective_until IS NULL
            OR effective_until >= effective_from
        ),

    CONSTRAINT activity_schedule_rules_unique_period
        UNIQUE (
            activity_id,
            day_of_week,
            period_order,
            effective_from
        )
);

CREATE INDEX activity_schedule_rules_activity_idx
ON activity_schedule_rules (activity_id);

CREATE INDEX activity_schedule_rules_location_idx
ON activity_schedule_rules (provider_location_id);

CREATE INDEX activity_schedule_rules_active_idx
ON activity_schedule_rules (is_active);
