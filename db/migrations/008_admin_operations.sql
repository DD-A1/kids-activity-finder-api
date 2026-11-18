BEGIN;

-- Shared administrative task queue
CREATE TABLE admin_tasks (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    task_type VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    priority VARCHAR(20) NOT NULL,
    status VARCHAR(30) NOT NULL,

    assignee_user_id INTEGER
        REFERENCES users(id) ON DELETE SET NULL,
    created_by_user_id INTEGER
        REFERENCES users(id) ON DELETE SET NULL,

    created_source VARCHAR(30) NOT NULL DEFAULT 'ADMIN',

    due_at TIMESTAMPTZ,
    remind_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,

    provider_id INTEGER REFERENCES providers(id) ON DELETE RESTRICT,
    provider_document_id INTEGER REFERENCES provider_documents(id) ON DELETE RESTRICT,
    provider_location_id INTEGER REFERENCES provider_locations(id) ON DELETE RESTRICT,
    provider_verification_id INTEGER REFERENCES provider_verifications(id) ON DELETE RESTRICT,
    provider_location_review_id INTEGER,
    activity_id INTEGER REFERENCES activities(id) ON DELETE RESTRICT,
    activity_session_id INTEGER REFERENCES activity_sessions(id) ON DELETE RESTRICT,
    external_event_id INTEGER REFERENCES external_events(id) ON DELETE RESTRICT,
    event_source_id INTEGER REFERENCES event_sources(id) ON DELETE RESTRICT,
    source_sync_run_id INTEGER REFERENCES source_sync_runs(id) ON DELETE RESTRICT,
    report_id INTEGER REFERENCES reports(id) ON DELETE RESTRICT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT admin_tasks_title_nonblank CHECK (BTRIM(title) <> ''),
    CONSTRAINT admin_tasks_type_nonblank CHECK (BTRIM(task_type) <> ''),
    CONSTRAINT admin_tasks_priority_nonblank CHECK (BTRIM(priority) <> ''),
    CONSTRAINT admin_tasks_status_nonblank CHECK (BTRIM(status) <> ''),
    CONSTRAINT admin_tasks_created_source_nonblank CHECK (BTRIM(created_source) <> ''),

    CONSTRAINT admin_tasks_at_most_one_target CHECK (
        num_nonnulls(
            provider_id,
            provider_document_id,
            provider_location_id,
            provider_verification_id,
            provider_location_review_id,
            activity_id,
            activity_session_id,
            external_event_id,
            event_source_id,
            source_sync_run_id,
            report_id
        ) <= 1
    )
);

CREATE INDEX admin_tasks_status_priority_idx
    ON admin_tasks (status, priority);

CREATE INDEX admin_tasks_assignee_idx
    ON admin_tasks (assignee_user_id)
    WHERE assignee_user_id IS NOT NULL;

CREATE INDEX admin_tasks_due_at_idx
    ON admin_tasks (due_at)
    WHERE due_at IS NOT NULL;

CREATE TRIGGER admin_tasks_set_updated_at
BEFORE UPDATE ON admin_tasks
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- Audit history for task changes and reassignment
CREATE TABLE admin_task_history (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    task_id BIGINT NOT NULL
        REFERENCES admin_tasks(id) ON DELETE RESTRICT,
    changed_by_user_id INTEGER
        REFERENCES users(id) ON DELETE RESTRICT,
    change_type VARCHAR(40) NOT NULL,
    previous_values JSONB,
    new_values JSONB,
    change_notes TEXT,
    change_source VARCHAR(30) NOT NULL DEFAULT 'ADMIN',
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT admin_task_history_change_type_nonblank
        CHECK (BTRIM(change_type) <> ''),
    CONSTRAINT admin_task_history_change_source_nonblank
        CHECK (BTRIM(change_source) <> '')
);

CREATE INDEX admin_task_history_task_time_idx
    ON admin_task_history (task_id, changed_at DESC);


-- Prevent normal updates or deletions of audit history
CREATE OR REPLACE FUNCTION public.prevent_admin_task_history_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'Admin task history is immutable.';
END;
$$;

CREATE TRIGGER admin_task_history_immutable
BEFORE UPDATE OR DELETE ON admin_task_history
FOR EACH ROW EXECUTE FUNCTION public.prevent_admin_task_history_changes();


-- Notifications for administrators and providers
CREATE TABLE admin_notifications (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    recipient_user_id INTEGER NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT,
    task_id BIGINT
        REFERENCES admin_tasks(id) ON DELETE SET NULL,

    notification_type VARCHAR(40) NOT NULL,
    channel VARCHAR(20) NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT,
    delivery_status VARCHAR(30) NOT NULL DEFAULT 'PENDING',

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sent_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,

    CONSTRAINT admin_notifications_type_nonblank
        CHECK (BTRIM(notification_type) <> ''),
    CONSTRAINT admin_notifications_channel_nonblank
        CHECK (BTRIM(channel) <> ''),
    CONSTRAINT admin_notifications_title_nonblank
        CHECK (BTRIM(title) <> ''),
    CONSTRAINT admin_notifications_status_nonblank
        CHECK (BTRIM(delivery_status) <> ''),
    CONSTRAINT admin_notifications_sent_after_created
        CHECK (sent_at IS NULL OR sent_at >= created_at)
);

CREATE INDEX admin_notifications_recipient_unread_idx
    ON admin_notifications (recipient_user_id, created_at DESC)
    WHERE read_at IS NULL;

CREATE INDEX admin_notifications_task_idx
    ON admin_notifications (task_id)
    WHERE task_id IS NOT NULL;

COMMIT;
