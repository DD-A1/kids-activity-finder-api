
-- ============================================
-- DOMAIN 2: PROVIDER OPERATING HOURS
-- ============================================

CREATE TABLE provider_hours (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    provider_location_id BIGINT NOT NULL
        REFERENCES provider_locations(id) ON DELETE CASCADE,

    -- Sunday = 0, Monday = 1, ... Saturday = 6
    day_of_week SMALLINT NOT NULL
        CHECK (day_of_week BETWEEN 0 AND 6),

    -- Allows multiple operating periods on the same day
    period_order SMALLINT NOT NULL DEFAULT 1
        CHECK (period_order > 0),

    opens_at TIME NOT NULL,
    closes_at TIME NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT provider_hours_valid_time_range
        CHECK (closes_at > opens_at),

    CONSTRAINT provider_hours_unique_period
        UNIQUE (provider_location_id, day_of_week, period_order)
);
