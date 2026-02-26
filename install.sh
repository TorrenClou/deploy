#!/usr/bin/env bash
set -euo pipefail

# ─── Colors ───────────────────────────────────────────────
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
DIM='\033[2m'
NC='\033[0m'

# ─── Config ───────────────────────────────────────────────
IMAGE="ghcr.io/torrenclou/torrentclou:latest"
CONTAINER_NAME="torrencloud"
INSTALL_DIR="./torrencloud"
REPO_URL="https://github.com/TorrenClou/deploy.git"

ADMIN_EMAIL="admin@torrencloud.local"
ADMIN_PASSWORD="TorrenCloud@2024"
ADMIN_NAME="Admin"

# ─── Banner ───────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}"
echo "  ╔════════════════════════════════════════╗"
echo "  ║         TorrenCloud Installer          ║"
echo "  ╚════════════════════════════════════════╝"
echo -e "${NC}"

# ─── Helpers ──────────────────────────────────────────────
info()    { echo -e "${CYAN}  ▸ $1${NC}"; }
success() { echo -e "${GREEN}  ✓ $1${NC}"; }
warn()    { echo -e "${YELLOW}  ⚠ $1${NC}"; }
fail()    { echo -e "${RED}  ✗ $1${NC}"; exit 1; }

spinner() {
    local pid=$1
    local chars="⣾⣽⣻⢿⡿⣟⣯⣷"
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${CYAN}%s${NC} %s" "${chars:i++%${#chars}:1}" "$2"
        sleep 0.1
    done
    printf "\r"
}

# portable sed -i
sedi() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# ─── Prerequisites ────────────────────────────────────────
info "Checking prerequisites..."

command -v git   >/dev/null 2>&1 || fail "git is not installed. Install it from https://git-scm.com"
command -v curl  >/dev/null 2>&1 || fail "curl is not installed."
command -v docker >/dev/null 2>&1 || fail "Docker is not installed. Install it from https://docs.docker.com/get-docker/"

docker info >/dev/null 2>&1 || fail "Docker daemon is not running. Please start Docker and try again."

success "All prerequisites met"

# ─── Clone / Update Repo ─────────────────────────────────
if [ -d "$INSTALL_DIR/.git" ]; then
    info "Existing installation found, updating..."
    cd "$INSTALL_DIR"
    git pull --quiet
else
    info "Cloning deploy repository..."
    git clone --quiet "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

success "Repository ready"

# ─── Generate .env ────────────────────────────────────────
if [ -f ".env" ]; then
    warn "Existing .env found — keeping current configuration"
else
    if [ ! -f ".env.example" ]; then
        fail ".env.example not found in the repository"
    fi

    info "Generating configuration..."
    cp .env.example .env

    # Generate secrets
    POSTGRES_PASSWORD=$(openssl rand -base64 16 | tr -d '\n')
    JWT_SECRET=$(openssl rand -base64 32 | tr -d '\n')
    NEXTAUTH_SECRET=$(openssl rand -base64 32 | tr -d '\n')

    # Replace placeholders
    sedi "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PASSWORD}|" .env
    sedi "s|JWT_SECRET=.*|JWT_SECRET=${JWT_SECRET}|" .env
    sedi "s|NEXTAUTH_SECRET=.*|NEXTAUTH_SECRET=${NEXTAUTH_SECRET}|" .env
    sedi "s|ADMIN_EMAIL=.*|ADMIN_EMAIL=${ADMIN_EMAIL}|" .env
    sedi "s|ADMIN_PASSWORD=.*|ADMIN_PASSWORD=${ADMIN_PASSWORD}|" .env
    sedi "s|ADMIN_NAME=.*|ADMIN_NAME=${ADMIN_NAME}|" .env

    # Enable observability by default
    sedi "s|# OBSERVABILITY_ENABLE_PROMETHEUS=.*|OBSERVABILITY_ENABLE_PROMETHEUS=true|" .env
    sedi "s|# OBSERVABILITY_ENABLE_TRACING=.*|OBSERVABILITY_ENABLE_TRACING=true|" .env

    success "Configuration generated with secure random secrets"
fi

# ─── Stop Existing Container ─────────────────────────────
if docker ps -aq -f "name=${CONTAINER_NAME}" | grep -q .; then
    info "Stopping existing container..."
    docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
    success "Old container removed"
fi

# ─── Pull Image ──────────────────────────────────────────
info "Pulling latest Docker image..."
docker pull "$IMAGE"
success "Image pulled"

# ─── Run Container ────────────────────────────────────────
info "Starting TorrenCloud..."
docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    -p 3000:3000 \
    -p 5000:5000 \
    -p 3200:3200 \
    -p 9090:9090 \
    -v torrencloud-pgdata:/data/postgres \
    -v torrencloud-redis:/data/redis \
    -v torrencloud-downloads:/data/downloads \
    --env-file .env \
    "$IMAGE" >/dev/null

success "Container started"

# ─── Wait for Healthy ────────────────────────────────────
info "Waiting for services to start (this may take up to 60 seconds)..."
HEALTH_URL="http://localhost:5000/api/health/ready"
MAX_WAIT=90
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    if curl -sf "$HEALTH_URL" >/dev/null 2>&1; then
        break
    fi
    sleep 3
    ELAPSED=$((ELAPSED + 3))
    printf "\r  ${DIM}  %ds elapsed...${NC}" "$ELAPSED"
done
printf "\r                            \r"

if [ $ELAPSED -ge $MAX_WAIT ]; then
    warn "Health check timed out — services may still be starting"
    echo -e "  ${DIM}Run 'docker logs -f torrencloud' to check progress${NC}"
else
    success "All services are healthy"
fi

# ─── Print Credentials ───────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}  ══════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}    ✓ TorrenCloud is ready!${NC}"
echo -e "${GREEN}${BOLD}  ══════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}── Services ──${NC}"
echo -e "  Frontend        ${CYAN}http://localhost:3000${NC}"
echo -e "  API             ${CYAN}http://localhost:5000/api${NC}"
echo -e "  Hangfire        ${CYAN}http://localhost:5000/hangfire${NC}"
echo ""
echo -e "  ${BOLD}── Login ──${NC}"
echo -e "  Email           ${YELLOW}${ADMIN_EMAIL}${NC}"
echo -e "  Password        ${YELLOW}${ADMIN_PASSWORD}${NC}"
echo ""
echo -e "  ${BOLD}── Monitoring ──${NC}"
echo -e "  Grafana         ${CYAN}http://localhost:3200${NC}     ${DIM}(admin / admin)${NC}"
echo -e "  Prometheus      ${CYAN}http://localhost:9090${NC}"
echo ""
echo -e "${GREEN}${BOLD}  ══════════════════════════════════════════════${NC}"
echo -e "  ${DIM}Config: $(pwd)/.env${NC}"
echo -e "  ${DIM}Change credentials and restart:${NC}"
echo -e "  ${DIM}  docker restart torrencloud${NC}"
echo -e "${GREEN}${BOLD}  ══════════════════════════════════════════════${NC}"
echo ""
