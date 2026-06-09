# KasWarga

KasWarga adalah aplikasi Flutter Web/PWA untuk iuran warga, kas komunitas,
pengumuman, dan laporan operasional RT/RW, komplek, apartemen kecil, masjid,
sekolah, serta organisasi lokal Indonesia.

UI menggunakan Bahasa Indonesia, responsif untuk browser mobile dan desktop,
serta menyediakan mode demo lokal ketika konfigurasi Supabase belum diberikan.

## Tech Stack

- Flutter Web / PWA dan Material 3
- Riverpod untuk state management
- `go_router` untuk auth guard dan role guard
- Supabase Auth, PostgreSQL, RPC, Row Level Security, dan Storage
- CSV export yang kompatibel dengan regional Excel Indonesia

## Fitur MVP

- Register, login email/password, login nomor HP/password, lupa password, logout
- Routing untuk `super_admin`, `admin`, dan `member`
- Dashboard platform, admin komunitas, dan warga
- Manajemen komunitas, user, anggota, rekening tujuan, dan iuran bulanan
- Generate tagihan untuk anggota aktif
- Transfer manual, pilih rekening, upload bukti, approval/reject admin
- Pengeluaran kas dan upload nota
- Pengumuman yang dapat dipin
- Ringkasan kas: iuran lunas dikurangi pengeluaran
- Laporan pembayaran, pengeluaran, dan transfer per rekening ke CSV
- PWA manifest, ikon, theme color, dan Flutter service worker saat build

## Struktur Project

```text
lib/
  main.dart
  app.dart
  core/
    config/
    constants/
    routing/
    theme/
    utils/
    widgets/
  features/
    auth/
    dashboard/
    communities/
    members/
    dues/
    bills/
    payment_accounts/
    expenses/
    announcements/
    reports/
    profile/
  shared/
    models/
    providers/
    services/
supabase/
  migrations/
  seed.sql
test/
web/
```

Repository aplikasi otomatis memakai Supabase jika `SUPABASE_URL` dan
`SUPABASE_ANON_KEY` tersedia. Tanpa keduanya, aplikasi memakai data demo lokal
untuk memudahkan review UI.

## Prasyarat

1. Flutter stable dengan dukungan Web.
2. Chrome.
3. Supabase CLI untuk database lokal atau project Supabase cloud.
4. Docker jika menjalankan Supabase lokal.

Periksa instalasi:

```bash
flutter doctor
flutter config --enable-web
supabase --version
```

## Setup Supabase

### Supabase lokal

```bash
supabase init
supabase start
supabase db reset
```

`supabase db reset` menjalankan migration di
`supabase/migrations/202606090001_initial_schema.sql` dan `supabase/seed.sql`.

### Supabase cloud

Tautkan repo ke project:

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

Untuk seed development, jalankan `supabase/seed.sql` melalui SQL Editor.
Jangan menjalankan akun demo pada database production.

Migration membuat:

- Semua tabel dan index
- Trigger `updated_at`
- Trigger pembuatan profil setelah user Auth dibuat
- RPC `get_email_by_phone(normalized_phone text)`
- RPC `generate_bills_for_due(target_due_id uuid)`
- RPC `verify_bill_payment(...)`
- RPC `get_community_cash_summary()`
- RLS untuk seluruh tabel
- Bucket privat `payment_proofs` dan `expense_receipts`
- Policy Storage berdasarkan folder `community_id/user_id/file`

## Environment

Nilai contoh tersedia di `.env.example`. Aplikasi menggunakan compile-time
environment agar secret tidak dibundel dari file `.env`.

Jalankan lokal:

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=APP_ENV=development
```

Anon key aman digunakan di frontend selama RLS aktif. Jangan pernah memberikan
service role key ke Flutter Web.

Untuk melihat mode demo tanpa Supabase:

```bash
flutter pub get
flutter run -d chrome
```

## Akun Demo

Semua password: `password123`.

| Role | Email | Nomor HP |
|---|---|---|
| Super Admin | `superadmin@kaswarga.local` | `+628111111110` |
| Admin | `admin@kaswarga.local` | `+628111111111` |
| Member 1 | `member1@kaswarga.local` | `+628111111112` |
| Member 2 | `member2@kaswarga.local` | `+628111111113` |
| Member 3 | `member3@kaswarga.local` | `+628111111114` |

Login email mengirim email/password langsung ke Supabase Auth.

Login nomor HP menormalisasi `08...`, `62...`, atau `+62...` menjadi `+62`,
memanggil RPC `get_email_by_phone`, lalu memakai email hasil lookup untuk
`signInWithPassword`. RPC hanya mengembalikan email nullable dan tidak
mengembalikan id, role, komunitas, atau profil lain.

## Flow Pembayaran

1. Admin mengatur minimal satu rekening tujuan aktif.
2. Admin membuat iuran bulanan.
3. RPC menghasilkan satu tagihan untuk setiap anggota aktif.
4. Warga membuka detail tagihan dan memilih rekening tujuan.
5. Warga transfer di luar aplikasi.
6. Warga memilih tanggal dan mengunggah gambar bukti maksimal 5 MB.
7. Status berubah menjadi `waiting_verification`.
8. Admin memeriksa bukti, rekening tujuan, dan nominal.
9. Admin menyetujui menjadi `paid` atau menolak menjadi `rejected`.
10. Penolakan wajib memiliki alasan.

Saldo kas dihitung dari total tagihan `paid` dikurangi total pengeluaran.

## Test dan Quality Check

```bash
dart format .
flutter analyze
flutter test
```

Test dasar meliputi format Rupiah, tanggal Indonesia, status tagihan, nomor
rekening, normalisasi/validasi/masking nomor HP, deteksi identifier login, dan
role route guard.

## Build PWA

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=APP_ENV=production
```

Output berada di `build/web`. Flutter menghasilkan service worker untuk cache
app shell. Deploy direktori tersebut ke Firebase Hosting, Cloudflare Pages,
Netlify, Vercel, Nginx, atau layanan static hosting lain.

Pastikan hosting:

- Mengarahkan route aplikasi ke `index.html`.
- Menggunakan HTTPS agar instalasi PWA dan service worker aktif.
- Tidak menyimpan cache permanen untuk `flutter_service_worker.js`.
- Menyimpan aset fingerprinted dengan cache jangka panjang.

## Catatan Keamanan

- RLS aktif pada seluruh tabel.
- Admin hanya dapat mengelola `community_id` miliknya.
- Member hanya dapat membaca profil sendiri, tagihan sendiri, rekening aktif,
  pengumuman, dan RPC ringkasan kas komunitas.
- Trigger database mencegah member mengubah nominal, pemilik, atau hasil
  verifikasi tagihan melalui request langsung.
- Bucket Storage bersifat privat dan dibatasi folder komunitas/user.
- Preview bukti menggunakan signed URL berumur lima menit.
- File dibatasi MIME gambar dan ukuran 5 MB di bucket maupun UI.
- RPC login HP memakai `SECURITY DEFINER`, `search_path` eksplisit, return
  minimal, serta privilege yang dibatasi.
- Di production, tambahkan rate limiting pada RPC lookup nomor HP melalui
  API gateway/Edge Function untuk mengurangi risiko enumerasi identifier.

## Roadmap

- Undangan/join code komunitas dan approval anggota baru
- OTP SMS atau WhatsApp dengan provider terverifikasi
- Preview dan pengelolaan signed URL untuk nota pengeluaran
- Notifikasi jatuh tempo dan pengumuman
- Export PDF dan template laporan resmi
- Rekonsiliasi mutasi bank dan payment gateway
- Audit log, soft delete, dan histori perubahan role
- Multi-community untuk satu pengguna
- Monitoring, Sentry, analytics, dan integration test browser
