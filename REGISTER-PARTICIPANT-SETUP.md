# Mengaktifkan pendaftaran peserta HADIR tanpa email

1. Pastikan `assets/js/config.js` berisi Project URL dan Publishable Key project Supabase. Jangan pernah menaruh service_role key di frontend.
2. Dari folder utama project (folder yang berisi `supabase/`), jalankan:

```bash
supabase login
supabase link --project-ref qcaixkrnpbutcwrruoyl
supabase functions deploy register-participant
```

3. Migration `supabase/migration_username_registration.sql` harus sudah diterapkan. Pastikan trigger `handle_new_user` aktif, kolom `username` dan `class_name` tersedia, serta indeks unik username terpasang. Jangan menjalankan ulang migration tanpa memeriksa status database.
4. Tes menggunakan username baru, nama, kelas, dan password minimal 8 karakter. Pendaftaran seharusnya membuat akun Auth terkonfirmasi tanpa mengirim email lalu login otomatis. Login admin tetap memakai email.

## Keamanan

Function membuat akun dengan service role hanya di server. Jangan memasukkan service-role key ke HTML, JavaScript frontend, GitHub, atau browser. Sebelum pendaftaran dibuka untuk umum, tambahkan CAPTCHA/Turnstile dan rate limiting.
