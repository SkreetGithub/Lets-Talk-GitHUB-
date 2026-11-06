// POST { text, source?, target, provider?: "google"|"openai" } -> { translatedText, detectedLanguage }
// Secrets (set with `supabase secrets set`): GOOGLE_TRANSLATE_API_KEY, OPENAI_API_KEY
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared_cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
    );
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    const { text, source, target, provider } = await req.json();
    if (!text || !target) return json({ error: "text and target required" }, 400);
    if (String(text).length > 5000) return json({ error: "text too long" }, 413);

    if (provider === "openai") {
      const r = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${Deno.env.get("OPENAI_API_KEY")}` },
        body: JSON.stringify({
          model: "gpt-4o-mini", temperature: 0.2, max_tokens: 1000,
          messages: [
            { role: "system", content: `Translate the user's text to language code "${target}". Return only the translation.` },
            { role: "user", content: text },
          ],
        }),
      });
      if (!r.ok) return json({ error: "provider error" }, 502);
      const j = await r.json();
      return json({ translatedText: j.choices?.[0]?.message?.content?.trim() ?? "", detectedLanguage: source ?? null });
    }

    const params = new URLSearchParams({ q: text, target, format: "text", key: Deno.env.get("GOOGLE_TRANSLATE_API_KEY")! });
    if (source && source !== "auto") params.set("source", source);
    const r = await fetch(`https://translation.googleapis.com/language/translate/v2?${params}`, { method: "POST" });
    if (!r.ok) return json({ error: "provider error" }, 502);
    const j = await r.json();
    const t = j.data?.translations?.[0];
    return json({ translatedText: t?.translatedText ?? "", detectedLanguage: t?.detectedSourceLanguage ?? source ?? null });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}
