# Deploy Docker KasWarga

Opsi ini ditujukan untuk DevOps yang ingin deploy KasWarga sebagai container di
1 instance IDCloudHost. Container hanya menjalankan Flutter Web/PWA via Nginx.
Backend tetap memakai Supabase Cloud.

## Arsitektur

```text
Internet
  -> Nginx host + Certbot SSL di VPS
  -> Docker container kaswarga-web pada 127.0.0.1:8080
  -> Supabase Cloud untuk Auth, Database, RPC, RLS, dan Storage
```

Kenapa tetap ada Nginx host? Supaya TLS, renewal Let's Encrypt, dan reverse
proxy dikelola stabil di VPS. Container tetap sederhana dan mudah diganti.

## File

- `Dockerfile`: multi-stage build Flutter Web lalu serve dengan Nginx Alpine.
- `.dockerignore`: mengecilkan build context dan mencegah `.env` ikut masuk image.
- `deploy/docker/compose.yaml`: contoh compose production.
- `deploy/docker/nginx-container.conf`: konfigurasi Nginx di dalam container.
- `deploy/docker/nginx-host-proxy.conf`: reverse proxy host untuk domain.
- `deploy/docker/.env.production.example`: template environment build.

## Catatan penting Flutter Web

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, dan `APP_ENV` dipakai sebagai
compile-time variable melalui `--dart-define`. Artinya:

- Nilai tersebut masuk saat `docker build`.
- Mengubah nilai Supabase perlu rebuild image.
- Jangan pernah memakai service role key. Pakai anon key saja.

## Build image lokal

Dari root repository:

```bash
docker build \
  --build-arg SUPABASE_URL="https://YOUR_PROJECT.supabase.co" \
  --build-arg SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY" \
  --build-arg APP_ENV="production" \
  -t kaswarga-web:latest .
```

Test lokal:

```bash
docker run --rm -p 8080:80 kaswarga-web:latest
```

Buka:

```text
http://127.0.0.1:8080
```

## Deploy dengan Docker Compose di VPS

1. Install Docker dan Compose plugin di VPS Ubuntu:

   ```bash
   sudo apt-get update
   sudo apt-get install -y ca-certificates curl gnupg
   sudo install -m 0755 -d /etc/apt/keyrings
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
     | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
   echo \
     "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
     $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
     | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   sudo apt-get update
   sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
   sudo systemctl enable --now docker
   ```

2. Clone repository di VPS:

   ```bash
   git clone https://github.com/okykur/KasWarga.git /opt/kaswarga
   cd /opt/kaswarga
   ```

3. Buat env production:

   ```bash
   cp deploy/docker/.env.production.example deploy/docker/.env.production
   nano deploy/docker/.env.production
   ```

4. Build dan jalankan container:

   ```bash
   docker compose --env-file deploy/docker/.env.production \
     -f deploy/docker/compose.yaml up -d --build
   ```

5. Cek container:

   ```bash
   docker compose --env-file deploy/docker/.env.production \
     -f deploy/docker/compose.yaml ps
   curl -I http://127.0.0.1:8080
   ```

## Reverse proxy domain kaswarga.koneksi.co.id

Salin reverse proxy:

```bash
sudo cp deploy/docker/nginx-host-proxy.conf /etc/nginx/sites-available/kaswarga.koneksi.co.id
sudo ln -sfn /etc/nginx/sites-available/kaswarga.koneksi.co.id /etc/nginx/sites-enabled/kaswarga.koneksi.co.id
sudo nginx -t
sudo systemctl reload nginx
```

Pastikan DNS:

| Type | Name | Value |
|---|---|---|
| A | `kaswarga` | `IP_VPS_IDCLOUDHOST` |

Aktifkan SSL:

```bash
sudo certbot --nginx -d kaswarga.koneksi.co.id
sudo certbot renew --dry-run
```

## Workflow DevOps dengan registry

Di CI/CD atau mesin build:

```bash
export IMAGE="registry.example.com/kaswarga/kaswarga-web:$(git rev-parse --short HEAD)"

docker build \
  --build-arg SUPABASE_URL="$SUPABASE_URL" \
  --build-arg SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --build-arg APP_ENV="production" \
  -t "$IMAGE" .

docker push "$IMAGE"
```

Di VPS:

```bash
export KASWARGA_IMAGE="registry.example.com/kaswarga/kaswarga-web:COMMIT_SHA"
docker compose --env-file deploy/docker/.env.production \
  -f deploy/docker/compose.yaml pull
docker compose --env-file deploy/docker/.env.production \
  -f deploy/docker/compose.yaml up -d
```

Jika memakai image dari registry, DevOps dapat menghapus blok `build:` dari
`compose.yaml` atau membuat override compose khusus production.

## Rollback

Jika image sebelumnya masih ada:

```bash
export KASWARGA_IMAGE="registry.example.com/kaswarga/kaswarga-web:PREVIOUS_SHA"
docker compose --env-file deploy/docker/.env.production \
  -f deploy/docker/compose.yaml up -d
```

## Health check

```bash
curl -I https://kaswarga.koneksi.co.id
curl -I https://kaswarga.koneksi.co.id/flutter_service_worker.js
docker inspect --format='{{json .State.Health}}' kaswarga-web
```

## Supabase production checklist

- Jalankan migration terbaru ke Supabase production.
- Set Auth Site URL ke `https://kaswarga.koneksi.co.id`.
- Tambahkan Redirect URLs:

  ```text
  https://kaswarga.koneksi.co.id
  https://kaswarga.koneksi.co.id/*
  ```

- Pastikan bucket `payment_proofs` dan `expense_receipts` tersedia.
- Pastikan RLS aktif.
