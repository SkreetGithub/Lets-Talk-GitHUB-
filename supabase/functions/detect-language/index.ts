// POST { text } -> { language, confidence }   (Google Translate "detect")
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared_cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401, headers: corsHeaders });
  const { text } = await req.json();
  const params = new URLSearchParams({ q: text ?? "", key: Deno.env.get("GOOGLE_TRANSLATE_API_KEY")! });
  const r = await fetch(`https://translation.googleapis.com/language/translate/v2/detect?${params}`, { method: "POST" });
  const j = await r.json();
  const d = j.data?.detections?.[0]?.[0];
  return new Response(JSON.stringify({ language: d?.language ?? null, confidence: d?.confidence ?? 0 }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } });
});
