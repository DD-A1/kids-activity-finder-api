BEGIN;

-- =========================================================
-- 1. Approved public event sources
-- =========================================================

CREATE TABLE public.event_sources (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

  source_name VARCHAR(255) NOT NULL,
  canonical_url TEXT NOT NULL,
  source_type VARCHAR(50) NOT NULL,
  collection_method VARCHAR(50) NOT NULL,
  permission_status VARCHAR(50) NOT NULL,

  terms_url TEXT,
  attribution_rule TEXT,

  refresh_interval INTERVAL NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT event_sources_name_nonblank_check
    CHECK (nullif(btrim(source_name), '') IS NOT NULL),

  CONSTRAINT event_sources_url_nonblank_check
    CHECK (nullif(btrim(canonical_url), '') IS NOT NULL),

  CONSTRAINT event_sources_type_nonblank_check
    CHECK (nullif(btrim(source_type), '') IS NOT NULL),

  CONSTRAINT event_sources_collection_method_nonblank_check
    CHECK (nullif(btrim(collection_method), '') IS NOT NULL),

  CONSTRAINT event_sources_permission_status_nonblank_check
    CHECK (nullif(btrim(permission_status), '') IS NOT NULL),

  CONSTRAINT event_sources_refresh_interval_check
    CHECK (refresh_interval > INTERVAL '0 seconds')
);


-- =========================================================
-- 2. Geographic coverage for event sources
-- Exactly one geography reference per row.
-- =========================================================

CREATE TABLE public.event_source_geographies (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

  event_source_id BIGINT NOT NULL,

  state_id BIGINT,
  county_id BIGINT,
  city_id BIGINT,
  region_id BIGINT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT event_source_geographies_source_id_fkey
    FOREIGN KEY (event_source_id)
    REFERENCES public.event_sources(id)
    ON DELETE CASCADE,

  CONSTRAINT event_source_geographies_state_id_fkey
    FOREIGN KEY (state_id)
    REFERENCES geography.states(id)
    ON DELETE RESTRICT,

  CONSTRAINT event_source_geographies_county_id_fkey
    FOREIGN KEY (county_id)
    REFERENCES geography.counties(id)
    ON DELETE RESTRICT,

  CONSTRAINT event_source_geographies_city_id_fkey
    FOREIGN KEY (city_id)
    REFERENCES geography.cities(id)
    ON DELETE RESTRICT,

  CONSTRAINT event_source_geographies_region_id_fkey
    FOREIGN KEY (region_id)
    REFERENCES geography.regions(id)
    ON DELETE RESTRICT,

  CONSTRAINT event_source_geographies_exactly_one_geography_check
    CHECK (num_nonnulls(state_id, county_id, city_id, region_id) = 1)
);

CREATE INDEX event_source_geographies_event_source_id_idx
  ON public.event_source_geographies(event_source_id);

CREATE UNIQUE INDEX event_source_geographies_state_uq
  ON public.event_source_geographies(event_source_id, state_id)
  WHERE state_id IS NOT NULL;

CREATE UNIQUE INDEX event_source_geographies_county_uq
  ON public.event_source_geographies(event_source_id, county_id)
  WHERE county_id IS NOT NULL;

CREATE UNIQUE INDEX event_source_geographies_city_uq
  ON public.event_source_geographies(event_source_id, city_id)
  WHERE city_id IS NOT NULL;

CREATE UNIQUE INDEX event_source_geographies_region_uq
  ON public.event_source_geographies(event_source_id, region_id)
  WHERE region_id IS NOT NULL;


-- =========================================================
-- 3. Source synchronization history
-- =========================================================

CREATE TABLE public.source_sync_runs (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

  event_source_id BIGINT NOT NULL,

  started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMPTZ,

  status VARCHAR(50) NOT NULL,
  records_found INTEGER NOT NULL DEFAULT 0,
  error_summary TEXT,

  CONSTRAINT source_sync_runs_event_source_id_fkey
    FOREIGN KEY (event_source_id)
    REFERENCES public.event_sources(id)
    ON DELETE RESTRICT,

  CONSTRAINT source_sync_runs_records_found_check
    CHECK (records_found >= 0),

  CONSTRAINT source_sync_runs_completed_at_check
    CHECK (completed_at IS NULL OR completed_at >= started_at),

  CONSTRAINT source_sync_runs_status_nonblank_check
    CHECK (nullif(btrim(status), '') IS NOT NULL)
);

CREATE INDEX source_sync_runs_source_started_idx
  ON public.source_sync_runs(event_source_id, started_at DESC);

CREATE INDEX source_sync_runs_status_started_idx
  ON public.source_sync_runs(status, started_at DESC);


-- =========================================================
-- 4. Recurring external event series
-- =========================================================

CREATE TABLE public.external_event_series (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

  title VARCHAR(500) NOT NULL,
  organizer_name VARCHAR(255),
  description TEXT,
  status VARCHAR(50) NOT NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT external_event_series_title_nonblank_check
    CHECK (nullif(btrim(title), '') IS NOT NULL),

  CONSTRAINT external_event_series_status_nonblank_check
    CHECK (nullif(btrim(status), '') IS NOT NULL)
);


-- =========================================================
-- 5. Individual external event occurrences
-- A standalone event has no series_id.
-- =========================================================

CREATE TABLE public.external_events (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

  external_event_series_id BIGINT,

  title VARCHAR(500) NOT NULL,
  description TEXT,

  event_date DATE NOT NULL,
  start_at TIMESTAMPTZ,
  end_at TIMESTAMPTZ,
  timezone VARCHAR(100) NOT NULL,

  venue_name VARCHAR(255),
  address_line_1 VARCHAR(255),
  address_line_2 VARCHAR(255),

  state_id BIGINT,
  county_id BIGINT,
  city_id BIGINT,
  postal_code_id BIGINT,

  price_amount NUMERIC(10,2),
  currency_code VARCHAR(3),
  registration_url TEXT,

  status VARCHAR(50) NOT NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT external_events_series_id_fkey
    FOREIGN KEY (external_event_series_id)
    REFERENCES public.external_event_series(id)
    ON DELETE SET NULL,

  CONSTRAINT external_events_state_id_fkey
    FOREIGN KEY (state_id)
    REFERENCES geography.states(id)
    ON DELETE RESTRICT,

  CONSTRAINT external_events_county_id_fkey
    FOREIGN KEY (county_id)
    REFERENCES geography.counties(id)
    ON DELETE RESTRICT,

  CONSTRAINT external_events_city_id_fkey
    FOREIGN KEY (city_id)
    REFERENCES geography.cities(id)
    ON DELETE RESTRICT,

  CONSTRAINT external_events_postal_code_id_fkey
    FOREIGN KEY (postal_code_id)
    REFERENCES geography.postal_codes(id)
    ON DELETE RESTRICT,

  CONSTRAINT external_events_title_nonblank_check
    CHECK (nullif(btrim(title), '') IS NOT NULL),

  CONSTRAINT external_events_timezone_nonblank_check
    CHECK (nullif(btrim(timezone), '') IS NOT NULL),

  CONSTRAINT external_events_status_nonblank_check
    CHECK (nullif(btrim(status), '') IS NOT NULL),

  CONSTRAINT external_events_time_order_check
    CHECK (
      start_at IS NULL
      OR end_at IS NULL
      OR end_at >= start_at
    ),

  CONSTRAINT external_events_price_check
    CHECK (price_amount IS NULL OR price_amount >= 0),

  CONSTRAINT external_events_currency_check
    CHECK (
      currency_code IS NULL
      OR currency_code ~ '^[A-Z]{3}$'
    )
);

CREATE INDEX external_events_series_id_idx
  ON public.external_events(external_event_series_id);

CREATE INDEX external_events_event_date_idx
  ON public.external_events(event_date);

CREATE INDEX external_events_status_date_idx
  ON public.external_events(status, event_date);

CREATE INDEX external_events_state_id_idx
  ON public.external_events(state_id);

CREATE INDEX external_events_county_id_idx
  ON public.external_events(county_id);

CREATE INDEX external_events_city_id_idx
  ON public.external_events(city_id);

CREATE INDEX external_events_postal_code_id_idx
  ON public.external_events(postal_code_id);


-- =========================================================
-- 6. Links between external events and their source records
-- Exactly one target: an event occurrence OR a series.
-- =========================================================

CREATE TABLE public.event_source_links (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

  external_event_id BIGINT,
  external_event_series_id BIGINT,

  event_source_id BIGINT NOT NULL,

  source_record_id TEXT,
  normalized_source_url TEXT,

  first_seen_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

  image_rights_confirmed_at TIMESTAMPTZ,
  image_attribution TEXT,

  CONSTRAINT event_source_links_event_source_id_fkey
    FOREIGN KEY (event_source_id)
    REFERENCES public.event_sources(id)
    ON DELETE RESTRICT,

  CONSTRAINT event_source_links_external_event_id_fkey
    FOREIGN KEY (external_event_id)
    REFERENCES public.external_events(id)
    ON DELETE RESTRICT,

  CONSTRAINT event_source_links_external_event_series_id_fkey
    FOREIGN KEY (external_event_series_id)
    REFERENCES public.external_event_series(id)
    ON DELETE RESTRICT,

  CONSTRAINT event_source_links_exactly_one_target_check
    CHECK (num_nonnulls(external_event_id, external_event_series_id) = 1),

  CONSTRAINT event_source_links_seen_dates_check
    CHECK (last_seen_at >= first_seen_at)
);

CREATE INDEX event_source_links_event_id_idx
  ON public.event_source_links(external_event_id);

CREATE INDEX event_source_links_series_id_idx
  ON public.event_source_links(external_event_series_id);

CREATE INDEX event_source_links_source_id_idx
  ON public.event_source_links(event_source_id);

CREATE UNIQUE INDEX event_source_links_source_record_uq
  ON public.event_source_links(event_source_id, source_record_id)
  WHERE source_record_id IS NOT NULL;

CREATE UNIQUE INDEX event_source_links_normalized_url_uq
  ON public.event_source_links(event_source_id, normalized_source_url)
  WHERE normalized_source_url IS NOT NULL
    AND nullif(btrim(normalized_source_url), '') IS NOT NULL;


-- =========================================================
-- 7. Human event review history
-- Repeated decisions are allowed.
-- =========================================================

CREATE TABLE public.event_review_records (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

  external_event_id BIGINT NOT NULL,
  reviewer_user_id INTEGER NOT NULL,

  decision VARCHAR(50) NOT NULL,
  reviewed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  notes TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT event_review_records_external_event_id_fkey
    FOREIGN KEY (external_event_id)
    REFERENCES public.external_events(id)
    ON DELETE RESTRICT,

  CONSTRAINT event_review_records_reviewer_user_id_fkey
    FOREIGN KEY (reviewer_user_id)
    REFERENCES public.users(id)
    ON DELETE RESTRICT,

  CONSTRAINT event_review_records_decision_nonblank_check
    CHECK (nullif(btrim(decision), '') IS NOT NULL)
);

CREATE INDEX event_review_records_event_id_idx
  ON public.event_review_records(external_event_id);

CREATE INDEX event_review_records_reviewer_user_id_idx
  ON public.event_review_records(reviewer_user_id);


-- =========================================================
-- 8. External event change history
-- Nullable actor supports automated source updates.
-- =========================================================

CREATE TABLE public.event_change_history (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

  external_event_id BIGINT NOT NULL,
  actor_user_id INTEGER,

  change_source VARCHAR(50) NOT NULL,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  change_summary TEXT NOT NULL,

  CONSTRAINT event_change_history_external_event_id_fkey
    FOREIGN KEY (external_event_id)
    REFERENCES public.external_events(id)
    ON DELETE RESTRICT,

  CONSTRAINT event_change_history_actor_user_id_fkey
    FOREIGN KEY (actor_user_id)
    REFERENCES public.users(id)
    ON DELETE SET NULL,

  CONSTRAINT event_change_history_change_source_nonblank_check
    CHECK (nullif(btrim(change_source), '') IS NOT NULL),

  CONSTRAINT event_change_history_summary_nonblank_check
    CHECK (nullif(btrim(change_summary), '') IS NOT NULL)
);

CREATE INDEX event_change_history_event_changed_idx
  ON public.event_change_history(external_event_id, changed_at DESC);

CREATE INDEX event_change_history_actor_user_id_idx
  ON public.event_change_history(actor_user_id);


-- =========================================================
-- 9. Updated-at triggers
-- =========================================================

CREATE TRIGGER event_sources_updated_at_trigger
BEFORE UPDATE ON public.event_sources
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER external_event_series_updated_at_trigger
BEFORE UPDATE ON public.external_event_series
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER external_events_updated_at_trigger
BEFORE UPDATE ON public.external_events
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


COMMIT;
