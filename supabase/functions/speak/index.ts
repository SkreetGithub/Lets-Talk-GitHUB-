// Translated speech in the SPEAKER's chosen voice, in the LISTENER's language (Google Cloud TTS).
//
// POST { action: "speak", voice_id: "male-3", text: "Hola", language: "es" }
//   -> { audio: "<base64 MP3>", voice: "es-ES-Wavenet-B", pitch: 0, rate: 1 }
// POST { action: "voices", language: "en" }
//   -> { language: "en-US", voices: [{ id: "male-1", gender: "male", voice: "en-US-Wavenet-B", pitch: 0, rate: 1 }, ...] }
//
// A voice ID is "<male|female>-<1..8>", not a Google voice name, so one choice works in every
// language. Slot N is the Nth WaveNet voice of that gender in the language (sorted by name).
// Languages with fewer than 8 voices of a gender reuse them with a different pitch and speed,
// so all 8 slots always sound distinct.
//
// Secret: GOOGLE_TTS_API_KEY (falls back to GOOGLE_TRANSLATE_API_KEY). The key's Google Cloud
// project needs the Cloud Text-to-Speech API enabled, with active billing.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// App language code -> Google TTS language code.
const LANGUAGES: Record<string, string> = {
  en: "en-US", es: "es-ES", fr: "fr-FR", de: "de-DE", it: "it-IT", pt: "pt-BR",
  ru: "ru-RU", ja: "ja-JP", ko: "ko-KR", zh: "cmn-CN", ar: "ar-XA", hi: "hi-IN",
};

// Variations used when a language has fewer than 8 real voices of a gender.
const VARIANTS = [
  { pitch: 0, rate: 1.0 }, { pitch: -3, rate: 0.95 }, { pitch: 3, rate: 1.05 }, { pitch: -6, rate: 1.0 },
  { pitch: 5, rate: 0.95 }, { pitch: -1.5, rate: 1.1 }, { pitch: 1.5, rate: 0.9 }, { pitch: -4.5, rate: 1.05 },
];

const MAX_CHARS = 800;

type GoogleVoice = { name: string; ssmlGender: string; languageCodes: string[] };
type Slot = { id: string; gender: "male" | "female"; voice: string; pitch: number; rate: number };

const slotCache = new Map<string, { slots: Slot[]; at: number }>();

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
    );
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    const body = await req.json().catch(() => ({}));
    const languageCode = toGoogleLanguage(body.language);
    if (!languageCode) return json({ error: "unsupported language" }, 400);

    const slots = await slotsFor(languageCode);
    if (!slots.length) return json({ error: "no voices for language" }, 502);

    if (body.action === "voices") return json({ language: languageCode, voices: slots });

    const text = String(body.text ?? "").trim();
    if (!text) return json({ error: "text required" }, 400);
    if (text.length > MAX_CHARS) return json({ error: "text too long" }, 413);

    const slot = slots.find((s) => s.id === body.voice_id) ?? slots[0];
    const r = await fetch(`https://texttospeech.googleapis.com/v1/text:synthesize?key=${apiKey()}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        input: { text },
        voice: { languageCode, name: slot.voice },
        audioConfig: { audioEncoding: "MP3", pitch: slot.pitch, speakingRate: slot.rate },
      }),
    });
    if (!r.ok) return json({ error: "provider error", status: r.status, detail: await safeText(r) }, 502);
    const j = await r.json();
    return json({ audio: j.audioContent ?? "", voice: slot.voice, pitch: slot.pitch, rate: slot.rate });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function toGoogleLanguage(value: unknown): string | null {
  const raw = String(value ?? "").trim();
  if (!raw) return null;
  const base = raw.split(/[-_]/)[0].toLowerCase();
  return LANGUAGES[base] ?? null;
}

async function slotsFor(languageCode: string): Promise<Slot[]> {
  const cached = slotCache.get(languageCode);
  if (cached && Date.now() - cached.at < 6 * 60 * 60 * 1000) return cached.slots;

  const r = await fetch(`https://texttospeech.googleapis.com/v1/voices?languageCode=${languageCode}&key=${apiKey()}`);
  if (!r.ok) throw new Error(`voices list failed (${r.status}): ${await safeText(r)}`);
  const all: GoogleVoice[] = ((await r.json()).voices ?? [])
    .filter((v: GoogleVoice) => v.languageCodes?.includes(languageCode));

  const slots: Slot[] = [];
  for (const gender of ["male", "female"] as const) {
    const ofGender = all.filter((v) => v.ssmlGender === gender.toUpperCase());
    // WaveNet first; if a language has none of this gender, fall back to Standard voices.
    let pool = ofGender.filter((v) => v.name.includes("-Wavenet-"));
    if (!pool.length) pool = ofGender.filter((v) => v.name.includes("-Standard-"));
    pool.sort((a, b) => a.name.localeCompare(b.name));
    if (!pool.length) continue;
    for (let i = 0; i < 8; i++) {
      const variant = VARIANTS[Math.floor(i / pool.length)] ?? VARIANTS[0];
      slots.push({ id: `${gender}-${i + 1}`, gender, voice: pool[i % pool.length].name, ...variant });
    }
  }
  slotCache.set(languageCode, { slots, at: Date.now() });
  return slots;
}

// GOOGLE_TTS_API_KEY: a Let Talk key (project let-talk-4) restricted to Cloud Text-to-Speech.
// Falls back to GOOGLE_TRANSLATE_API_KEY until that secret is added.
function apiKey(): string {
  const key = Deno.env.get("GOOGLE_TTS_API_KEY") || Deno.env.get("GOOGLE_TRANSLATE_API_KEY");
  if (!key) throw new Error("GOOGLE_TTS_API_KEY is not set");
  return encodeURIComponent(key);
}

async function safeText(r: Response): Promise<string> {
  try { return (await r.text()).slice(0, 300); } catch { return ""; }
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}
