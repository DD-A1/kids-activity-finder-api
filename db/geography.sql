
-- ============================================================
-- KIDS ACTIVITY FINDER
-- GEOGRAPHY SCHEMA
-- Contains all nine geographic reference tables
-- ============================================================

CREATE SCHEMA IF NOT EXISTS geography;

-- ============================================================
-- 1. STATES
-- ============================================================

CREATE TABLE IF NOT EXISTS geography.states (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country_code VARCHAR(2) NOT NULL,
    state_code VARCHAR(10) NOT NULL,
    state_name VARCHAR(100) NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT states_country_code_check
        CHECK (
            country_code = UPPER(BTRIM(country_code))
            AND CHAR_LENGTH(country_code) = 2
        ),

    CONSTRAINT states_state_code_check
        CHECK (
            state_code = UPPER(BTRIM(state_code))
            AND state_code <> ''
        ),

    CONSTRAINT states_name_check
        CHECK (BTRIM(state_name) <> ''),

    CONSTRAINT states_country_state_unique
        UNIQUE (country_code, state_code)
);

-- ============================================================
-- 2. COUNTIES
-- ============================================================

CREATE TABLE IF NOT EXISTS geography.counties (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    state_id BIGINT NOT NULL,
    county_name VARCHAR(150) NOT NULL,
    geoid VARCHAR(20) UNIQUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT counties_state_fk
        FOREIGN KEY (state_id)
        REFERENCES geography.states(id)
        ON DELETE RESTRICT,

    CONSTRAINT counties_name_check
        CHECK (BTRIM(county_name) <> ''),

    CONSTRAINT counties_geoid_check
        CHECK (geoid IS NULL OR BTRIM(geoid) <> '')
);

CREATE INDEX IF NOT EXISTS counties_state_id_idx
    ON geography.counties(state_id);

-- ============================================================
-- 3. CITIES
-- ============================================================

CREATE TABLE IF NOT EXISTS geography.cities (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    state_id BIGINT NOT NULL,
    city_name VARCHAR(150) NOT NULL,
    city_type VARCHAR(30) NOT NULL,
    geoid VARCHAR(20),

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT cities_state_fk
        FOREIGN KEY (state_id)
        REFERENCES geography.states(id)
        ON DELETE RESTRICT,

    CONSTRAINT cities_name_check
        CHECK (BTRIM(city_name) <> ''),

    CONSTRAINT cities_type_check
        CHECK (BTRIM(city_type) <> '')
);

CREATE UNIQUE INDEX IF NOT EXISTS cities_geoid_unique_idx
    ON geography.cities(geoid)
    WHERE geoid IS NOT NULL;

CREATE INDEX IF NOT EXISTS cities_state_id_idx
    ON geography.cities(state_id);

-- ============================================================
-- 4. CITY_COUNTIES
-- Connects cities to one or more counties
-- ============================================================

CREATE TABLE IF NOT EXISTS geography.city_counties (
    city_id BIGINT NOT NULL,
    county_id BIGINT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT city_counties_pk
        PRIMARY KEY (city_id, county_id),

    CONSTRAINT city_counties_city_fk
        FOREIGN KEY (city_id)
        REFERENCES geography.cities(id)
        ON DELETE CASCADE,

    CONSTRAINT city_counties_county_fk
        FOREIGN KEY (county_id)
        REFERENCES geography.counties(id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS city_counties_county_id_idx
    ON geography.city_counties(county_id);

-- ============================================================
-- 5. REGIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS geography.regions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    state_id BIGINT NOT NULL,
    region_name VARCHAR(150) NOT NULL,
    region_type VARCHAR(50) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT regions_state_fk
        FOREIGN KEY (state_id)
        REFERENCES geography.states(id)
        ON DELETE RESTRICT,

    CONSTRAINT regions_name_check
        CHECK (BTRIM(region_name) <> ''),

    CONSTRAINT regions_type_check
        CHECK (BTRIM(region_type) <> '')
);

CREATE UNIQUE INDEX IF NOT EXISTS regions_state_name_type_unique_idx
    ON geography.regions (
        state_id,
        LOWER(BTRIM(region_name)),
        UPPER(BTRIM(region_type))
    );

CREATE INDEX IF NOT EXISTS regions_state_id_idx
    ON geography.regions(state_id);

-- ============================================================
-- 6. REGION_COUNTIES
-- Connects regions to one or more counties
-- ============================================================

CREATE TABLE IF NOT EXISTS geography.region_counties (
    region_id BIGINT NOT NULL,
    county_id BIGINT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT region_counties_pk
        PRIMARY KEY (region_id, county_id),

    CONSTRAINT region_counties_region_fk
        FOREIGN KEY (region_id)
        REFERENCES geography.regions(id)
        ON DELETE CASCADE,

    CONSTRAINT region_counties_county_fk
        FOREIGN KEY (county_id)
        REFERENCES geography.counties(id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS region_counties_county_id_idx
    ON geography.region_counties(county_id);

-- ============================================================
-- 7. POSTAL_CODES
-- ============================================================

CREATE TABLE IF NOT EXISTS geography.postal_codes (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country_code VARCHAR(2) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,

    centroid public.geography(Point, 4326),

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT postal_codes_country_code_check
        CHECK (
            country_code = UPPER(BTRIM(country_code))
            AND CHAR_LENGTH(country_code) = 2
        ),

    CONSTRAINT postal_codes_code_check
        CHECK (
            BTRIM(postal_code) <> ''
            AND postal_code = BTRIM(postal_code)
        ),

    CONSTRAINT postal_codes_country_code_unique
        UNIQUE (country_code, postal_code)
);

CREATE INDEX IF NOT EXISTS postal_codes_centroid_gist_idx
    ON geography.postal_codes
    USING GIST (centroid);

-- ============================================================
-- 8. POSTAL_CODE_CITIES
-- Connects postal codes to cities
-- ============================================================

CREATE TABLE IF NOT EXISTS geography.postal_code_cities (
    postal_code_id BIGINT NOT NULL,
    city_id BIGINT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT postal_code_cities_pk
        PRIMARY KEY (postal_code_id, city_id),

    CONSTRAINT postal_code_cities_postal_fk
        FOREIGN KEY (postal_code_id)
        REFERENCES geography.postal_codes(id)
        ON DELETE CASCADE,

    CONSTRAINT postal_code_cities_city_fk
        FOREIGN KEY (city_id)
        REFERENCES geography.cities(id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS postal_code_cities_city_id_idx
    ON geography.postal_code_cities(city_id);

-- ============================================================
-- 9. POSTAL_CODE_COUNTIES
-- Connects postal codes to counties
-- ============================================================

CREATE TABLE IF NOT EXISTS geography.postal_code_counties (
    postal_code_id BIGINT NOT NULL,
    county_id BIGINT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT postal_code_counties_pk
        PRIMARY KEY (postal_code_id, county_id),

    CONSTRAINT postal_code_counties_postal_fk
        FOREIGN KEY (postal_code_id)
        REFERENCES geography.postal_codes(id)
        ON DELETE CASCADE,

    CONSTRAINT postal_code_counties_county_fk
        FOREIGN KEY (county_id)
        REFERENCES geography.counties(id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS postal_code_counties_county_id_idx
    ON geography.postal_code_counties(county_id);


-- ============================================================
-- 10. GEOGRAPHIC RELATIONSHIP VALIDATION
-- ============================================================

CREATE OR REPLACE FUNCTION geography.validate_geographic_relationship()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    first_state_id BIGINT;
    second_state_id BIGINT;
    postal_country_code VARCHAR(2);
    related_country_code VARCHAR(2);
BEGIN

    -- CITY AND COUNTY MUST BELONG TO THE SAME STATE
    IF TG_TABLE_NAME = 'city_counties' THEN

        SELECT state_id
        INTO first_state_id
        FROM geography.cities
        WHERE id = NEW.city_id;

        SELECT state_id
        INTO second_state_id
        FROM geography.counties
        WHERE id = NEW.county_id;

        IF first_state_id IS DISTINCT FROM second_state_id THEN
            RAISE EXCEPTION
                'City and county must belong to the same state.';
        END IF;

    -- REGION AND COUNTY MUST BELONG TO THE SAME STATE
    ELSIF TG_TABLE_NAME = 'region_counties' THEN

        SELECT state_id
        INTO first_state_id
        FROM geography.regions
        WHERE id = NEW.region_id;

        SELECT state_id
        INTO second_state_id
        FROM geography.counties
        WHERE id = NEW.county_id;

        IF first_state_id IS DISTINCT FROM second_state_id THEN
            RAISE EXCEPTION
                'Region and county must belong to the same state.';
        END IF;

    -- POSTAL CODE AND CITY MUST BELONG TO THE SAME COUNTRY
    ELSIF TG_TABLE_NAME = 'postal_code_cities' THEN

        SELECT pc.country_code, s.country_code
        INTO postal_country_code, related_country_code
        FROM geography.postal_codes pc
        JOIN geography.cities c
            ON c.id = NEW.city_id
        JOIN geography.states s
            ON s.id = c.state_id
        WHERE pc.id = NEW.postal_code_id;

        IF postal_country_code IS DISTINCT FROM related_country_code THEN
            RAISE EXCEPTION
                'Postal code and city must belong to the same country.';
        END IF;

    -- POSTAL CODE AND COUNTY MUST BELONG TO THE SAME COUNTRY
    ELSIF TG_TABLE_NAME = 'postal_code_counties' THEN

        SELECT pc.country_code, s.country_code
        INTO postal_country_code, related_country_code
        FROM geography.postal_codes pc
        JOIN geography.counties c
            ON c.id = NEW.county_id
        JOIN geography.states s
            ON s.id = c.state_id
        WHERE pc.id = NEW.postal_code_id;

        IF postal_country_code IS DISTINCT FROM related_country_code THEN
            RAISE EXCEPTION
                'Postal code and county must belong to the same country.';
        END IF;

    END IF;

    RETURN NEW;
END;
$$;


-- CITY_COUNTIES VALIDATION
DROP TRIGGER IF EXISTS city_counties_geography_check
ON geography.city_counties;

CREATE TRIGGER city_counties_geography_check
BEFORE INSERT OR UPDATE
ON geography.city_counties
FOR EACH ROW
EXECUTE FUNCTION geography.validate_geographic_relationship();


-- REGION_COUNTIES VALIDATION
DROP TRIGGER IF EXISTS region_counties_geography_check
ON geography.region_counties;

CREATE TRIGGER region_counties_geography_check
BEFORE INSERT OR UPDATE
ON geography.region_counties
FOR EACH ROW
EXECUTE FUNCTION geography.validate_geographic_relationship();


-- POSTAL_CODE_CITIES VALIDATION
DROP TRIGGER IF EXISTS postal_code_cities_geography_check
ON geography.postal_code_cities;

CREATE TRIGGER postal_code_cities_geography_check
BEFORE INSERT OR UPDATE
ON geography.postal_code_cities
FOR EACH ROW
EXECUTE FUNCTION geography.validate_geographic_relationship();


-- POSTAL_CODE_COUNTIES VALIDATION
DROP TRIGGER IF EXISTS postal_code_counties_geography_check
ON geography.postal_code_counties;

CREATE TRIGGER postal_code_counties_geography_check
BEFORE INSERT OR UPDATE
ON geography.postal_code_counties
FOR EACH ROW
EXECUTE FUNCTION geography.validate_geographic_relationship();


-- ============================================================
-- 11. AUTOMATIC UPDATED_AT TIMESTAMPS
-- ============================================================

CREATE OR REPLACE FUNCTION geography.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


-- STATES
DROP TRIGGER IF EXISTS states_updated_at_trigger
ON geography.states;

CREATE TRIGGER states_updated_at_trigger
BEFORE UPDATE ON geography.states
FOR EACH ROW
EXECUTE FUNCTION geography.set_updated_at();


-- COUNTIES
DROP TRIGGER IF EXISTS counties_updated_at_trigger
ON geography.counties;

CREATE TRIGGER counties_updated_at_trigger
BEFORE UPDATE ON geography.counties
FOR EACH ROW
EXECUTE FUNCTION geography.set_updated_at();


-- CITIES
DROP TRIGGER IF EXISTS cities_updated_at_trigger
ON geography.cities;

CREATE TRIGGER cities_updated_at_trigger
BEFORE UPDATE ON geography.cities
FOR EACH ROW
EXECUTE FUNCTION geography.set_updated_at();


-- REGIONS
DROP TRIGGER IF EXISTS regions_updated_at_trigger
ON geography.regions;

CREATE TRIGGER regions_updated_at_trigger
BEFORE UPDATE ON geography.regions
FOR EACH ROW
EXECUTE FUNCTION geography.set_updated_at();


-- POSTAL_CODES
DROP TRIGGER IF EXISTS postal_codes_updated_at_trigger
ON geography.postal_codes;

CREATE TRIGGER postal_codes_updated_at_trigger
BEFORE UPDATE ON geography.postal_codes
FOR EACH ROW
EXECUTE FUNCTION geography.set_updated_at();

-- ============================================================
-- 12. PROTECT GEOGRAPHIC HIERARCHY AFTER RELATIONSHIPS EXIST
-- ============================================================

CREATE OR REPLACE FUNCTION geography.prevent_invalid_hierarchy_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    -- A city's state cannot change while it has county or
    -- postal-code relationships.
    IF TG_TABLE_NAME = 'cities'
       AND OLD.state_id IS DISTINCT FROM NEW.state_id THEN

        IF EXISTS (
            SELECT 1
            FROM geography.city_counties
            WHERE city_id = OLD.id
        ) OR EXISTS (
            SELECT 1
            FROM geography.postal_code_cities
            WHERE city_id = OLD.id
        ) THEN
            RAISE EXCEPTION
                'Cannot change a city state while geographic relationships exist.';
        END IF;
    END IF;

    -- A county's state cannot change while it has city,
    -- region, or postal-code relationships.
    IF TG_TABLE_NAME = 'counties'
       AND OLD.state_id IS DISTINCT FROM NEW.state_id THEN

        IF EXISTS (
            SELECT 1
            FROM geography.city_counties
            WHERE county_id = OLD.id
        ) OR EXISTS (
            SELECT 1
            FROM geography.region_counties
            WHERE county_id = OLD.id
        ) OR EXISTS (
            SELECT 1
            FROM geography.postal_code_counties
            WHERE county_id = OLD.id
        ) THEN
            RAISE EXCEPTION
                'Cannot change a county state while geographic relationships exist.';
        END IF;
    END IF;

    -- A region's state cannot change while counties are assigned.
    IF TG_TABLE_NAME = 'regions'
       AND OLD.state_id IS DISTINCT FROM NEW.state_id THEN

        IF EXISTS (
            SELECT 1
            FROM geography.region_counties
            WHERE region_id = OLD.id
        ) THEN
            RAISE EXCEPTION
                'Cannot change a region state while counties are assigned.';
        END IF;
    END IF;

    -- A postal code's country cannot change while it has
    -- city or county relationships.
    IF TG_TABLE_NAME = 'postal_codes'
       AND OLD.country_code IS DISTINCT FROM NEW.country_code THEN

        IF EXISTS (
            SELECT 1
            FROM geography.postal_code_cities
            WHERE postal_code_id = OLD.id
        ) OR EXISTS (
            SELECT 1
            FROM geography.postal_code_counties
            WHERE postal_code_id = OLD.id
        ) THEN
            RAISE EXCEPTION
                'Cannot change a postal code country while geographic relationships exist.';
        END IF;
    END IF;

    -- A state's country cannot change if postal codes are
    -- already associated with its cities or counties.
    IF TG_TABLE_NAME = 'states'
       AND OLD.country_code IS DISTINCT FROM NEW.country_code THEN

        IF EXISTS (
            SELECT 1
            FROM geography.cities c
            JOIN geography.postal_code_cities pcc
                ON pcc.city_id = c.id
            WHERE c.state_id = OLD.id
        ) OR EXISTS (
            SELECT 1
            FROM geography.counties co
            JOIN geography.postal_code_counties pcc
                ON pcc.county_id = co.id
            WHERE co.state_id = OLD.id
        ) THEN
            RAISE EXCEPTION
                'Cannot change a state country code while postal-code relationships exist.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


-- Install hierarchy protection triggers.

DROP TRIGGER IF EXISTS cities_hierarchy_protection_trigger
ON geography.cities;

CREATE TRIGGER cities_hierarchy_protection_trigger
BEFORE UPDATE OF state_id
ON geography.cities
FOR EACH ROW
EXECUTE FUNCTION geography.prevent_invalid_hierarchy_changes();


DROP TRIGGER IF EXISTS counties_hierarchy_protection_trigger
ON geography.counties;

CREATE TRIGGER counties_hierarchy_protection_trigger
BEFORE UPDATE OF state_id
ON geography.counties
FOR EACH ROW
EXECUTE FUNCTION geography.prevent_invalid_hierarchy_changes();


DROP TRIGGER IF EXISTS regions_hierarchy_protection_trigger
ON geography.regions;

CREATE TRIGGER regions_hierarchy_protection_trigger
BEFORE UPDATE OF state_id
ON geography.regions
FOR EACH ROW
EXECUTE FUNCTION geography.prevent_invalid_hierarchy_changes();


DROP TRIGGER IF EXISTS postal_codes_hierarchy_protection_trigger
ON geography.postal_codes;

CREATE TRIGGER postal_codes_hierarchy_protection_trigger
BEFORE UPDATE OF country_code
ON geography.postal_codes
FOR EACH ROW
EXECUTE FUNCTION geography.prevent_invalid_hierarchy_changes();


DROP TRIGGER IF EXISTS states_hierarchy_protection_trigger
ON geography.states;

CREATE TRIGGER states_hierarchy_protection_trigger
BEFORE UPDATE OF country_code
ON geography.states
FOR EACH ROW
EXECUTE FUNCTION geography.prevent_invalid_hierarchy_changes();


-- =========================================================
-- CENSUS PLACE REFERENCE DATA
-- =========================================================

ALTER TABLE geography.cities
    ADD COLUMN IF NOT EXISTS census_name VARCHAR(150),
    ADD COLUMN IF NOT EXISTS census_lsad_code VARCHAR(2),
    ADD COLUMN IF NOT EXISTS census_funcstat CHAR(1),
    ADD COLUMN IF NOT EXISTS latitude NUMERIC(10, 7),
    ADD COLUMN IF NOT EXISTS longitude NUMERIC(11, 7);

-- Recreate Census constraints safely on repeated executions.
ALTER TABLE geography.cities
    DROP CONSTRAINT IF EXISTS cities_census_lsad_check,
    DROP CONSTRAINT IF EXISTS cities_census_funcstat_check,
    DROP CONSTRAINT IF EXISTS cities_coordinates_pair_check;

-- Valid Census Legal/Statistical Area Description codes.
ALTER TABLE geography.cities
    ADD CONSTRAINT cities_census_lsad_check
    CHECK (
        census_lsad_code IS NULL
        OR census_lsad_code IN (
            '00', '21', '25', '37', '43',
            '47', '53', '55', '57', '62',
            'CG', 'CN', 'MG', 'UC', 'UG'
        )
    );

-- Valid Census functional status codes.
ALTER TABLE geography.cities
    ADD CONSTRAINT cities_census_funcstat_check
    CHECK (
        census_funcstat IS NULL
        OR census_funcstat IN ('A', 'B', 'F', 'I', 'N', 'S')
    );

-- Coordinates must either both be NULL or both be valid.
ALTER TABLE geography.cities
    ADD CONSTRAINT cities_coordinates_pair_check
    CHECK (
        (latitude IS NULL AND longitude IS NULL)
        OR (
            latitude BETWEEN -90 AND 90
            AND longitude BETWEEN -180 AND 180
        )
    );

-- Allow distinct Census places to share a name and type.
-- GEOID uniquely identifies imported Census places.
DROP INDEX IF EXISTS geography.cities_state_name_type_unique_idx;

CREATE UNIQUE INDEX cities_state_name_type_unique_idx
ON geography.cities (
    state_id,
    LOWER(BTRIM(city_name)),
    UPPER(BTRIM(city_type))
)
WHERE geoid IS NULL;

-- ============================================================
-- END OF GEOGRAPHY SCHEMA
-- ============================================================

