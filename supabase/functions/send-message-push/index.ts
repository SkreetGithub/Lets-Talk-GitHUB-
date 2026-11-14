// POST { message_id } -> sends the receiver a notification for a message the caller just sent,
// with the text TRANSLATED INTO THE RECEIVER'S LANGUAGE (profiles.language).
//
// Called by the sender's app right after the message is saved. Only the sender of the message
// can trigger it, nothing is sent if the receiver blocked the sender, and the database row
// keeps the original text: the receiver's app translates again (and offers "Show Original").
//
// Secrets: GOOGLE_TRANSLATE_API_KEY, and for APNs: APNS_KEY_P8, APNS_KEY_ID, APNS_TEAM_ID,
// APNS_BUNDLE_ID (com.upappllc.lettalk), APNS_ENV (development|production). Without the APNs
// secrets it returns { sent: false, reason: "apns not configured" } instead of failing.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "https://esm.sh/jose@5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const PREVIEW_CHARS = 500;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const userClient = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    const { message_id } = await req.json().catch(() => ({}));
    if (!message_id) return json({ error: "message_id required" }, 400);

    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    const { data: message } = await admin.from("messages")
      .select("id, chat_id, sender_id, receiver_id, content, type, metadata")
      .eq("id", message_id).maybeSingle();
    // Only the sender may trigger a notification for their own message.
    if (!message || message.sender_id !== user.id) return json({ error: "not found" }, 404);

    const { data: blocked } = await admin.from("blocks").select("blocker_id")
      .eq("blocker_id", message.receiver_id).eq("blocked_id", user.id).maybeSingle();
    if (blocked) return json({ sent: false, reason: "blocked" });

    const { data: tok } = await admin.from("push_tokens").select("token")
      .eq("user_id", message.receiver_id).eq("kind", "apns").maybeSingle();
    if (!tok) return json({ sent: false, reason: "no token" });

    const [{ data: sender }, { data: receiver }] = await Promise.all([
      admin.from("profiles").select("name").eq("id", user.id).maybeSingle(),
      admin.from("profiles").select("language").eq("id", message.receiver_id).maybeSingle(),
    ]);
    const target = String(receiver?.language || "en").slice(0, 2);
    const body = await notificationBody(message, target);

    const apns = apnsConfig();
    if (!apns) return json({ sent: false, reason: "apns not configured" });

    const key = await importPKCS8(apns.p8, "ES256");
    const jwt = await new SignJWT({}).setProtectedHeader({ alg: "ES256", kid: apns.keyId })
      .setIssuer(apns.teamId).setIssuedAt().sign(key);
    const host = apns.env === "production" ? "api.push.apple.com" : "api.sandbox.push.apple.com";
    const r = await fetch(`https://${host}/3/device/${tok.token}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": apns.bundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "apns-collapse-id": String(message.id).slice(0, 64),
      },
      body: JSON.stringify({
        aps: {
          alert: { title: sender?.name || "New message", body },
          sound: "default",
          "thread-id": message.chat_id,
        },
        type: "message",
        chat_id: message.chat_id,
        sender_id: user.id,
        message_id: message.id,
      }),
    });
    if (r.status === 410) {
      // The receiver's token is no longer valid (app deleted / notifications reset).
      await admin.from("push_tokens").delete().eq("user_id", message.receiver_id).eq("kind", "apns");
    }
    return json({ sent: r.ok, status: r.status });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

// The notification text: translated for text messages, a short label for everything else.
async function notificationBody(message: Record<string, unknown>, target: string): Promise<string> {
  switch (message.type) {
    case "image": return "📷 Photo";
    case "video": return "🎥 Video";
    case "audio": return "🎤 Voice message";
    case "file": return "📄 Document";
    case "location": return "📍 Location";
    case "contact": return "👤 Contact";
  }
  const original = String(message.content ?? "").slice(0, PREVIEW_CHARS);
  const source = sourceLanguage(message.metadata);
  if (!original || source === target) return original;
  try {
    const params = new URLSearchParams({ q: original, target, format: "text", key: Deno.env.get("GOOGLE_TRANSLATE_API_KEY")! });
    if (source) params.set("source", source);
    const r = await fetch(`https://translation.googleapis.com/language/translate/v2?${params}`, { method: "POST" });
    if (!r.ok) return original;
    const j = await r.json();
    return j.data?.translations?.[0]?.translatedText || original;
  } catch {
    return original;   // never drop the notification because translation failed
  }
}

// messages.metadata is saved as a JSON string by the app; accept an object too.
function sourceLanguage(metadata: unknown): string | null {
  try {
    const m = typeof metadata === "string" ? JSON.parse(metadata) : metadata;
    const lang = (m as Record<string, unknown> | null)?.lang;
    return typeof lang === "string" && lang ? lang.slice(0, 2) : null;
  } catch {
    return null;
  }
}

function apnsConfig() {
  // Secrets pasted into the dashboard often arrive with literal "\n" instead of line breaks.
  const p8 = Deno.env.get("APNS_KEY_P8")?.replace(/\\n/g, "\n").trim();
  const keyId = Deno.env.get("APNS_KEY_ID")?.trim(), teamId = Deno.env.get("APNS_TEAM_ID")?.trim();
  if (!p8 || !keyId || !teamId) return null;
  return {
    p8, keyId, teamId,
    bundleId: Deno.env.get("APNS_BUNDLE_ID") || "com.upappllc.lettalk",
    env: Deno.env.get("APNS_ENV") || "development",
  };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}
