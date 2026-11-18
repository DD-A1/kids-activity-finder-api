
-- ============================================
-- DOMAIN 2: PROVIDER SOCIAL LINKS
-- ============================================

CREATE TABLE provider_social_links (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    provider_id BIGINT NOT NULL
        REFERENCES providers(id) ON DELETE RESTRICT,

    platform VARCHAR(30) NOT NULL
        CHECK (
            platform IN (
                'WEBSITE',
                'INSTAGRAM',
                'FACEBOOK',
                'YOUTUBE',
                'TIKTOK',
                'LINKEDIN',
                'X',
                'OTHER'
            )
        ),

    url VARCHAR(1000) NOT NULL,

    display_name VARCHAR(255),

    is_public BOOLEAN NOT NULL DEFAULT TRUE,

    display_order INTEGER NOT NULL DEFAULT 0
        CHECK (display_order >= 0),

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT provider_social_links_unique_url
        UNIQUE (provider_id, platform, url)
);

-- Provider lookup
CREATE INDEX provider_social_links_provider_id_idx
ON provider_social_links (provider_id);

-- Platform filtering
CREATE INDEX provider_social_links_platform_idx
ON provider_social_links (platform);
