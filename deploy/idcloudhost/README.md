# Deploy KasWarga ke IDCloudHost VPS

Panduan ini men-deploy KasWarga sebagai Flutter Web/PWA di 1 instance VPS
IDCloudHost dengan domain:

- `https://koneksi.co.id`
- `https://www.koneksi.co.id`

Arsitektur yang disarankan:

- VPS IDCloudHost: Nginx untuk serve static file Flutter Web.
- Supabase Cloud: Auth, PostgreSQL, RLS, RPC, dan Storage.

Jangan menjalankan service role key di frontend. Flutter Web hanya memakai
Supabase URL dan anon key.

## 1. Siapkan VPS IDCloudHost

Rekomendasi awal untuk MVP:

- Ubuntu 22.04 LTS atau 24.04 LTS
- 1 vCPU
- RAM 1-2 GB
- Disk 20 GB
- Port firewall: `22`, `80`, `443`

Login ke VPS:

```bash
ssh root@IP_VPS
```

Clone repo atau salin file `deploy/idcloudhost/server-bootstrap.sh` ke VPS,
lalu jalankan:

```bash
chmod +x server-bootstrap.sh
sudo ./server-bootstrap.sh
```

Script tersebut akan memasang Nginx, Certbot, membuat root web:

```text
/var/www/koneksi.co.id/current
/var/www/koneksi.co.id/releases
```

## 2. Arahkan DNS domain

Di DNS manager domain `koneksi.co.id`, buat record:

| Type | Name | Value |
|---|---|---|
| A | `@` | `IP_VPS_IDCLOUDHOST` |
| A | `www` | `IP_VPS_IDCLOUDHOST` |

Tunggu propagasi DNS. Cek dari lokal:

```bash
nslookup koneksi.co.id
nslookup www.koneksi.co.id
```

## 3. Aktifkan SSL

Setelah DNS mengarah ke VPS:

```bash
sudo certbot --nginx -d koneksi.co.id -d www.koneksi.co.id
sudo certbot renew --dry-run
```

Certbot akan mengubah konfigurasi Nginx untuk HTTPS. Jika ingin memakai template
manual, gunakan `nginx-ssl.conf` dan salin ke:

```bash
sudo cp nginx-ssl.conf /etc/nginx/sites-available/koneksi.co.id
sudo nginx -t
sudo systemctl reload nginx
```

## 4. Build dan deploy dari PC lokal

Pastikan Flutter sudah tersedia di PATH lokal.

Jalankan dari root project KasWarga:

```powershell
.\deploy\idcloudhost\deploy-local.ps1 `
  -ServerHost "IP_VPS_IDCLOUDHOST" `
  -ServerUser "root" `
  -SupabaseUrl "https://YOUR_PROJECT.supabase.co" `
  -SupabaseAnonKey "YOUR_SUPABASE_ANON_KEY"
```

Script ini akan:

1. Menjalankan `flutter build web --release`.
2. Membuat ZIP dari `build/web`.
3. Upload ZIP ke VPS via `scp`.
4. Extract ke `/var/www/koneksi.co.id/releases/TIMESTAMP`.
5. Mengarahkan symlink `/var/www/koneksi.co.id/current` ke release terbaru.
6. Reload Nginx.

Jika deploy sukses, buka:

```text
https://koneksi.co.id
```

## 5. Konfigurasi Supabase production

Di Supabase project:

1. Jalankan migration:

   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   supabase db push
   ```

2. Pastikan Storage bucket dari migration tersedia:

   - `payment_proofs`
   - `expense_receipts`

3. Di Authentication URL Configuration, set:

   ```text
   Site URL: https://koneksi.co.id
   Redirect URLs:
   https://koneksi.co.id
   https://koneksi.co.id/*
   ```

4. Jangan pakai seed akun demo pada database production kecuali untuk staging.

## 6. Health check

Di VPS:

```bash
sudo nginx -t
sudo systemctl status nginx
curl -I https://koneksi.co.id
curl -I https://koneksi.co.id/flutter_service_worker.js
```

Ekspektasi:

- `https://koneksi.co.id` return `200`.
- Route Flutter seperti `/login`, `/admin/dashboard`, dan `/member/dashboard`
  tetap diarahkan ke `index.html`.
- `flutter_service_worker.js` tidak di-cache permanen.

## 7. Update versi berikutnya

Untuk update aplikasi, cukup ulangi:

```powershell
.\deploy\idcloudhost\deploy-local.ps1 `
  -ServerHost "IP_VPS_IDCLOUDHOST" `
  -ServerUser "root" `
  -SupabaseUrl "https://YOUR_PROJECT.supabase.co" `
  -SupabaseAnonKey "YOUR_SUPABASE_ANON_KEY"
```

Release lama tetap tersimpan di `/var/www/koneksi.co.id/releases`.

Rollback manual:

```bash
sudo ln -sfn /var/www/koneksi.co.id/releases/RELEASE_LAMA /var/www/koneksi.co.id/current
sudo nginx -t
sudo systemctl reload nginx
```

## Catatan

- Jika memakai user non-root untuk SSH, pastikan user tersebut punya akses
  `sudo`.
- Jika firewall aktif, buka port:

  ```bash
  sudo ufw allow OpenSSH
  sudo ufw allow "Nginx Full"
  sudo ufw enable
  ```

- Jika aplikasi terbuka tetapi login/register gagal, periksa Supabase URL,
  anon key, RLS policy, dan konfigurasi Auth redirect URL.
