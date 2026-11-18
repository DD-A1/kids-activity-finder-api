-- ============================================
-- DOMAIN 1: LEGAL ACCEPTANCES
-- ============================================

CREATE TABLE legal_acceptances (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INTEGER NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT,
    document_type VARCHAR(100) NOT NULL
        CHECK (
            document_type IN (
                'TERMS_OF_SERVICE',
                'PRIVACY_POLICY',
                'PROVIDER_AGREEMENT'
            )
        ),
    document_version VARCHAR(50) NOT NULL,
    accepted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    provider_id BIGINT
);
