
-- ============================================
-- DOMAIN 2: PROVIDER CONTACTS
-- ============================================

CREATE TABLE provider_contacts (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    provider_id BIGINT NOT NULL
        REFERENCES providers(id) ON DELETE RESTRICT,

    contact_type VARCHAR(30) NOT NULL
        CHECK (
            contact_type IN (
                'GENERAL',
                'REGISTRATION',
                'ACCESSIBILITY',
                'EMERGENCY',
                'OTHER'
            )
        ),

    contact_name VARCHAR(255),

    job_title VARCHAR(150),

    email VARCHAR(255),

    phone VARCHAR(30),

    extension VARCHAR(10),

    is_public BOOLEAN NOT NULL DEFAULT FALSE,

    is_primary BOOLEAN NOT NULL DEFAULT FALSE,

    display_order INTEGER NOT NULL DEFAULT 0
        CHECK (display_order >= 0),

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT provider_contacts_require_contact_method
        CHECK (
            email IS NOT NULL
            OR phone IS NOT NULL
        )
);

-- Provider lookup
CREATE INDEX provider_contacts_provider_id_idx
ON provider_contacts (provider_id);

-- Contact type filtering
CREATE INDEX provider_contacts_type_idx
ON provider_contacts (contact_type);

-- Public contact lookup
CREATE INDEX provider_contacts_public_idx
ON provider_contacts (provider_id, is_public);
