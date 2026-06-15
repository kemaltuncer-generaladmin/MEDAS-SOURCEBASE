# Build the Flutter web frontend and serve it with nginx.
# Stage 1 — build
FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build
WORKDIR /app

# Cache deps first
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Build
COPY . .
RUN flutter build web --release

# Stage 2 — serve
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
# Serve on 3000 to match Coolify's default proxy target.
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/ >/dev/null || exit 1
