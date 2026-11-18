
-- ============================================
-- DOMAIN 3: ACTIVITIES
-- ============================================

CREATE TABLE activities (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    provider_id BIGINT NOT NULL
        REFERENCES providers(id) ON DELETE RESTRICT,

    provider_location_id BIGINT
        REFERENCES provider_locations(id) ON DELETE RESTRICT,

    created_by_user_id INTEGER NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT,

    title VARCHAR(255) NOT NULL,
    short_description VARCHAR(500),
    description TEXT,

    activity_format VARCHAR(30) NOT NULL
        CHECK (
            activity_format IN (
                'IN_PERSON',
                'ONLINE',
                'HYBRID'
            )
        ),

    minimum_age_months SMALLINT
        CHECK (minimum_age_months >= 0),

    maximum_age_months SMALLINT
        CHECK (maximum_age_months >= 0),

    is_free BOOLEAN NOT NULL DEFAULT TRUE,

    price_amount NUMERIC(10,2),
    currency_code CHAR(3) NOT NULL DEFAULT 'USD',

    registration_url VARCHAR(1000),

    publication_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
        CHECK (
            publication_status IN (
                'DRAFT',
                'PENDING_REVIEW',
                'PUBLISHED',
                'REJECTED',
                'ARCHIVED'
            )
        ),

    published_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT activities_valid_age_range
        CHECK (
            maximum_age_months IS NULL
            OR minimum_age_months IS NULL
            OR maximum_age_months >= minimum_age_months
        ),

    CONSTRAINT activities_valid_price
        CHECK (
            (is_free = TRUE AND price_amount IS NULL)
            OR
            (is_free = FALSE AND price_amount >= 0)
        )
);

CREATE INDEX activities_provider_id_idx
ON activities (provider_id);

CREATE INDEX activities_location_id_idx
ON activities (provider_location_id);

CREATE INDEX activities_publication_status_idx
ON activities (publication_status);

CREATE INDEX activities_created_by_user_id_idx
ON activities (created_by_user_id);
