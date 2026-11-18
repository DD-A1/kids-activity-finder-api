BEGIN;

-- Parent-saved activities
CREATE TABLE activity_favorites (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    activity_id INTEGER NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT activity_favorites_user_activity_unique
        UNIQUE (user_id, activity_id)
);

-- Parent-saved public event occurrences
CREATE TABLE event_favorites (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    external_event_id INTEGER NOT NULL
        REFERENCES external_events(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT event_favorites_user_event_unique
        UNIQUE (user_id, external_event_id)
);

-- One editable review per parent per activity or event
CREATE TABLE reviews (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    activity_id INTEGER REFERENCES activities(id) ON DELETE RESTRICT,
    external_event_id INTEGER
        REFERENCES external_events(id) ON DELETE RESTRICT,
    rating SMALLINT NOT NULL,
    review_text VARCHAR(1000),
    status TEXT NOT NULL,
    experience_attested BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT reviews_exactly_one_target
        CHECK (
            (activity_id IS NOT NULL AND external_event_id IS NULL)
            OR
            (activity_id IS NULL AND external_event_id IS NOT NULL)
        ),
    CONSTRAINT reviews_rating_range CHECK (rating BETWEEN 0 AND 5),
    CONSTRAINT reviews_experience_attested CHECK (experience_attested = TRUE)
);

CREATE UNIQUE INDEX reviews_user_activity_unique
    ON reviews (user_id, activity_id)
    WHERE activity_id IS NOT NULL;

CREATE UNIQUE INDEX reviews_user_event_unique
    ON reviews (user_id, external_event_id)
    WHERE external_event_id IS NOT NULL;

CREATE INDEX reviews_activity_status_idx
    ON reviews (activity_id, status)
    WHERE activity_id IS NOT NULL;

CREATE INDEX reviews_event_status_idx
    ON reviews (external_event_id, status)
    WHERE external_event_id IS NOT NULL;

CREATE INDEX reviews_user_idx ON reviews (user_id);

CREATE TRIGGER reviews_set_updated_at
BEFORE UPDATE ON reviews
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- Retain every event-link click, including repeat clicks
CREATE TABLE event_link_clicks (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    external_event_id INTEGER NOT NULL
        REFERENCES external_events(id) ON DELETE RESTRICT,
    clicked_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX event_link_clicks_event_time_idx
    ON event_link_clicks (external_event_id, clicked_at DESC);

-- One review prompt per parent per event occurrence
CREATE TABLE event_review_prompts (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    external_event_id INTEGER NOT NULL
        REFERENCES external_events(id) ON DELETE RESTRICT,
    prompted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    delivery_status TEXT NOT NULL,
    CONSTRAINT event_review_prompts_user_event_unique
        UNIQUE (user_id, external_event_id)
);

COMMIT;
