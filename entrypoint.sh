#!/bin/bash
set -e

# ============================================================
# TorrenCloud All-in-One Entrypoint
# Initializes PostgreSQL, sets runtime env vars, starts supervisord
# ============================================================

POSTGRES_DB="${POSTGRES_DB:-torrenclo}"
POSTGRES_USER="${POSTGRES_USER:-torrenclo_user}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-changeme}"
PGDATA="/data/postgres"

# -----------------------------------------------------------
# 1. Initialize PostgreSQL if data directory is empty
# -----------------------------------------------------------
if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "[entrypoint] Initializing PostgreSQL data directory..."
    chown -R postgres:postgres "$PGDATA"
    su - postgres -c "/usr/lib/postgresql/15/bin/initdb -D $PGDATA --encoding=UTF8 --locale=C"

    # Configure PostgreSQL
    cat >> "$PGDATA/postgresql.conf" <<EOF
listen_addresses = '127.0.0.1'
max_connections = 200
shared_buffers = 128MB
EOF

    # Configure authentication
    cat > "$PGDATA/pg_hba.conf" <<EOF
local   all   all                 trust
host    all   all   127.0.0.1/32  md5
host    all   all   ::1/128       md5
EOF

    # Start PostgreSQL temporarily to create user and database
    su - postgres -c "/usr/lib/postgresql/15/bin/pg_ctl -D $PGDATA -w start"
    su - postgres -c "psql -c \"CREATE USER $POSTGRES_USER WITH PASSWORD '$POSTGRES_PASSWORD';\""
    su - postgres -c "psql -c \"CREATE DATABASE $POSTGRES_DB OWNER $POSTGRES_USER;\""
    su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO $POSTGRES_USER;\""
    su - postgres -c "/usr/lib/postgresql/15/bin/pg_ctl -D $PGDATA -w stop"

    echo "[entrypoint] PostgreSQL initialized successfully."
else
    echo "[entrypoint] PostgreSQL data directory exists, skipping init."
    chown -R postgres:postgres "$PGDATA"
fi

# -----------------------------------------------------------
# 2. Ensure directory permissions
# -----------------------------------------------------------
chown -R redis:redis /data/redis
mkdir -p /data/downloads
chmod 777 /data/downloads

# -----------------------------------------------------------
# 3. Export environment variables for .NET services
# -----------------------------------------------------------
export ConnectionStrings__DefaultConnection="Host=127.0.0.1;Port=5432;Database=${POSTGRES_DB};Username=${POSTGRES_USER};Password=${POSTGRES_PASSWORD}"
export Redis__ConnectionString="127.0.0.1:6379"
export APPLY_MIGRATIONS="${APPLY_MIGRATIONS:-true}"
export ASPNETCORE_ENVIRONMENT="${ASPNETCORE_ENVIRONMENT:-Production}"
export TORRENT_DOWNLOAD_PATH="/data/downloads"
export Hangfire__WorkerCount="${HANGFIRE_WORKER_COUNT:-10}"

# JWT
export Jwt__Key="${JWT_SECRET}"
export Jwt__Issuer="${JWT_ISSUER:-TorrenClou_API}"
export Jwt__Audience="${JWT_AUDIENCE:-TorrenClou_Client}"

# Google OAuth
export Google__ClientId="${GOOGLE_CLIENT_ID}"

# Admin credentials
export ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
export ADMIN_PASSWORD="${ADMIN_PASSWORD:-changeme}"
export ADMIN_NAME="${ADMIN_NAME:-Admin}"

# Frontend URL (for CORS)
export FRONTEND_URL="http://127.0.0.1:3000"

# Next.js server-side runtime vars
export BACKEND_URL="http://127.0.0.1:8080"
export NEXTAUTH_SECRET="${NEXTAUTH_SECRET:-change-me-in-production}"
export NEXTAUTH_URL="${NEXTAUTH_URL:-http://localhost}"

# Observability (optional)
export Observability__LokiUrl="${OBSERVABILITY_LOKI_URL:-}"
export Observability__LokiUsername="${OBSERVABILITY_LOKI_USERNAME:-}"
export Observability__LokiApiKey="${OBSERVABILITY_LOKI_API_KEY:-}"
export Observability__OtlpEndpoint="${OBSERVABILITY_OTLP_ENDPOINT:-}"
export Observability__OtlpHeaders="${OBSERVABILITY_OTLP_HEADERS:-}"
export Observability__EnablePrometheus="${OBSERVABILITY_ENABLE_PROMETHEUS:-true}"
export Observability__EnableTracing="${OBSERVABILITY_ENABLE_TRACING:-true}"

# .NET Runtime settings
export DOTNET_gcServer=1
export DOTNET_EnableDiagnostics=0
export TMPDIR=/app/tmp
export TEMP=/app/tmp
export TMP=/app/tmp
export DOTNET_BUNDLE_EXTRACT_BASE_DIR=/app/tmp/bundle

# -----------------------------------------------------------
# 4. Start all services via supervisord
# -----------------------------------------------------------
echo "[entrypoint] Starting all services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/torrencloud.conf
