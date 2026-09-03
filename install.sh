#!/usr/bin/env bash
#
# TorrenClou installer.
#
#   curl -fsSL https://raw.githubusercontent.com/TorrenClou/deploy/main/install.sh | bash
#
# Pulls the image, starts it, and prints the URL to open. There is no configuration
# step: the container generates its own secrets on first boot and everything else
# is set up in the browser.
#
set -euo pipefail

IMAGE="ghcr.io/torrenclou/torrentclou:latest"
CONTAINER_NAME="torrencloud"

BOLD='\033[1m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; RED='\033[0;31m'; DIM='\033[2m'; NC='\033[0m'

info()    { echo -e "${CYAN}  ▸ $1${NC}"; }
success() { echo -e "${GREEN}  ✓ $1${NC}"; }
warn()    { echo -e "${YELLOW}  ⚠ $1${NC}"; }
fail()    { echo -e "${RED}  ✗ $1${NC}"; exit 1; }

echo ""
echo -e "${CYAN}${BOLD}"
echo "  ╔════════════════════════════════════════╗"
echo "  ║         TorrenClou Installer          ║"
echo "  ╚════════════════════════════════════════╝"
echo -e "${NC}"

# ─── Prerequisites ────────────────────────────────────────
# Docker is the only one. Nothing is cloned and no secrets are generated here,
# so neither git nor openssl is needed.
command -v docker >/dev/null 2>&1 \
    || fail "Docker is not installed. Install it from https://docs.docker.com/get-docker/"

docker info >/dev/null 2>&1 \
    || fail "Docker daemon is not running. Start Docker and try again."

success "Docker is ready"

# ─── Replace any existing container ──────────────────────
# The named volumes are left alone, so an upgrade keeps its database, downloads
# and generated secrets.
if docker ps -aq -f "name=^${CONTAINER_NAME}$" | grep -q .; then
    info "Replacing the existing container (data volumes are kept)..."
    docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

info "Pulling ${IMAGE}..."
docker pull "$IMAGE"

info "Starting TorrenClou..."
docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    -p 47100:47100 \
    -p 47200:47200 \
    -p 47500:47500 \
    -p 47600:47600 \
    -v torrencloud-pgdata:/data/postgres \
    -v torrencloud-redis:/data/redis \
    -v torrencloud-downloads:/data/downloads \
    "$IMAGE" >/dev/null

success "Container started"

# ─── Wait for it to come up ──────────────────────────────
info "Waiting for services to start (up to 90 seconds)..."
ELAPSED=0
while [ $ELAPSED -lt 90 ]; do
    if curl -sf "http://localhost:47200/api/health/ready" >/dev/null 2>&1; then
        break
    fi
    sleep 3
    ELAPSED=$((ELAPSED + 3))
    printf "\r  ${DIM}  %ds elapsed...${NC}" "$ELAPSED"
done
printf "\r                            \r"

if [ $ELAPSED -ge 90 ]; then
    warn "Health check timed out — services may still be starting"
    echo -e "  ${DIM}Run 'docker logs -f ${CONTAINER_NAME}' to watch progress${NC}"
else
    success "All services are healthy"
fi

# ─── Print where to go ───────────────────────────────────
# sslip.io resolves <dashed-ip>.sslip.io to that IP, which gives a working
# hostname on a fresh server with no DNS set up. Only used for display; the app
# works on whatever address you reach it by.
SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
[ -z "$SERVER_IP" ] && SERVER_IP="$(ip route get 1 2>/dev/null | awk '/src/{print $7}' | head -1 || true)"
[ -z "$SERVER_IP" ] && SERVER_IP="$(curl -sf --max-time 3 https://api.ipify.org 2>/dev/null || true)"

if [ -n "$SERVER_IP" ]; then
    APP_URL="http://$(echo "$SERVER_IP" | tr '.' '-').sslip.io:47100"
else
    APP_URL="http://localhost:47100"
fi

echo ""
echo -e "${GREEN}${BOLD}  ══════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}    ✓ TorrenClou is running${NC}"
echo -e "${GREEN}${BOLD}  ══════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}Open this and create your account:${NC}"
echo -e "  ${CYAN}${APP_URL}${NC}"
echo ""
echo -e "  ${DIM}Also on http://localhost:47100 from this machine.${NC}"
echo -e "  ${DIM}Grafana on :47500, Prometheus on :47600.${NC}"
echo -e "  ${DIM}Grafana's password: docker exec ${CONTAINER_NAME} cat /data/postgres/secrets.env${NC}"
echo ""
echo -e "  ${DIM}Logs:    docker logs -f ${CONTAINER_NAME}${NC}"
echo -e "  ${DIM}Restart: docker restart ${CONTAINER_NAME}${NC}"
echo -e "  ${DIM}Docs:    https://tc.gitnasr.com/docs${NC}"
echo ""
