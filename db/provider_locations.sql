
-- ============================================
-- DOMAIN 2: PROVIDER LOCATIONS
-- ============================================

CREATE TABLE provider_locations (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    provider_id BIGINT NOT NULL
        REFERENCES providers(id) ON DELETE RESTRICT,

    location_name VARCHAR(255) NOT NULL,

    location_type VARCHAR(30) NOT NULL
        CHECK (
            location_type IN (
                'PHYSICAL',
                'ONLINE',
                'MOBILE'
            )
        ),

    -- Physical location address
    address_line_1 VARCHAR(255),
    address_line_2 VARCHAR(255),
    city VARCHAR(100),
    state_province VARCHAR(100),
    postal_code VARCHAR(20),
    country_code CHAR(2),

    -- Geographic coordinates (longitude/latitude)
    location GEOGRAPHY(POINT, 4326),

    -- Controls whether the location is publicly displayed
    is_public BOOLEAN NOT NULL DEFAULT TRUE,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Physical locations require an address
    CONSTRAINT physical_location_requires_address
        CHECK (
            location_type <> 'PHYSICAL'
            OR (
                address_line_1 IS NOT NULL
                AND city IS NOT NULL
                AND state_province IS NOT NULL
                AND country_code IS NOT NULL
            )
        ),

    -- Online and mobile locations must not expose street addresses
    CONSTRAINT nonphysical_location_no_street_address
        CHECK (
            location_type = 'PHYSICAL'
            OR (
                address_line_1 IS NULL
                AND address_line_2 IS NULL
                AND location IS NULL
            )
        )
);

-- Geographic index for nearby searches
CREATE INDEX provider_locations_geography_idx
ON provider_locations
USING GIST (location);

-- Provider lookup index
CREATE INDEX provider_locations_provider_id_idx
ON provider_locations (provider_id);
