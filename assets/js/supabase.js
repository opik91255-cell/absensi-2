const db = window.supabase.createClient(
  window.SUPABASE_URL,
  window.SUPABASE_ANON_KEY
);

function usernameEmail(value) {
  const username = String(value || "").trim().toLowerCase();
  return username + "@login.hadir.invalid";
}

async function currentProfile() {
  const { data: { user }, error } = await db.auth.getUser();
  if (error || !user) return null;
  const { data, error: profileError } = await db
    .from("profiles").select("*").eq("id", user.id).single();
  if (profileError) throw profileError;
  return data;
}

async function requireRole(role) {
  const profile = await currentProfile();
  if (!profile) {
    location.href = "../login.html";
    return null;
  }
  if (profile.role !== role) {
    location.href = profile.role === "admin" ? "../admin/index.html" : "../peserta/index.html";
    return null;
  }
  return profile;
}

async function signOut() {
  await db.auth.signOut();
  location.href = "../login.html";
}

function showMessage(target, message, kind = "info") {
  const el = document.querySelector(target);
  if (!el) return;
  el.textContent = message;
  el.className = `notice ${kind}`;
  el.hidden = false;
}
