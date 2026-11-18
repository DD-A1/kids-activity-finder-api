BEGIN;

-- Ensure cities and counties linked together belong to the same state.
CREATE OR REPLACE FUNCTION geography.check_city_county_state()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    city_state_id BIGINT;
    county_state_id BIGINT;
BEGIN
    SELECT state_id INTO city_state_id
    FROM geography.cities WHERE id = NEW.city_id;

    SELECT state_id INTO county_state_id
    FROM geography.counties WHERE id = NEW.county_id;

    IF city_state_id IS DISTINCT FROM county_state_id THEN
        RAISE EXCEPTION
            'City and county must belong to the same state.';
    END IF;

    RETURN NEW;
END;
$$;

-- Ensure regions and counties belong to the same state.
CREATE OR REPLACE FUNCTION geography.check_region_county_state()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    region_state_id BIGINT;
    county_state_id BIGINT;
BEGIN
    SELECT state_id INTO region_state_id
    FROM geography.regions WHERE id = NEW.region_id;

    SELECT state_id INTO county_state_id
    FROM geography.counties WHERE id = NEW.county_id;

    IF region_state_id IS DISTINCT FROM county_state_id THEN
        RAISE EXCEPTION
            'Region and county must belong to the same state.';
    END IF;

    RETURN NEW;
END;
$$;

-- Ensure postal-code and city country codes match.
CREATE OR REPLACE FUNCTION geography.check_postal_code_city_country()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    postal_country_code VARCHAR(2);
    city_country_code VARCHAR(2);
BEGIN
    SELECT country_code INTO postal_country_code
    FROM geography.postal_codes
    WHERE id = NEW.postal_code_id;

    SELECT s.country_code INTO city_country_code
    FROM geography.cities c
    JOIN geography.states s ON s.id = c.state_id
    WHERE c.id = NEW.city_id;

    IF postal_country_code IS DISTINCT FROM city_country_code THEN
        RAISE EXCEPTION
            'Postal code and city must belong to the same country.';
    END IF;

    RETURN NEW;
END;
$$;

-- Ensure postal-code and county country codes match.
CREATE OR REPLACE FUNCTION geography.check_postal_code_county_country()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    postal_country_code VARCHAR(2);
    county_country_code VARCHAR(2);
BEGIN
    SELECT country_code INTO postal_country_code
    FROM geography.postal_codes
    WHERE id = NEW.postal_code_id;

    SELECT s.country_code INTO county_country_code
    FROM geography.counties c
    JOIN geography.states s ON s.id = c.state_id
    WHERE c.id = NEW.county_id;

    IF postal_country_code IS DISTINCT FROM county_country_code THEN
        RAISE EXCEPTION
            'Postal code and county must belong to the same country.';
    END IF;

    RETURN NEW;
END;
$$;

-- Install consistency triggers on the four relationship tables.
DROP TRIGGER IF EXISTS city_counties_check_state
    ON geography.city_counties;
CREATE TRIGGER city_counties_check_state
BEFORE INSERT OR UPDATE ON geography.city_counties
FOR EACH ROW EXECUTE FUNCTION geography.check_city_county_state();

DROP TRIGGER IF EXISTS region_counties_check_state
    ON geography.region_counties;
CREATE TRIGGER region_counties_check_state
BEFORE INSERT OR UPDATE ON geography.region_counties
FOR EACH ROW EXECUTE FUNCTION geography.check_region_county_state();

DROP TRIGGER IF EXISTS postal_code_cities_check_country
    ON geography.postal_code_cities;
CREATE TRIGGER postal_code_cities_check_country
BEFORE INSERT OR UPDATE ON geography.postal_code_cities
FOR EACH ROW EXECUTE FUNCTION geography.check_postal_code_city_country();

DROP TRIGGER IF EXISTS postal_code_counties_check_country
    ON geography.postal_code_counties;
CREATE TRIGGER postal_code_counties_check_country
BEFORE INSERT OR UPDATE ON geography.postal_code_counties
FOR EACH ROW EXECUTE FUNCTION geography.check_postal_code_county_country();

-- Automatically maintain updated_at on the five base geography tables.
DROP TRIGGER IF EXISTS states_set_updated_at ON geography.states;
CREATE TRIGGER states_set_updated_at
BEFORE UPDATE ON geography.states
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS counties_set_updated_at ON geography.counties;
CREATE TRIGGER counties_set_updated_at
BEFORE UPDATE ON geography.counties
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS cities_set_updated_at ON geography.cities;
CREATE TRIGGER cities_set_updated_at
BEFORE UPDATE ON geography.cities
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS regions_set_updated_at ON geography.regions;
CREATE TRIGGER regions_set_updated_at
BEFORE UPDATE ON geography.regions
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS postal_codes_set_updated_at
    ON geography.postal_codes;
CREATE TRIGGER postal_codes_set_updated_at
BEFORE UPDATE ON geography.postal_codes
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

COMMIT;
