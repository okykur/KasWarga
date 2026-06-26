#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${DOMAIN:-koneksi.co.id}"
WWW_DOMAIN="${WWW_DOMAIN:-www.koneksi.co.id}"
WEB_ROOT="/var/www/${DOMAIN}"
APP_ROOT="${WEB_ROOT}/current"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Jalankan script ini dengan sudo."
  exit 1
fi

apt-get update
apt-get install -y nginx certbot python3-certbot-nginx unzip curl git

mkdir -p "${WEB_ROOT}/releases" "${APP_ROOT}"
chown -R www-data:www-data "${WEB_ROOT}"

cat > "/etc/nginx/sites-available/${DOMAIN}" <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} ${WWW_DOMAIN};

    root ${APP_ROOT};
    index index.html;

    access_log /var/log/nginx/${DOMAIN}.access.log;
    error_log /var/log/nginx/${DOMAIN}.error.log;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location = /flutter_service_worker.js {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        try_files \$uri =404;
    }

    location = /manifest.json {
        add_header Cache-Control "no-cache";
        try_files \$uri =404;
    }

    location ~* \.(?:js|css|png|jpg|jpeg|gif|svg|ico|woff|woff2|ttf|otf|wasm)$ {
        expires 30d;
        add_header Cache-Control "public, max-age=2592000, immutable";
        try_files \$uri =404;
    }
}
NGINX

ln -sfn "/etc/nginx/sites-available/${DOMAIN}" "/etc/nginx/sites-enabled/${DOMAIN}"
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable nginx
systemctl reload nginx

echo "Bootstrap selesai."
echo "Pastikan DNS A record ${DOMAIN} dan ${WWW_DOMAIN} sudah mengarah ke IP VPS."
echo "Setelah DNS aktif, jalankan:"
echo "sudo certbot --nginx -d ${DOMAIN} -d ${WWW_DOMAIN}"
