// POST (no body) with the user's JWT -> deletes the caller's data and auth user (Guideline 5.1.1(v)).
// Uses the service role key, which exists only inside the function runtime.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
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
  if (!user) return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401, headers: corsHeaders });

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const id = user.id;
  const errors: string[] = [];
  const run = async (label: string, p: PromiseLike<{ error: { message: string } | null }>) => {
    const { error } = await p; if (error) errors.push(`${label}: ${error.message}`);
  };

  await run("messages", admin.from("messages").delete().or(`sender_id.eq.${id},receiver_id.eq.${id}`));
  await run("calls", admin.from("calls").delete().or(`caller_id.eq.${id},callee_id.eq.${id}`));
  await run("contacts", admin.from("contacts").delete().eq("owner_id", id));
  await run("blocks", admin.from("blocks").delete().or(`blocker_id.eq.${id},blocked_id.eq.${id}`));
  await run("push_tokens", admin.from("push_tokens").delete().eq("user_id", id));
  await run("call_signals", admin.from("call_signals").delete().eq("sender_id", id));
  await run("reports", admin.from("reports").delete().eq("reporter_id", id));

  // Storage objects under the user's folder (avatars/attachments), best effort.
  const bucket = Deno.env.get("SUPABASE_STORAGE_BUCKET") ?? "public";
  const { data: files } = await admin.storage.from(bucket).list(id);
  if (files?.length) await admin.storage.from(bucket).remove(files.map((f) => `${id}/${f.name}`));

  await run("profiles", admin.from("profiles").delete().eq("id", id));
  const { error: authErr } = await admin.auth.admin.deleteUser(id);
  if (authErr) return new Response(JSON.stringify({ error: authErr.message, partial: errors }), { status: 500, headers: corsHeaders });
  return new Response(JSON.stringify({ deleted: true, warnings: errors }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
});
