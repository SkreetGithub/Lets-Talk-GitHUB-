-- Let Talk v10: reuse the APNs provider token (JWT) instead of signing a new one for every push.
-- Apple refuses pushes with 429 TooManyProviderTokenUpdates when a new token is made more often
-- than every 20 minutes. Tokens are valid for 60 minutes; the push functions reuse one for 50.
-- Only the service role (the push functions) can read or write this table.
CREATE TABLE IF NOT EXISTS public.apns_token_cache (
    key_id     TEXT PRIMARY KEY,
    jwt        TEXT NOT NULL,
    issued_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.apns_token_cache ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.apns_token_cache FROM anon, authenticated;
