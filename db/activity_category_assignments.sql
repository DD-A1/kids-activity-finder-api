
-- ============================================
-- DOMAIN 3: ACTIVITY CATEGORY ASSIGNMENTS
-- ============================================

CREATE TABLE activity_category_assignments (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    activity_id BIGINT NOT NULL
        REFERENCES activities(id) ON DELETE CASCADE,

    category_id BIGINT NOT NULL
        REFERENCES activity_categories(id) ON DELETE RESTRICT,

    is_primary BOOLEAN NOT NULL DEFAULT FALSE,

    assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT activity_category_assignments_unique
        UNIQUE (activity_id, category_id)
);

CREATE INDEX activity_category_assignments_category_idx
ON activity_category_assignments (category_id);

CREATE INDEX activity_category_assignments_activity_idx
ON activity_category_assignments (activity_id);
