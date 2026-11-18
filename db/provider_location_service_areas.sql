
-- ============================================
-- DOMAIN 2: PROVIDER LOCATION SERVICE AREAS
-- ============================================

CREATE TABLE provider_location_service_areas (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    provider_location_id BIGINT NOT NULL
        REFERENCES provider_locations(id) ON DELETE CASCADE,

    area_name VARCHAR(255) NOT NULL,

    coverage_type VARCHAR(30) NOT NULL
        CHECK (
            coverage_type IN (
                'RADIUS',
                'CUSTOM_POLYGON'
            )
        ),

    center_point GEOGRAPHY(POINT, 4326),

    radius_meters INTEGER,

    boundary GEOGRAPHY(MULTIPOLYGON, 4326),

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT radius_area_requires_center_and_radius
        CHECK (
            coverage_type <> 'RADIUS'
            OR (
                center_point IS NOT NULL
                AND radius_meters IS NOT NULL
                AND radius_meters > 0
                AND boundary IS NULL
            )
        ),

    CONSTRAINT polygon_area_requires_boundary
        CHECK (
            coverage_type <> 'CUSTOM_POLYGON'
            OR (
                boundary IS NOT NULL
                AND center_point IS NULL
                AND radius_meters IS NULL
            )
        )
);

CREATE INDEX provider_location_service_areas_center_idx
ON provider_location_service_areas
USING GIST (center_point);

CREATE INDEX provider_location_service_areas_boundary_idx
ON provider_location_service_areas
USING GIST (boundary);

CREATE INDEX provider_location_service_areas_location_id_idx
ON provider_location_service_areas (provider_location_id);
