// POST { hashes: ["<sha256 hex>", ...] } -> { matches: [{ hash, user_id, name }] }
//
// Contact sync. The app sends SHA-256 hashes of the phone numbers in the user's address book
// (digits only, last 10 digits); this returns which of them belong to Let Talk accounts, using
// profiles.phone_hash (same normalization, computed by the database). Raw numbers and the
// address book are never sent or stored. At most 500 hashes per call.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const MAX_HASHES = 500;
const HASH = /^[0-9a-f]{64}$/;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const userClient = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    const body = await req.json().catch(() => ({}));
    const hashes: string[] = Array.isArray(body.hashes)
      ? [...new Set(body.hashes.map((h: unknown) => String(h).toLowerCase()).filter((h: string) => HASH.test(h)))]
      : [];
    if (hashes.length === 0) return json({ matches: [] });
    if (hashes.length > MAX_HASHES) return json({ error: `at most ${MAX_HASHES} hashes per request` }, 413);

    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data, error } = await admin.from("profiles")
      .select("id, name, phone_hash")
      .in("phone_hash", hashes)
      .neq("id", user.id);
    if (error) return json({ error: "lookup failed" }, 500);

    // Leave out people who blocked this user.
    const ids = (data ?? []).map((p) => p.id);
    let blockedBy = new Set<string>();
    if (ids.length) {
      const { data: blocks } = await admin.from("blocks").select("blocker_id")
        .eq("blocked_id", user.id).in("blocker_id", ids);
      blockedBy = new Set((blocks ?? []).map((b) => b.blocker_id));
    }

    const matches = (data ?? [])
      .filter((p) => !blockedBy.has(p.id))
      .map((p) => ({ hash: p.phone_hash, user_id: p.id, name: p.name ?? null }));
    return json({ matches });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}
