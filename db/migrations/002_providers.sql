BEGIN;

-- Add one primary contact directly to each provider.
ALTER TABLE public.providers
    ADD COLUMN IF NOT EXISTS contact_name varchar(255),
    ADD COLUMN IF NOT EXISTS contact_email varchar(255),
    ADD COLUMN IF NOT EXISTS contact_phone varchar(50);

-- Normalize contact email addresses.
UPDATE public.providers
SET contact_email = lower(btrim(contact_email))
WHERE contact_email IS NOT NULL;

-- Replace these constraints safely if the migration is rerun.
ALTER TABLE public.providers
    DROP CONSTRAINT IF EXISTS providers_display_name_nonblank_check,
    DROP CONSTRAINT IF EXISTS providers_contact_name_nonblank_check,
    DROP CONSTRAINT IF EXISTS providers_contact_email_normalized_check,
    DROP CONSTRAINT IF EXISTS providers_contact_phone_nonblank_check,
    DROP CONSTRAINT IF EXISTS providers_contact_method_required_check;

ALTER TABLE public.providers
    ADD CONSTRAINT providers_display_name_nonblank_check
        CHECK (NULLIF(btrim(display_name), '') IS NOT NULL),
    ADD CONSTRAINT providers_contact_name_nonblank_check
        CHECK (contact_name IS NULL OR NULLIF(btrim(contact_name), '') IS NOT NULL),
    ADD CONSTRAINT providers_contact_email_normalized_check
        CHECK (
            contact_email IS NULL
            OR (
                NULLIF(btrim(contact_email), '') IS NOT NULL
                AND contact_email = lower(btrim(contact_email))
            )
        ),
    ADD CONSTRAINT providers_contact_phone_nonblank_check
        CHECK (contact_phone IS NULL OR NULLIF(btrim(contact_phone), '') IS NOT NULL),
    ADD CONSTRAINT providers_contact_method_required_check
        CHECK (
            NULLIF(btrim(contact_email), '') IS NOT NULL
            OR NULLIF(btrim(contact_phone), '') IS NOT NULL
        );

-- Reuse the shared updated_at trigger function from migration 001.
DROP TRIGGER IF EXISTS providers_updated_at_trigger
    ON public.providers;

CREATE TRIGGER providers_updated_at_trigger
    BEFORE UPDATE ON public.providers
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Retire the superseded MVP tables.
-- RESTRICT prevents dropping either table if an unexpected dependency exists.
DROP TABLE public.provider_contacts RESTRICT;
DROP TABLE public.provider_hours RESTRICT;

COMMIT;
