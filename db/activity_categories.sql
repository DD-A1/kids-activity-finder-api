
-- ============================================
-- DOMAIN 3: ACTIVITY CATEGORIES
-- ============================================

CREATE TABLE activity_categories (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    parent_category_id BIGINT
        REFERENCES activity_categories(id) ON DELETE RESTRICT,

    category_code VARCHAR(75) NOT NULL UNIQUE,
    category_name VARCHAR(150) NOT NULL,
    description TEXT,

    icon_name VARCHAR(100),

    display_order INTEGER NOT NULL DEFAULT 0
        CHECK (display_order >= 0),

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX activity_categories_parent_idx
ON activity_categories (parent_category_id);

CREATE INDEX activity_categories_active_idx
ON activity_categories (is_active);
