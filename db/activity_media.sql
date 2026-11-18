
-- ============================================
-- DOMAIN 3: ACTIVITY MEDIA
-- ============================================

CREATE TABLE activity_media (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    activity_id BIGINT NOT NULL
        REFERENCES activities(id) ON DELETE CASCADE,

    media_type VARCHAR(20) NOT NULL
        CHECK (
            media_type IN ('IMAGE', 'VIDEO')
        ),

    storage_key VARCHAR(1000) NOT NULL UNIQUE,

    media_url VARCHAR(1500),

    alt_text VARCHAR(500),

    caption VARCHAR(500),

    display_order INTEGER NOT NULL DEFAULT 0
        CHECK (display_order >= 0),

    is_primary BOOLEAN NOT NULL DEFAULT FALSE,

    moderation_status VARCHAR(30) NOT NULL DEFAULT 'PENDING'
        CHECK (
            moderation_status IN (
                'PENDING',
                'APPROVED',
                'REJECTED'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX activity_media_activity_idx
ON activity_media (activity_id);

CREATE INDEX activity_media_moderation_idx
ON activity_media (moderation_status);

CREATE UNIQUE INDEX activity_media_one_primary_idx
ON activity_media (activity_id)
WHERE is_primary = TRUE;
