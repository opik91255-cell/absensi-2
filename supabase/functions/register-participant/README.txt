HADIR - registrasi peserta tanpa email peserta

Deploy dari folder project:
  supabase functions deploy register-participant

Function menggunakan SUPABASE_URL dan SUPABASE_SERVICE_ROLE_KEY di environment server Supabase.
Jangan pernah memasukkan service_role key ke config.js atau frontend.

Peserta mengisi nama, username, kelas, dan password. Function membuat akun Auth memakai
identifier teknis username@login.hadir.invalid dengan email_confirm=true sehingga tidak
mengirim email verifikasi. Trigger public.handle_new_user() mengisi public.profiles.
Frontend lalu login memakai username + password melalui identifier internal yang sama.

Sebelum membuka pendaftaran ke publik, tambahkan CAPTCHA/Turnstile dan rate limiting.
