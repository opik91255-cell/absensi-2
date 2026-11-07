# HADIR | One QR Attendance (versi pembaruan)

**Konsep:** Admin membuat sesi dan membuka sesi, lalu menampilkan **satu QR** untuk seluruh peserta. Peserta memindai QR menggunakan kamera HP atau kamera bawaan, login jika perlu, melihat nama sesi, menekan **Absen Sekarang**. Database mencatat akun yang login, menolak duplikat, dan menolak sesi tertutup.

## WAJIB: Update database project yang sudah ada
1. Pastikan `supabase/schema.sql` versi lama sudah pernah berhasil dijalankan.
2. Buka Supabase → SQL Editor → New Query, jalankan **seluruh** `supabase/migration_one_qr.sql` **satu kali**. Jangan jalankan schema.sql lama lagi.
3. Di `assets/js/config.js`, isi Project URL **tanpa `/rest/v1/`** dan Publishable/Anon Key. Jangan gunakan service_role/secret key.
4. Login admin yang sudah terdaftar, cek role `admin` di `profiles`.
5. Deploy ulang seluruh file website (Vercel atau server HTTPS), bukan hanya file HTML.
6. Buka admin → Sesi Absensi → buat sesi → Buka.
7. Buka admin → QR Sesi Bersama, pilih sesi dan tampilkan/unduh QR.
8. Login akun peserta lain di HP → scan QR → konfirmasi Absen Sekarang → cek Riwayat dan Laporan admin.

## Catatan
- Peserta **harus login**. QR tidak menyimpan identitas peserta.
- QR hanya valid saat sesi terbuka. QR berubah ketika sesi ditutup lalu dibuka kembali.
- Jika QR difoto/dibagikan saat sesi masih terbuka, pengguna lain yang punya akun peserta dapat mengaksesnya. Sistem ini tidak membuktikan lokasi fisik peserta.
- `admin/scanner.html` dan `peserta/barcode.html` adalah redirect kompatibilitas dari desain lama.
- Akun peserta baru memerlukan deployment Edge Function `create-participant` dan `delete-participant` yang ada di paket; setup detail tetap ada pada instruksi versi sebelumnya.
- Kamera web membutuhkan HTTPS atau localhost. Untuk akses langsung dari kamera bawaan HP, website harus sudah di-host pada URL yang bisa diakses HP.
- Belum ada uji integrasi dengan project Supabase milikmu, jadi lakukan tes end-to-end sebelum dipakai sungguhan.

# HADIR | Web Absensi Barcode

Website absensi QR dengan dua portal yang terpisah.

## Fitur admin
- Dashboard statistik
- Tambah dan hapus akun peserta
- Manajemen dan reset QR Code
- Membuat, membuka, dan menutup sesi absensi
- Scanner QR menggunakan kamera
- Melihat dan menghapus catatan kehadiran
- Laporan CSV
- Pengaturan profil admin

## Fitur peserta
- Dashboard pribadi
- QR Code pribadi
- Riwayat kehadiran sendiri
- Profil read-only

## Teknologi
HTML, CSS, JavaScript, Supabase Auth, PostgreSQL, RLS, Supabase Edge Functions, QRCode.js, HTML5-QRCode, Vercel.

## Identitas visual
Tema putih-biru: primary `#2563EB`, navy `#1E40AF`, background `#F8FAFC`, border `#E2E8F0`. Desain sengaja minimalis dan responsif.

## Setup Supabase
1. Buat project Supabase.
2. Jalankan seluruh `supabase/schema.sql` di SQL Editor.
3. Isi `assets/js/config.js` dengan Project URL dan anon/public key.
4. Deploy Edge Functions `create-participant` dan `delete-participant`.
5. Atur secrets Edge Functions: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`.
6. Buat akun admin pertama melalui Authentication > Users.
7. Promosikan akun tersebut melalui SQL, ganti email contoh:
   `update public.profiles set role = 'admin' where email = 'admin@contoh.com';`
8. Login melalui `login.html`.

**Keamanan:** Jangan pernah menaruh service role key di frontend. RLS membatasi peserta agar hanya membaca profil dan riwayat miliknya. Scanner dan pencatatan hadir hanya dapat dijalankan admin.

## Lokal dan deployment
Buka folder di VS Code, jalankan menggunakan Live Server. Kamera memerlukan localhost atau HTTPS. Untuk Vercel, import repository dan deploy menggunakan `vercel.json`.

## Sebelum produksi
Uji RLS dengan akun admin dan peserta yang berbeda. Gunakan password kuat, aktifkan kebijakan autentikasi yang sesuai, dan pertimbangkan audit log untuk aktivitas admin.


## Pembaruan: pendaftaran username dan daftar hadir kelas
1. Jalankan `supabase/migration_username_registration.sql` satu kali setelah schema utama dan migration One QR.
2. Di Supabase Authentication settings, nonaktifkan **Confirm email** untuk alur username internal tanpa alamat email sungguhan. Akun peserta memakai alamat internal `username@login.hadir.invalid`; jangan gunakan alamat tersebut untuk komunikasi email.
3. Peserta mendaftar lewat `daftar.html` dengan nama lengkap, username, kelas, dan password. Login menerima username/NIS (username) atau email untuk admin lama.
4. Daftar teman sekelas hanya menampilkan nama, waktu, dan status peserta yang tercatat hadir pada sesi yang sama, dan hanya dapat dibuka oleh peserta yang juga tercatat hadir pada sesi tersebut.
5. Kelas yang diketik saat pendaftaran belum diverifikasi admin. Untuk penggunaan resmi, cocokkan/validasi kelas dan NIS peserta melalui pengelola.

## Pembaruan antarmuka perangkat seluler
- Formulir peserta tidak meminta NIM/NIS, email, atau nomor identitas.
- Login peserta menggunakan username dan password; admin tetap menggunakan email dan password.
- Opsi **Ingat perangkat ini** ditampilkan pada halaman login. Supabase Auth menyimpan sesi pada penyimpanan browser secara default; logout manual atau menghapus data browser akan mengakhiri sesi tersimpan.
- Form login dan pendaftaran memakai penyesuaian viewport/scroll saat keyboard virtual terbuka agar input dan tombol tidak tertutup.

**Catatan implementasi penting:** alur username saat ini memakai alamat internal teknis `username@login.hadir.invalid` untuk menjembatani Supabase Auth. Peserta tidak mengisi email. Pastikan fungsi registrasi dan trigger database diselaraskan sebelum dipakai; jangan pernah menyimpan password sendiri atau menaruh service-role key di frontend.
