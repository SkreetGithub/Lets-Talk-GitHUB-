-- Let Talk v9: Let Talk number rules. Safe to run more than once.
--  1. Every Let Talk number belongs to ONE account (last 10 digits are unique).
--  2. You pick a number when you sign up, then you can change it once a year.
--     Enforced here in the database, so it can't be bypassed from a modified app.
--  3. phone_changed_at records when the number was last picked or changed.

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone_changed_at TIMESTAMPTZ;

CREATE UNIQUE INDEX IF NOT EXISTS profiles_number_unique
    ON profiles (right(regexp_replace(phone, '\D', '', 'g'), 10))
    WHERE length(regexp_replace(coalesce(phone, ''), '\D', '', 'g')) >= 7;

CREATE OR REPLACE FUNCTION public.enforce_number_rules() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.phone_changed_at := CASE WHEN coalesce(NEW.phone, '') <> '' THEN now() END;
        RETURN NEW;
    END IF;

    -- The app can never set the date itself.
    NEW.phone_changed_at := OLD.phone_changed_at;

    IF coalesce(NEW.phone, '') IS DISTINCT FROM coalesce(OLD.phone, '') THEN
        -- Changing an existing number (not the first pick) within a year of the last change.
        -- Only end users are limited (auth.uid() set); admin/SQL fixes are not.
        IF coalesce(OLD.phone, '') <> ''
           AND OLD.phone_changed_at IS NOT NULL
           AND OLD.phone_changed_at > now() - interval '365 days'
           AND auth.uid() IS NOT NULL THEN
            RAISE EXCEPTION 'NUMBER_CHANGE_LIMIT:%', to_char(OLD.phone_changed_at + interval '365 days', 'YYYY-MM-DD')
                USING ERRCODE = 'P0001',
                      HINT = 'You can change your Let Talk number once a year.';
        END IF;
        IF coalesce(NEW.phone, '') <> '' THEN
            NEW.phone_changed_at := now();
        END IF;
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS profiles_number_rules ON profiles;
CREATE TRIGGER profiles_number_rules
    BEFORE INSERT OR UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION public.enforce_number_rules();

-- Is this number free? (The number picker only offers numbers nobody has.)
CREATE OR REPLACE FUNCTION public.numbers_available(candidates TEXT[]) RETURNS TEXT[]
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT coalesce(array_agg(c), '{}') FROM unnest(candidates) AS c
    WHERE NOT EXISTS (
        SELECT 1 FROM profiles p
        WHERE length(regexp_replace(coalesce(p.phone, ''), '\D', '', 'g')) >= 7
          AND right(regexp_replace(p.phone, '\D', '', 'g'), 10) = right(regexp_replace(c, '\D', '', 'g'), 10)
    );
$$;
REVOKE ALL ON FUNCTION public.numbers_available(TEXT[]) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.numbers_available(TEXT[]) TO authenticated;

NOTIFY pgrst, 'reload schema';
