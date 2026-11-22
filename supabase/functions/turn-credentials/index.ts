// POST {} -> { iceServers: RTCIceServer[], ttl: number }
//
// Mints short-lived Cloudflare Realtime TURN credentials for the signed-in user, so the app never
// ships a TURN password. Docs: https://developers.cloudflare.com/realtime/turn/generate-credentials/
//
// Secrets (set with `supabase secrets set`):
//   CLOUDFLARE_TURN_KEY_ID         - the TURN key's ID (Cloudflare dashboard > Realtime > TURN)
//   CLOUDFLARE_TURN_KEY_API_TOKEN  - that key's API token
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared_cors.ts";

// Longer than the longest expected call; credentials expire on their own after this.
const TTL_SECONDS = 4 * 60 * 60;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    // Only signed-in users get relay credentials (stops strangers using our TURN quota).
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
    );
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    const keyId = Deno.env.get("CLOUDFLARE_TURN_KEY_ID");
    const token = Deno.env.get("CLOUDFLARE_TURN_KEY_API_TOKEN");
    if (!keyId || !token) return json({ error: "TURN is not configured" }, 503);

    const r = await fetch(
      `https://rtc.live.cloudflare.com/v1/turn/keys/${keyId}/credentials/generate-ice-servers`,
      {
        method: "POST",
        headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
        body: JSON.stringify({ ttl: TTL_SECONDS }),
      },
    );
    if (!r.ok) return json({ error: "turn provider error", status: r.status }, 502);

    const body = await r.json();
    // Drop the alternate port-53 URLs: they often time out and only slow down ICE gathering.
    const iceServers = (body.iceServers ?? []).map((server: { urls: string | string[]; username?: string; credential?: string }) => {
      const urls = (Array.isArray(server.urls) ? server.urls : [server.urls]).filter((u) => !/:53(\?|$)/.test(u));
      return { ...server, urls };
    }).filter((server: { urls: string[] }) => server.urls.length > 0);

    return json({ iceServers, ttl: TTL_SECONDS });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}
