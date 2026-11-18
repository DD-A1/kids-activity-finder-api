BEGIN;

-- USERS
UPDATE public.users
SET email = lower(btrim(email));

ALTER TABLE public.users
  ALTER COLUMN created_at TYPE timestamptz
    USING created_at AT TIME ZONE 'America/New_York',
  ALTER COLUMN updated_at TYPE timestamptz
    USING updated_at AT TIME ZONE 'America/New_York',
  ALTER COLUMN email_verified_at TYPE timestamptz
    USING email_verified_at AT TIME ZONE 'America/New_York';

CREATE UNIQUE INDEX users_email_normalized_uq
  ON public.users (lower(btrim(email)));

-- USER ROLES
ALTER TABLE public.user_roles
  ALTER COLUMN granted_at TYPE timestamptz
    USING granted_at AT TIME ZONE 'America/New_York',
  ALTER COLUMN revoked_at TYPE timestamptz
    USING revoked_at AT TIME ZONE 'America/New_York';

CREATE UNIQUE INDEX user_roles_one_active_role_uq
  ON public.user_roles (user_id, role_code)
  WHERE revoked_at IS NULL;

ALTER TABLE public.user_roles
  ADD CONSTRAINT user_roles_revocation_after_grant_check
  CHECK (revoked_at IS NULL OR revoked_at >= granted_at);

-- PARENT PROFILES
ALTER TABLE public.parent_profiles
  ALTER COLUMN created_at TYPE timestamptz
    USING created_at AT TIME ZONE 'America/New_York',
  ALTER COLUMN updated_at TYPE timestamptz
    USING updated_at AT TIME ZONE 'America/New_York',
  ADD CONSTRAINT parent_profiles_children_count_nonnegative_check
  CHECK (household_children_count IS NULL OR household_children_count >= 0);

-- CHILD PROFILES
ALTER TABLE public.child_profiles
  ALTER COLUMN created_at TYPE timestamptz
    USING created_at AT TIME ZONE 'America/New_York',
  ALTER COLUMN updated_at TYPE timestamptz
    USING updated_at AT TIME ZONE 'America/New_York';

ALTER TABLE public.child_profiles
  DROP CONSTRAINT child_name_required,
  ADD CONSTRAINT child_name_required
    CHECK (
      nullif(btrim(first_name), '') IS NOT NULL
      OR nullif(btrim(nickname), '') IS NOT NULL
    ),
  ADD CONSTRAINT child_display_name_nonblank_check
    CHECK (nullif(btrim(display_name), '') IS NOT NULL);

-- LEGAL ACCEPTANCES
ALTER TABLE public.legal_acceptances
  ADD CONSTRAINT legal_document_version_nonblank_check
    CHECK (nullif(btrim(document_version), '') IS NOT NULL),
  ADD CONSTRAINT legal_provider_agreement_provider_check
    CHECK (
      document_type <> 'PROVIDER_AGREEMENT'
      OR provider_id IS NOT NULL
    );

-- AUTOMATIC updated_at HANDLING
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS users_updated_at_trigger ON public.users;
CREATE TRIGGER users_updated_at_trigger
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS parent_profiles_updated_at_trigger
  ON public.parent_profiles;
CREATE TRIGGER parent_profiles_updated_at_trigger
  BEFORE UPDATE ON public.parent_profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS child_profiles_updated_at_trigger
  ON public.child_profiles;
CREATE TRIGGER child_profiles_updated_at_trigger
  BEFORE UPDATE ON public.child_profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

COMMIT;
