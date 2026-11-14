// POST { callee_id, caller_name, call_id, video } -> sends a PushKit VoIP push via APNs (HTTP/2, token auth).
// Needs secrets: APNS_KEY_P8 (contents of AuthKey_XXXX.p8), APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID (com.upappllc.lettalk), APNS_ENV (development|production)
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "https://esm.sh/jose@5";
// CORS headers inlined (no ../_shared_cors.ts import) so the file also deploys from the dashboard editor.
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const userClient = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return new Response("unauthorized", { status: 401, headers: corsHeaders });

  const { callee_id, caller_name, call_id, video } = await req.json();
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // Don't ring someone who blocked the caller.
  const { data: blocked } = await admin.from("blocks").select("blocker_id")
    .eq("blocker_id", callee_id).eq("blocked_id", user.id).maybeSingle();
  if (blocked) return new Response(JSON.stringify({ sent: false, reason: "blocked" }), { headers: corsHeaders });

  const { data: tok } = await admin.from("push_tokens").select("token").eq("user_id", callee_id).eq("kind", "voip").maybeSingle();
  if (!tok) return new Response(JSON.stringify({ sent: false, reason: "no token" }), { headers: corsHeaders });

  // Dashboard-pasted secrets can arrive with literal "\\n" instead of line breaks.
  const p8 = (Deno.env.get("APNS_KEY_P8") ?? "").replace(/\\n/g, "\n").trim();
  if (!p8) return new Response(JSON.stringify({ sent: false, reason: "apns not configured" }), { headers: corsHeaders });
  const key = await importPKCS8(p8, "ES256");
  const jwt = await new SignJWT({}).setProtectedHeader({ alg: "ES256", kid: Deno.env.get("APNS_KEY_ID")! })
    .setIssuer(Deno.env.get("APNS_TEAM_ID")!).setIssuedAt().sign(key);
  const host = Deno.env.get("APNS_ENV") === "production" ? "api.push.apple.com" : "api.sandbox.push.apple.com";
  const r = await fetch(`https://${host}/3/device/${tok.token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": `${Deno.env.get("APNS_BUNDLE_ID")}.voip`,
      "apns-push-type": "voip", "apns-priority": "10",
    },
    body: JSON.stringify({ caller_id: user.id, caller_name, call_id, video: !!video }),
  });
  return new Response(JSON.stringify({ sent: r.ok, status: r.status }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
});
