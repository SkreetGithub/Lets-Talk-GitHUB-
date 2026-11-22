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
  // 1:1 chats this user was in (the chat list rows; their messages are deleted above).
  // Note the chat IDs first: their photos and voice notes live in folders named after them.
  const { data: chats } = await admin.from("chats").select("id").contains("participants", [id]);
  const chatIds = (chats ?? []).map((c: { id: string }) => c.id);
  await run("chats", admin.from("chats").delete().contains("participants", [id]));

  // Storage, best effort (a failure here is reported but doesn't stop the deletion).
  // Removes every file directly inside `folder` of `bucket`.
  const removeFolder = async (bucket: string, folder: string) => {
    for (;;) {
      const { data: files, error } = await admin.storage.from(bucket).list(folder, { limit: 100 });
      if (error) { errors.push(`storage ${bucket}/${folder}: ${error.message}`); return; }
      const paths = (files ?? []).filter((f) => f.id).map((f) => `${folder}/${f.name}`);
      if (!paths.length) return;
      const { error: rmErr } = await admin.storage.from(bucket).remove(paths);
      if (rmErr) { errors.push(`storage ${bucket}/${folder}: ${rmErr.message}`); return; }
    }
  };
  // Profile photos: profile-photos/<user id>/<time>.jpg (private bucket, v8).
  await removeFolder("profile-photos", id);
  // Photos, files and voice notes sent in this user's chats: chat-files|chat-audio/<chat id>/...
  for (const chatId of chatIds) {
    await removeFolder("chat-files", chatId);
    await removeFolder("chat-audio", chatId);
  }
  // Older app versions: the public bucket, under the user's folder and profile_images/<id>.jpg.
  const legacy = Deno.env.get("SUPABASE_STORAGE_BUCKET") ?? "public";
  await removeFolder(legacy, id);
  // Old profile photos are profile_images/<USER ID>_<time>.jpg (either case).
  for (const search of new Set([id, id.toUpperCase()])) {
    const { data: old } = await admin.storage.from(legacy).list("profile_images", { search, limit: 100 });
    const paths = (old ?? []).filter((f) => f.id && f.name.toLowerCase().startsWith(id.toLowerCase()))
      .map((f) => `profile_images/${f.name}`);
    if (paths.length) await admin.storage.from(legacy).remove(paths);
  }

  await run("profiles", admin.from("profiles").delete().eq("id", id));
  const { error: authErr } = await admin.auth.admin.deleteUser(id);
  if (authErr) return new Response(JSON.stringify({ error: authErr.message, partial: errors }), { status: 500, headers: corsHeaders });
  return new Response(JSON.stringify({ deleted: true, warnings: errors }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
});
