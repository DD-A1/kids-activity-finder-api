BEGIN;

-- Reports submitted by parents or other users
CREATE TABLE reports (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reporter_user_id INTEGER
        REFERENCES users(id) ON DELETE SET NULL,

    provider_id INTEGER
        REFERENCES providers(id) ON DELETE RESTRICT,
    activity_id INTEGER
        REFERENCES activities(id) ON DELETE RESTRICT,
    external_event_id INTEGER
        REFERENCES external_events(id) ON DELETE RESTRICT,

    reason_code TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT reports_exactly_one_target CHECK (
        num_nonnulls(provider_id, activity_id, external_event_id) = 1
    ),
    CONSTRAINT reports_reason_nonblank
        CHECK (BTRIM(reason_code) <> ''),
    CONSTRAINT reports_status_nonblank
        CHECK (BTRIM(status) <> '')
);

CREATE INDEX reports_status_created_idx
    ON reports (status, created_at DESC);

CREATE INDEX reports_reporter_idx
    ON reports (reporter_user_id)
    WHERE reporter_user_id IS NOT NULL;

CREATE INDEX reports_provider_idx
    ON reports (provider_id)
    WHERE provider_id IS NOT NULL;

CREATE INDEX reports_activity_idx
    ON reports (activity_id)
    WHERE activity_id IS NOT NULL;

CREATE INDEX reports_event_idx
    ON reports (external_event_id)
    WHERE external_event_id IS NOT NULL;

CREATE TRIGGER reports_set_updated_at
BEFORE UPDATE ON reports
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();


-- Permanent record of moderator decisions and actions
CREATE TABLE moderation_actions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    moderator_user_id INTEGER NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT,

    provider_id INTEGER
        REFERENCES providers(id) ON DELETE RESTRICT,
    activity_id INTEGER
        REFERENCES activities(id) ON DELETE RESTRICT,
    external_event_id INTEGER
        REFERENCES external_events(id) ON DELETE RESTRICT,
    activity_image_id INTEGER
        REFERENCES activity_images(id) ON DELETE RESTRICT,

    action_code TEXT NOT NULL,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT moderation_actions_exactly_one_target CHECK (
        num_nonnulls(
            provider_id,
            activity_id,
            external_event_id,
            activity_image_id
        ) = 1
    ),
    CONSTRAINT moderation_actions_action_nonblank
        CHECK (BTRIM(action_code) <> '')
);

CREATE INDEX moderation_actions_moderator_idx
    ON moderation_actions (moderator_user_id, created_at DESC);

CREATE INDEX moderation_actions_provider_idx
    ON moderation_actions (provider_id)
    WHERE provider_id IS NOT NULL;

CREATE INDEX moderation_actions_activity_idx
    ON moderation_actions (activity_id)
    WHERE activity_id IS NOT NULL;

CREATE INDEX moderation_actions_event_idx
    ON moderation_actions (external_event_id)
    WHERE external_event_id IS NOT NULL;

CREATE INDEX moderation_actions_image_idx
    ON moderation_actions (activity_image_id)
    WHERE activity_image_id IS NOT NULL;

COMMIT;
