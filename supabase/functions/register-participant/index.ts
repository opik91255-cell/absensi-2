import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(status: number, payload: Record<string, unknown>) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return reply(405, { error: "Method tidak diizinkan." });

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return reply(500, { error: "Konfigurasi server belum lengkap." });

  try {
    const body = await req.json();
    const fullName = String(body.full_name ?? "").trim();
    const username = String(body.username ?? "").trim().toLowerCase();
    const className = String(body.class_name ?? "").trim();
    const password = String(body.password ?? "");

    if (fullName.length < 2 || fullName.length > 100) return reply(400, { error: "Nama harus berisi 2 sampai 100 karakter." });
    if (!/^[a-z0-9._-]{3,30}$/.test(username)) return reply(400, { error: "Username harus 3 sampai 30 karakter: huruf, angka, titik, garis bawah, atau strip." });
    if (className.length < 1 || className.length > 80) return reply(400, { error: "Kelas wajib diisi (maksimal 80 karakter)." });
    if (password.length < 8 || password.length > 72) return reply(400, { error: "Password harus minimal 8 karakter." });

    const admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
    const { data: existing, error: lookupError } = await admin
      .from("profiles").select("id").ilike("username", username).maybeSingle();
    if (lookupError) {
      console.error("Username lookup failed", lookupError);
      return reply(500, { error: "Tidak bisa memeriksa username. Coba lagi nanti." });
    }
    if (existing) return reply(409, { error: "Username sudah digunakan. Silakan pilih username lain." });

    // Identifier email internal, bukan alamat email peserta. email_confirm=true tidak mengirim email verifikasi.
    const { data, error } = await admin.auth.admin.createUser({
      email: `${username}@login.hadir.invalid`,
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName, username, class_name: className },
    });
    if (error) {
      console.error("Participant creation failed", error);
      if (/already|registered|duplicate/i.test(error.message)) return reply(409, { error: "Username sudah digunakan. Silakan pilih username lain." });
      return reply(400, { error: "Akun belum berhasil dibuat. Periksa data dan coba lagi." });
    }
    return reply(201, { success: true, user_id: data.user.id });
  } catch (error) {
    console.error("Unexpected registration error", error);
    return reply(400, { error: "Permintaan pendaftaran tidak valid." });
  }
});
