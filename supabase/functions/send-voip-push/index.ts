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

  // The callee's own Settings: Allow Calls / Call Notifications / Push Notifications switched off.
  const { data: callee } = await admin.from("profiles").select("settings").eq("id", callee_id).maybeSingle();
  const s = (callee?.settings as Record<string, any> | null) ?? {};
  if (s.privacy?.allowCalls === false || s.notifications?.calls === false || s.notifications?.push === false) {
    return new Response(JSON.stringify({ sent: false, reason: "calls muted by callee" }), { headers: corsHeaders });
  }

  const { data: tok } = await admin.from("push_tokens").select("token").eq("user_id", callee_id).eq("kind", "voip").maybeSingle();
  if (!tok) return new Response(JSON.stringify({ sent: false, reason: "no token" }), { headers: corsHeaders });

  // Dashboard-pasted secrets can arrive with literal "\\n" instead of line breaks.
  const p8 = (Deno.env.get("APNS_KEY_P8") ?? "").replace(/\\n/g, "\n").trim();
  if (!p8) return new Response(JSON.stringify({ sent: false, reason: "apns not configured" }), { headers: corsHeaders });
  const keyId = Deno.env.get("APNS_KEY_ID")!.trim(), teamId = Deno.env.get("APNS_TEAM_ID")!.trim();
  let jwt = await providerToken(admin, p8, keyId, teamId);
  // A TestFlight/App Store build has a production token, an Xcode build a sandbox one. Try the
  // configured server first and, if Apple says the token belongs to the other one, retry there.
  const primary = Deno.env.get("APNS_ENV") === "production" ? "api.push.apple.com" : "api.sandbox.push.apple.com";
  const other = primary === "api.push.apple.com" ? "api.sandbox.push.apple.com" : "api.push.apple.com";
  const send = (host: string) => fetch(`https://${host}/3/device/${tok.token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": `${Deno.env.get("APNS_BUNDLE_ID")}.voip`,
      "apns-push-type": "voip", "apns-priority": "10", "apns-expiration": "0",
    },
    body: JSON.stringify({ caller_id: user.id, caller_name, call_id, video: !!video }),
  });
  let r = await send(primary);
  let reason = r.ok ? "" : await r.text();
  if (r.status === 403 && reason.includes("ExpiredProviderToken")) {
    jwt = await providerToken(admin, p8, keyId, teamId, true);
    r = await send(primary);
    reason = r.ok ? "" : await r.text();
  }
  if (r.status === 400 && reason.includes("BadDeviceToken")) {
    r = await send(other);
    reason = r.ok ? "" : await r.text();
  }
  console.log(`voip push callee=${callee_id} status=${r.status} ${reason}`);
  if (r.status === 410) {
    await admin.from("push_tokens").delete().eq("user_id", callee_id).eq("kind", "voip");
  }
  return new Response(JSON.stringify({ sent: r.ok, status: r.status }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
});

// Apple allows a new provider token (JWT) at most every 20 minutes and accepts one for 60.
// Signing a fresh one per push got pushes refused (429 TooManyProviderTokenUpdates), so the
// token is kept in apns_token_cache and reused for 50 minutes by both push functions.
async function providerToken(admin: any, p8: string, keyId: string, teamId: string, forceNew = false): Promise<string> {
  if (!forceNew) {
    const { data } = await admin.from("apns_token_cache").select("jwt, issued_at").eq("key_id", keyId).maybeSingle();
    if (data && Date.now() - new Date(data.issued_at).getTime() < 50 * 60 * 1000) return data.jwt;
  }
  const key = await importPKCS8(p8, "ES256");
  const jwt = await new SignJWT({}).setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId).setIssuedAt().sign(key);
  await admin.from("apns_token_cache").upsert({ key_id: keyId, jwt, issued_at: new Date().toISOString() });
  return jwt;
}
