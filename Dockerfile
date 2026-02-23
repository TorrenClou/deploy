# ============================================================
# TorrenCloud All-in-One Image
# Frontend + API + Workers + PostgreSQL 15 + Redis 7
# ============================================================

# ---- Stage 1: Frontend Build ----
FROM node:20-alpine AS frontend-build
WORKDIR /app

COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci --prefer-offline

COPY frontend/ ./

# NEXT_PUBLIC_ vars are baked at build time
ARG NEXT_PUBLIC_API_URL=/api
ARG NEXT_PUBLIC_BACKEND_URL=
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_BACKEND_URL=$NEXT_PUBLIC_BACKEND_URL

RUN npm run build

# ---- Stage 2: Backend Build ----
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS backend-build
WORKDIR /src

# Copy solution and project files for dependency restoration
COPY backend/TorreClou.sln .
COPY backend/TorreClou.Core/TorreClou.Core.csproj TorreClou.Core/
COPY backend/TorreClou.Application/TorreClou.Application.csproj TorreClou.Application/
COPY backend/TorreClou.Infrastructure/TorreClou.Infrastructure.csproj TorreClou.Infrastructure/
COPY backend/TorreClou.API/TorreClou.API.csproj TorreClou.API/
COPY backend/TorreClou.Worker/TorreClou.Worker.csproj TorreClou.Worker/
COPY backend/TorreClou.GoogleDrive.Worker/TorreClou.GoogleDrive.Worker.csproj TorreClou.GoogleDrive.Worker/
COPY backend/TorreClou.S3.Worker/TorreClou.S3.Worker.csproj TorreClou.S3.Worker/

RUN dotnet restore TorreClou.sln

# Copy all source code
COPY backend/TorreClou.Core/ TorreClou.Core/
COPY backend/TorreClou.Application/ TorreClou.Application/
COPY backend/TorreClou.Infrastructure/ TorreClou.Infrastructure/
COPY backend/TorreClou.API/ TorreClou.API/
COPY backend/TorreClou.Worker/ TorreClou.Worker/
COPY backend/TorreClou.GoogleDrive.Worker/ TorreClou.GoogleDrive.Worker/
COPY backend/TorreClou.S3.Worker/ TorreClou.S3.Worker/

# Publish each project to its own directory
RUN dotnet publish TorreClou.API/TorreClou.API.csproj \
      -c Release --no-restore -o /publish/api /p:UseAppHost=false
RUN dotnet publish TorreClou.Worker/TorreClou.Worker.csproj \
      -c Release --no-restore -o /publish/torrent-worker /p:UseAppHost=false
RUN dotnet publish TorreClou.GoogleDrive.Worker/TorreClou.GoogleDrive.Worker.csproj \
      -c Release --no-restore -o /publish/gdrive-worker /p:UseAppHost=false
RUN dotnet publish TorreClou.S3.Worker/TorreClou.S3.Worker.csproj \
      -c Release --no-restore -o /publish/s3-worker /p:UseAppHost=false

# ---- Stage 3: Runtime ----
FROM ubuntu:22.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive

# Install PostgreSQL 15, Redis, nginx, supervisord
RUN apt-get update && apt-get install -y --no-install-recommends \
      gnupg2 lsb-release curl ca-certificates \
    && echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
       > /etc/apt/sources.list.d/pgdg.list \
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
       | gpg --dearmor -o /etc/apt/trusted.gpg.d/pgdg.gpg \
    && apt-get update && apt-get install -y --no-install-recommends \
      postgresql-15 \
      redis-server \
      nginx \
      supervisor \
    && rm -rf /var/lib/apt/lists/*

# Install .NET ASP.NET Runtime 9.0
RUN curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh \
    && chmod +x /tmp/dotnet-install.sh \
    && /tmp/dotnet-install.sh --channel 9.0 --runtime aspnetcore --install-dir /usr/share/dotnet \
    && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet \
    && rm /tmp/dotnet-install.sh

# Install Node.js 20 runtime (for Next.js standalone server)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Create data directories (volume mount points)
RUN mkdir -p /data/postgres /data/redis /data/downloads \
             /app/tmp /app/tmp/bundle /app/logs \
             /var/log/supervisor \
    && chown -R postgres:postgres /data/postgres \
    && chown -R redis:redis /data/redis

# Copy built frontend (Next.js standalone)
COPY --from=frontend-build /app/.next/standalone /app/frontend/
COPY --from=frontend-build /app/.next/static /app/frontend/.next/static
COPY --from=frontend-build /app/public /app/frontend/public

# Copy published backend services
COPY --from=backend-build /publish/api /app/api/
COPY --from=backend-build /publish/torrent-worker /app/torrent-worker/
COPY --from=backend-build /publish/gdrive-worker /app/gdrive-worker/
COPY --from=backend-build /publish/s3-worker /app/s3-worker/

# Copy configuration files
COPY config/supervisord.conf /etc/supervisor/conf.d/torrencloud.conf
COPY config/nginx.conf /etc/nginx/sites-available/default
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Persistent data volumes
VOLUME ["/data/postgres", "/data/redis", "/data/downloads"]

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
