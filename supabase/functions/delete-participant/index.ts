import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
    status, headers: { ...cors, "Content-Type": "application/json" }
  });
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Token login tidak ditemukan." }, 401);
    const userClient = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) return json({ error: "Sesi login tidak valid." }, 401);
    const adminClient = createClient(url, serviceKey);
    const { data: caller } = await adminClient.from("profiles").select("role").eq("id", user.id).single();
    if (caller?.role !== "admin") return json({ error: "Hanya admin yang boleh menghapus akun." }, 403);
    const { user_id } = await req.json();
    if (!user_id || user_id === user.id) return json({ error: "ID peserta tidak valid." }, 400);
    const { data: target } = await adminClient.from("profiles").select("role").eq("id", user_id).single();
    if (!target || target.role !== "participant") return json({ error: "Akun peserta tidak ditemukan." }, 404);
    const { error } = await adminClient.auth.admin.deleteUser(user_id);
    if (error) return json({ error: error.message }, 400);
    return json({ ok: true });
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : "Terjadi kesalahan." }, 500);
  }
});
