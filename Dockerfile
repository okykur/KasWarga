# syntax=docker/dockerfile:1

ARG FLUTTER_IMAGE=ghcr.io/cirruslabs/flutter:stable

FROM ${FLUTTER_IMAGE} AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

ARG SUPABASE_URL=""
ARG SUPABASE_ANON_KEY=""
ARG APP_ENV=production

RUN flutter config --enable-web \
    && flutter build web --release --no-wasm-dry-run \
      --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
      --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}" \
      --dart-define=APP_ENV="${APP_ENV}"

FROM nginx:1.27-alpine AS runtime

COPY deploy/docker/nginx-container.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1
