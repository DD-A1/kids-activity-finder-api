BEGIN;

-- 1. Normalize activity category names and slugs.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'activity_categories'
      AND column_name = 'name'
  ) THEN
    EXECUTE '
      CREATE UNIQUE INDEX IF NOT EXISTS activity_categories_name_normalized_uidx
      ON public.activity_categories (lower(btrim(name)))
    ';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'activity_categories'
      AND column_name = 'slug'
  ) THEN
    EXECUTE '
      CREATE UNIQUE INDEX IF NOT EXISTS activity_categories_slug_normalized_uidx
      ON public.activity_categories (lower(btrim(slug)))
    ';
  END IF;
END $$;

-- 2. Activity session date and all-day consistency.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.activity_sessions'::regclass
      AND conname = 'activity_sessions_end_date_check'
  ) THEN
    ALTER TABLE public.activity_sessions
      ADD CONSTRAINT activity_sessions_end_date_check
      CHECK (end_date IS NULL OR end_date >= session_date);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.activity_sessions'::regclass
      AND conname = 'activity_sessions_all_day_times_check'
  ) THEN
    ALTER TABLE public.activity_sessions
      ADD CONSTRAINT activity_sessions_all_day_times_check
      CHECK (
        (is_all_day IS TRUE AND start_time IS NULL AND end_time IS NULL)
        OR
        (is_all_day IS FALSE AND start_time IS NOT NULL)
      );
  END IF;
END $$;

-- 3. Validate session timezones against PostgreSQL's timezone database.
CREATE OR REPLACE FUNCTION public.validate_activity_session_timezone()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_timezone_names
    WHERE name = NEW.timezone
  ) THEN
    RAISE EXCEPTION 'Invalid timezone: %', NEW.timezone;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS activity_sessions_timezone_check
ON public.activity_sessions;

CREATE TRIGGER activity_sessions_timezone_check
BEFORE INSERT OR UPDATE OF timezone
ON public.activity_sessions
FOR EACH ROW
EXECUTE FUNCTION public.validate_activity_session_timezone();

-- 4. Prevent duplicate source identifiers and normalized URLs.
CREATE UNIQUE INDEX IF NOT EXISTS
  event_source_links_source_record_uidx
ON public.event_source_links (event_source_id, source_record_id)
WHERE source_record_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS
  event_source_links_source_url_uidx
ON public.event_source_links (event_source_id, normalized_source_url)
WHERE normalized_source_url IS NOT NULL
  AND btrim(normalized_source_url) <> '';

-- 5. Admin task queue indexes.
-- Rename assignee_user_id to assigned_to_user_id.
ALTER TABLE public.admin_tasks
RENAME COLUMN assignee_user_id TO assigned_to_user_id;

CREATE INDEX IF NOT EXISTS
  admin_tasks_status_priority_due_idx
ON public.admin_tasks (status, priority, due_at);

CREATE INDEX IF NOT EXISTS
  admin_tasks_assigned_status_due_idx
ON public.admin_tasks (assigned_to_user_id, status, due_at);

CREATE INDEX IF NOT EXISTS
  admin_tasks_created_at_idx
ON public.admin_tasks (created_at DESC);

-- Add indexes for optional task targets when present.
DO $$
DECLARE
  col TEXT;
  target_columns TEXT[] := ARRAY[
    'provider_id',
    'provider_document_id',
    'provider_location_id',
    'provider_verification_id',
    'activity_id',
    'activity_session_id',
    'external_event_id',
    'event_source_id',
    'source_sync_run_id',
    'report_id',
    'provider_location_review_id'
  ];
BEGIN
  FOREACH col IN ARRAY target_columns LOOP
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'admin_tasks'
        AND column_name = col
    ) THEN
      EXECUTE format(
        'CREATE INDEX IF NOT EXISTS %I ON public.admin_tasks (%I)',
        'admin_tasks_' || col || '_idx',
        col
      );
    END IF;
  END LOOP;
END $$;

COMMIT;
