BEGIN;

-- =========================================================
-- 1. Rename existing tables to their canonical names
-- =========================================================

ALTER TABLE public.activity_schedule_rules
  RENAME TO activity_schedules;

ALTER TABLE public.activity_category_assignments
  RENAME TO activity_category_links;

ALTER TABLE public.activity_media
  RENAME TO activity_images;

ALTER TABLE public.activity_verifications
  RENAME TO activity_review_records;


-- =========================================================
-- 2. Activity category links
--    Canonical key: (activity_id, category_id)
-- =========================================================

ALTER TABLE public.activity_category_links
  ADD COLUMN provider_suggested_category TEXT;

-- Remove the old surrogate primary key.
ALTER TABLE public.activity_category_links
  DROP CONSTRAINT activity_category_assignments_pkey;

ALTER TABLE public.activity_category_links
  DROP COLUMN id;

ALTER TABLE public.activity_category_links
  DROP CONSTRAINT activity_category_assignments_unique;

ALTER TABLE public.activity_category_links
  ADD CONSTRAINT activity_category_links_pkey
  PRIMARY KEY (activity_id, category_id);



-- =========================================================
-- 3. Activity schedules
-- =========================================================

-- Remove the old provider-location relationship.
ALTER TABLE public.activity_schedules
  DROP CONSTRAINT IF EXISTS activity_schedule_rules_provider_location_id_fkey;

ALTER TABLE public.activity_schedules
  DROP COLUMN IF EXISTS provider_location_id;

ALTER TABLE public.activity_schedules
  RENAME COLUMN timezone_name TO timezone;

ALTER TABLE public.activity_schedules
  ADD COLUMN recurrence_rule TEXT;

-- Replace the old activity FK with the approved RESTRICT action.
ALTER TABLE public.activity_schedules
  DROP CONSTRAINT IF EXISTS activity_schedule_rules_activity_id_fkey;

ALTER TABLE public.activity_schedules
  ADD CONSTRAINT activity_schedules_activity_id_fkey
  FOREIGN KEY (activity_id)
  REFERENCES public.activities(id)
  ON DELETE RESTRICT;

ALTER TABLE public.activity_schedules
  ADD CONSTRAINT activity_schedules_id_activity_id_uq
  UNIQUE (id, activity_id);

CREATE INDEX activity_schedules_activity_id_idx
  ON public.activity_schedules(activity_id);


-- =========================================================
-- 4. Activity locations
-- =========================================================

CREATE TABLE public.activity_locations (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

  activity_id BIGINT NOT NULL,
  provider_location_id BIGINT,

  address_line_1 VARCHAR(255),
  address_line_2 VARCHAR(255),

  state_id BIGINT,
  county_id BIGINT,
  city_id BIGINT,
  postal_code_id BIGINT,

  online_url VARCHAR(1000),
  location_notes TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT activity_locations_activity_id_fkey
    FOREIGN KEY (activity_id)
    REFERENCES public.activities(id)
    ON DELETE RESTRICT,

  CONSTRAINT activity_locations_provider_location_id_fkey
    FOREIGN KEY (provider_location_id)
    REFERENCES public.provider_locations(id)
    ON DELETE SET NULL,

  CONSTRAINT activity_locations_state_id_fkey
    FOREIGN KEY (state_id)
    REFERENCES geography.states(id)
    ON DELETE RESTRICT,

  CONSTRAINT activity_locations_county_id_fkey
    FOREIGN KEY (county_id)
    REFERENCES geography.counties(id)
    ON DELETE RESTRICT,

  CONSTRAINT activity_locations_city_id_fkey
    FOREIGN KEY (city_id)
    REFERENCES geography.cities(id)
    ON DELETE RESTRICT,

  CONSTRAINT activity_locations_postal_code_id_fkey
    FOREIGN KEY (postal_code_id)
    REFERENCES geography.postal_codes(id)
    ON DELETE RESTRICT,

  CONSTRAINT activity_locations_id_activity_id_uq
    UNIQUE (id, activity_id)
);

CREATE INDEX activity_locations_activity_id_idx
  ON public.activity_locations(activity_id);

CREATE INDEX activity_locations_provider_location_id_idx
  ON public.activity_locations(provider_location_id);

CREATE INDEX activity_locations_state_id_idx
  ON public.activity_locations(state_id);

CREATE INDEX activity_locations_county_id_idx
  ON public.activity_locations(county_id);

CREATE INDEX activity_locations_city_id_idx
  ON public.activity_locations(city_id);

CREATE INDEX activity_locations_postal_code_id_idx
  ON public.activity_locations(postal_code_id);


-- =========================================================
-- 5. Activity images
-- =========================================================

-- Remove the old IMAGE/VIDEO restriction and VIDEO capability.
ALTER TABLE public.activity_images
  DROP CONSTRAINT IF EXISTS activity_media_media_type_check;

ALTER TABLE public.activity_images
  DROP COLUMN IF EXISTS media_type;

ALTER TABLE public.activity_images
  RENAME COLUMN display_order TO sort_order;

ALTER TABLE public.activity_images
  ADD COLUMN rights_confirmed_at TIMESTAMPTZ NOT NULL;

ALTER TABLE public.activity_images
  DROP CONSTRAINT IF EXISTS activity_media_activity_id_fkey;

ALTER TABLE public.activity_images
  ADD CONSTRAINT activity_images_activity_id_fkey
  FOREIGN KEY (activity_id)
  REFERENCES public.activities(id)
  ON DELETE RESTRICT;

CREATE INDEX activity_images_activity_id_idx
  ON public.activity_images(activity_id);


-- =========================================================
-- 6. Activity review records
-- =========================================================

ALTER TABLE public.activity_review_records
  DROP CONSTRAINT IF EXISTS activity_verifications_verification_type_check;

ALTER TABLE public.activity_review_records
  DROP CONSTRAINT IF EXISTS activity_verifications_verification_method_check;

ALTER TABLE public.activity_review_records
  DROP CONSTRAINT IF EXISTS activity_verifications_verification_status_check;

ALTER TABLE public.activity_review_records
  DROP CONSTRAINT IF EXISTS activity_verifications_activity_id_fkey;

ALTER TABLE public.activity_review_records
  DROP CONSTRAINT IF EXISTS activity_verifications_verified_by_user_id_fkey;

ALTER TABLE public.activity_review_records
  RENAME COLUMN verified_by_user_id TO reviewer_user_id;

ALTER TABLE public.activity_review_records
  RENAME COLUMN reviewer_notes TO notes;

ALTER TABLE public.activity_review_records
  RENAME COLUMN checked_at TO reviewed_at;

ALTER TABLE public.activity_review_records
  ADD COLUMN decision VARCHAR(30) NOT NULL;

ALTER TABLE public.activity_review_records
  DROP COLUMN verification_type;

ALTER TABLE public.activity_review_records
  DROP COLUMN verification_method;

ALTER TABLE public.activity_review_records
  DROP COLUMN verification_status;

ALTER TABLE public.activity_review_records
  DROP COLUMN reference_number;

ALTER TABLE public.activity_review_records
  DROP COLUMN expires_at;

ALTER TABLE public.activity_review_records
  ADD CONSTRAINT activity_review_records_activity_id_fkey
  FOREIGN KEY (activity_id)
  REFERENCES public.activities(id)
  ON DELETE RESTRICT;

ALTER TABLE public.activity_review_records
  ADD CONSTRAINT activity_review_records_reviewer_user_id_fkey
  FOREIGN KEY (reviewer_user_id)
  REFERENCES public.users(id)
  ON DELETE RESTRICT;

CREATE INDEX activity_review_records_activity_id_idx
  ON public.activity_review_records(activity_id);


-- =========================================================
-- 7. Rebuild activity sessions
-- =========================================================

-- Remove existing foreign keys before changing the relationships.
ALTER TABLE public.activity_sessions
  DROP CONSTRAINT IF EXISTS activity_sessions_activity_id_fkey;

ALTER TABLE public.activity_sessions
  DROP CONSTRAINT IF EXISTS activity_sessions_provider_location_id_fkey;

ALTER TABLE public.activity_sessions
  DROP CONSTRAINT IF EXISTS activity_sessions_schedule_rule_id_fkey;

ALTER TABLE public.activity_sessions
  DROP CONSTRAINT IF EXISTS activity_sessions_valid_time;

ALTER TABLE public.activity_sessions
  DROP CONSTRAINT IF EXISTS activity_sessions_valid_registration_deadline;

ALTER TABLE public.activity_sessions
  RENAME COLUMN schedule_rule_id TO schedule_id;

ALTER TABLE public.activity_sessions
  RENAME COLUMN session_status TO status;

ALTER TABLE public.activity_sessions
  DROP COLUMN provider_location_id;

ALTER TABLE public.activity_sessions
  DROP COLUMN starts_at;

ALTER TABLE public.activity_sessions
  DROP COLUMN ends_at;

ALTER TABLE public.activity_sessions
  DROP COLUMN registration_deadline;

ALTER TABLE public.activity_sessions
  ADD COLUMN activity_location_id BIGINT NOT NULL,
  ADD COLUMN session_date DATE NOT NULL,
  ADD COLUMN start_time TIME,
  ADD COLUMN end_time TIME,
  ADD COLUMN end_date DATE,
  ADD COLUMN timezone VARCHAR(100) NOT NULL,
  ADD COLUMN is_all_day BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN session_price NUMERIC(10,2);

ALTER TABLE public.activity_sessions
  ADD CONSTRAINT activity_sessions_activity_id_fkey
  FOREIGN KEY (activity_id)
  REFERENCES public.activities(id)
  ON DELETE RESTRICT;

ALTER TABLE public.activity_sessions
  ADD CONSTRAINT activity_sessions_location_activity_fkey
  FOREIGN KEY (activity_location_id, activity_id)
  REFERENCES public.activity_locations(id, activity_id)
  ON DELETE RESTRICT;

ALTER TABLE public.activity_sessions
  ADD CONSTRAINT activity_sessions_schedule_activity_fkey
  FOREIGN KEY (schedule_id, activity_id)
  REFERENCES public.activity_schedules(id, activity_id)
  ON DELETE SET NULL (schedule_id);

ALTER TABLE public.activity_sessions
  ADD CONSTRAINT activity_sessions_end_date_check
  CHECK (end_date IS NULL OR end_date >= session_date);

ALTER TABLE public.activity_sessions
  ADD CONSTRAINT activity_sessions_all_day_check
  CHECK (
    (is_all_day AND start_time IS NULL AND end_time IS NULL)
    OR
    (NOT is_all_day AND start_time IS NOT NULL)
  );

ALTER TABLE public.activity_sessions
  ADD CONSTRAINT activity_sessions_timezone_nonblank_check
  CHECK (nullif(btrim(timezone), '') IS NOT NULL);

ALTER TABLE public.activity_sessions
  ADD CONSTRAINT activity_sessions_session_price_check
  CHECK (session_price IS NULL OR session_price >= 0);

CREATE INDEX activity_sessions_activity_location_id_idx
  ON public.activity_sessions(activity_location_id);

CREATE INDEX activity_sessions_schedule_id_idx
  ON public.activity_sessions(schedule_id);

CREATE INDEX activity_sessions_session_date_idx
  ON public.activity_sessions(session_date);


-- =========================================================
-- 8. Activity session change history
-- =========================================================

CREATE TABLE public.activity_session_changes (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

  session_id BIGINT NOT NULL,
  changed_by_user_id INTEGER NOT NULL,

  change_type VARCHAR(50) NOT NULL,
  previous_data JSONB,
  new_data JSONB,
  reason TEXT,

  changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  admin_reviewed_at TIMESTAMPTZ,

  CONSTRAINT activity_session_changes_session_id_fkey
    FOREIGN KEY (session_id)
    REFERENCES public.activity_sessions(id)
    ON DELETE RESTRICT,

  CONSTRAINT activity_session_changes_changed_by_user_id_fkey
    FOREIGN KEY (changed_by_user_id)
    REFERENCES public.users(id)
    ON DELETE RESTRICT,

  CONSTRAINT activity_session_changes_change_type_nonblank_check
    CHECK (nullif(btrim(change_type), '') IS NOT NULL)
);

CREATE INDEX activity_session_changes_session_id_idx
  ON public.activity_session_changes(session_id);

CREATE INDEX activity_session_changes_changed_by_user_id_idx
  ON public.activity_session_changes(changed_by_user_id);


-- =========================================================
-- 9. Updated-at triggers
-- =========================================================

CREATE TRIGGER activity_schedules_updated_at_trigger
BEFORE UPDATE ON public.activity_schedules
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER activity_images_updated_at_trigger
BEFORE UPDATE ON public.activity_images
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER activity_review_records_updated_at_trigger
BEFORE UPDATE ON public.activity_review_records
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =========================================================
-- 10. Append-only session audit history
-- =========================================================

CREATE OR REPLACE FUNCTION public.prevent_activity_session_change_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION
    'Activity session change history is append-only.';
END;
$$;

CREATE TRIGGER activity_session_changes_append_only_trigger
BEFORE UPDATE OR DELETE ON public.activity_session_changes
FOR EACH ROW
EXECUTE FUNCTION public.prevent_activity_session_change_mutation();


COMMIT;
