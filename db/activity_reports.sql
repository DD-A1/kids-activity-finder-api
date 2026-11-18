
-- ============================================
-- DOMAIN 3: ACTIVITY REPORTS
-- ============================================

CREATE TABLE activity_reports (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    activity_id BIGINT NOT NULL
        REFERENCES activities(id) ON DELETE RESTRICT,

    report_type VARCHAR(50) NOT NULL
        CHECK (
            report_type IN (
                'INACCURATE_INFORMATION',
                'OUTDATED_LISTING',
                'INAPPROPRIATE_CONTENT',
                'SAFETY_CONCERN',
                'ACCESSIBILITY_CONCERN',
                'DUPLICATE_LISTING',
                'OTHER'
            )
        ),

    description TEXT NOT NULL,

    reporter_name VARCHAR(150),
    reporter_email VARCHAR(255),

    report_status VARCHAR(30) NOT NULL DEFAULT 'NEW'
        CHECK (
            report_status IN (
                'NEW',
                'UNDER_REVIEW',
                'RESOLVED',
                'DISMISSED'
            )
        ),

    reviewed_by_user_id INTEGER
        REFERENCES users(id) ON DELETE RESTRICT,

    reviewer_notes TEXT,

    reviewed_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX activity_reports_activity_idx
ON activity_reports (activity_id);

CREATE INDEX activity_reports_status_idx
ON activity_reports (report_status);

CREATE INDEX activity_reports_type_idx
ON activity_reports (report_type);

CREATE INDEX activity_reports_created_at_idx
ON activity_reports (created_at);
