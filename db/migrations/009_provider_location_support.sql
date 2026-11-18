BEGIN;

-- 1. Provider profile image gallery
CREATE TABLE provider_images (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    provider_id INTEGER NOT NULL
        REFERENCES providers(id) ON DELETE RESTRICT,
    storage_key TEXT NOT NULL,
    caption TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    rights_confirmed_at TIMESTAMPTZ NOT NULL,
    moderation_status TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,

    CONSTRAINT provider_images_storage_key_nonblank
        CHECK (BTRIM(storage_key) <> ''),
    CONSTRAINT provider_images_moderation_status_nonblank
        CHECK (BTRIM(moderation_status) <> ''),
    CONSTRAINT provider_images_sort_order_nonnegative
        CHECK (sort_order >= 0)
);

CREATE INDEX provider_images_provider_idx
    ON provider_images (provider_id);

CREATE UNIQUE INDEX provider_images_active_sort_order_unique
    ON provider_images (provider_id, sort_order)
    WHERE deleted_at IS NULL;


-- Enforce a maximum of five active images per provider.
-- Locking the provider row makes the count check transaction-safe.
CREATE OR REPLACE FUNCTION public.enforce_provider_image_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    active_image_count INTEGER;
BEGIN
    PERFORM 1
    FROM providers
    WHERE id = NEW.provider_id
    FOR UPDATE;

    IF NEW.deleted_at IS NULL THEN
        SELECT COUNT(*) INTO active_image_count
        FROM provider_images
        WHERE provider_id = NEW.provider_id
          AND deleted_at IS NULL
          AND id IS DISTINCT FROM NEW.id;

        IF active_image_count >= 5 THEN
            RAISE EXCEPTION
                'A provider may have no more than five active profile images.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER provider_images_enforce_limit
BEFORE INSERT OR UPDATE ON provider_images
FOR EACH ROW
EXECUTE FUNCTION public.enforce_provider_image_limit();


-- 2. Provider location accuracy review history
CREATE TABLE provider_location_reviews (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    provider_location_id INTEGER NOT NULL
        REFERENCES provider_locations(id) ON DELETE RESTRICT,
    reviewer_user_id INTEGER
        REFERENCES users(id) ON DELETE RESTRICT,
    status TEXT NOT NULL,
    verification_method TEXT NOT NULL,
    notes TEXT,
    evidence_reference TEXT,
    reviewed_at TIMESTAMPTZ,
    next_review_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT provider_location_reviews_status_nonblank
        CHECK (BTRIM(status) <> ''),
    CONSTRAINT provider_location_reviews_method_nonblank
        CHECK (BTRIM(verification_method) <> ''),
    CONSTRAINT provider_location_reviews_review_dates
        CHECK (
            next_review_at IS NULL
            OR reviewed_at IS NULL
            OR next_review_at >= reviewed_at
        )
);

CREATE INDEX provider_location_reviews_location_idx
    ON provider_location_reviews (provider_location_id, created_at DESC);

CREATE INDEX provider_location_reviews_reviewer_idx
    ON provider_location_reviews (reviewer_user_id)
    WHERE reviewer_user_id IS NOT NULL;


-- 3. Append-only provider location change history
CREATE TABLE provider_location_history (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    provider_location_id INTEGER NOT NULL
        REFERENCES provider_locations(id) ON DELETE RESTRICT,
    changed_by_user_id INTEGER NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT,
    previous_address JSONB,
    new_address JSONB,
    previous_geography JSONB,
    new_geography JSONB,
    previous_accuracy_status TEXT,
    new_accuracy_status TEXT,
    reason TEXT NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT provider_location_history_reason_nonblank
        CHECK (BTRIM(reason) <> '')
);

CREATE INDEX provider_location_history_location_time_idx
    ON provider_location_history (provider_location_id, changed_at DESC);


CREATE OR REPLACE FUNCTION public.prevent_provider_location_history_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'Provider location history is immutable.';
END;
$$;

CREATE TRIGGER provider_location_history_immutable
BEFORE UPDATE OR DELETE ON provider_location_history
FOR EACH ROW
EXECUTE FUNCTION public.prevent_provider_location_history_changes();


-- 4. Restore the deferred admin task relationship
ALTER TABLE admin_tasks
ADD CONSTRAINT admin_tasks_provider_location_review_fk
FOREIGN KEY (provider_location_review_id)
REFERENCES provider_location_reviews(id)
ON DELETE RESTRICT;


-- 5. Align moderation actions with the provider image gallery
ALTER TABLE moderation_actions
ADD COLUMN provider_image_id INTEGER
REFERENCES provider_images(id) ON DELETE RESTRICT;

ALTER TABLE moderation_actions
DROP CONSTRAINT moderation_actions_exactly_one_target;

ALTER TABLE moderation_actions
ADD CONSTRAINT moderation_actions_exactly_one_target CHECK (
    num_nonnulls(
        provider_id,
        activity_id,
        external_event_id,
        provider_image_id,
        activity_image_id
    ) = 1
);

CREATE INDEX moderation_actions_provider_image_idx
    ON moderation_actions (provider_image_id)
    WHERE provider_image_id IS NOT NULL;

COMMIT;
