
-- ============================================
-- DOMAIN 2: PROVIDER DOCUMENTS
-- ============================================

CREATE TABLE provider_documents (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    provider_id BIGINT NOT NULL
        REFERENCES providers(id) ON DELETE RESTRICT,

    document_type VARCHAR(50) NOT NULL
        CHECK (
            document_type IN (
                'BUSINESS_LICENSE',
                'INSURANCE_CERTIFICATE',
                'PROFESSIONAL_CERTIFICATION',
                'BACKGROUND_CHECK',
                'SAFETY_DOCUMENT',
                'OTHER'
            )
        ),

    document_name VARCHAR(255) NOT NULL,

    storage_key VARCHAR(1000) NOT NULL UNIQUE,

    mime_type VARCHAR(100) NOT NULL,

    file_size_bytes BIGINT NOT NULL
        CHECK (file_size_bytes > 0),

    document_status VARCHAR(30) NOT NULL DEFAULT 'PENDING'
        CHECK (
            document_status IN (
                'PENDING',
                'UNDER_REVIEW',
                'APPROVED',
                'REJECTED',
                'EXPIRED'
            )
        ),

    uploaded_by_user_id INTEGER NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT,

    reviewed_by_user_id INTEGER
        REFERENCES users(id) ON DELETE RESTRICT,

    reviewer_notes TEXT,

    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    reviewed_at TIMESTAMPTZ,

    expires_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Provider lookup
CREATE INDEX provider_documents_provider_id_idx
ON provider_documents (provider_id);

-- Document status filtering
CREATE INDEX provider_documents_status_idx
ON provider_documents (document_status);

-- Document type filtering
CREATE INDEX provider_documents_type_idx
ON provider_documents (document_type);
