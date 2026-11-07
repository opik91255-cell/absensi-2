import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Token login tidak ditemukan." }, 401);

    const userClient = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) return json({ error: "Sesi login tidak valid." }, 401);

    const adminClient = createClient(url, serviceKey);
    const { data: caller } = await adminClient.from("profiles").select("role").eq("id", user.id).single();
    if (caller?.role !== "admin") return json({ error: "Hanya admin yang boleh membuat akun." }, 403);

    const body = await req.json();
    const full_name = String(body.full_name ?? "").trim();
    const student_number = String(body.student_number ?? "").trim();
    const email = String(body.email ?? "").trim().toLowerCase();
    const password = String(body.password ?? "");
    if (!full_name || !student_number || !email || password.length < 8)
      return json({ error: "Lengkapi semua kolom. Password minimal 8 karakter." }, 400);

    const { data, error } = await adminClient.auth.admin.createUser({
      email, password, email_confirm: true,
      user_metadata: { full_name, student_number }
    });
    if (error) return json({ error: error.message }, 400);
    return json({ ok: true, user_id: data.user.id });
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : "Terjadi kesalahan." }, 500);
  }
});
