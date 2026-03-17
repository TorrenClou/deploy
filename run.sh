#!/bin/bash
set -e

IMAGE="ghcr.io/torrenclou/torrentclou:latest"
CONTAINER_NAME="torrencloud"
ENV_FILE=".env"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "  TorrentClou — All-in-One Launcher"
echo "=========================================="

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

# Check .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}No .env file found. Creating from .env.example...${NC}"
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${YELLOW}Generating random secrets for .env...${NC}"
        
        DB_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)
        JWT_SEC=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 48)
        ADMIN_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
        NEXT_SEC=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 48)

        sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${DB_PASS}|" .env
        sed -i "s|^JWT_SECRET=.*|JWT_SECRET=${JWT_SEC}|" .env
        sed -i "s|^ADMIN_PASSWORD=.*|ADMIN_PASSWORD=${ADMIN_PASS}|" .env
        sed -i "s|^NEXTAUTH_SECRET=.*|NEXTAUTH_SECRET=${NEXT_SEC}|" .env

        echo -e "${GREEN}.env generated successfully with secure defaults!${NC}"
    else
        echo -e "${RED}Error: .env.example not found. Please create a .env file.${NC}"
        exit 1
    fi
fi

# Validate required env vars
MISSING=0
while IFS='=' read -r key value; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    if [[ "$value" == *"CHANGE_ME"* || "$value" == *"your_"* ]]; then
        echo -e "${RED}  Missing: $key still has a placeholder value${NC}"
        MISSING=1
    fi
done < "$ENV_FILE"

if [ "$MISSING" -eq 1 ]; then
    echo -e "${RED}Please update the values above in .env before running.${NC}"
    exit 1
fi

# Detect server IP and build sslip.io URLs
SERVER_IP=""
SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
[ -z "$SERVER_IP" ] && SERVER_IP=$(ip route get 1 2>/dev/null | awk '/src/{print $7}' | head -1 || true)
[ -z "$SERVER_IP" ] && SERVER_IP=$(curl -sf --max-time 3 https://api.ipify.org 2>/dev/null || true)

if [ -n "$SERVER_IP" ]; then
    SSLIP_HOST=$(echo "$SERVER_IP" | tr '.' '-')
    FRONTEND_PUBLIC="http://${SSLIP_HOST}.sslip.io:47100"
    BACKEND_PUBLIC="http://${SSLIP_HOST}.sslip.io:47200"
    GRAFANA_PUBLIC="http://${SSLIP_HOST}.sslip.io:47500"
    PROMETHEUS_PUBLIC="http://${SSLIP_HOST}.sslip.io:47600"
    GDRIVE_REDIRECT="${FRONTEND_PUBLIC}/proxy/api/storage/gdrive/callback"

    # Update .env with real public URLs for NextAuth and CORS
    sed -i "s|NEXTAUTH_URL=.*|NEXTAUTH_URL=${FRONTEND_PUBLIC}|" "$ENV_FILE" 2>/dev/null || true
    grep -q "^PUBLIC_FRONTEND_URL=" "$ENV_FILE" 2>/dev/null \
        && sed -i "s|PUBLIC_FRONTEND_URL=.*|PUBLIC_FRONTEND_URL=${FRONTEND_PUBLIC}|" "$ENV_FILE" \
        || echo "PUBLIC_FRONTEND_URL=${FRONTEND_PUBLIC}" >> "$ENV_FILE"
else
    FRONTEND_PUBLIC="http://localhost:47100"
    BACKEND_PUBLIC="http://localhost:47200"
    GRAFANA_PUBLIC="http://localhost:47500"
    PROMETHEUS_PUBLIC="http://localhost:47600"
    GDRIVE_REDIRECT="${FRONTEND_PUBLIC}/proxy/api/storage/gdrive/callback"
    echo -e "${YELLOW}Warning: Could not detect server IP — using localhost URLs${NC}"
fi

# Stop existing container if running
if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
    echo -e "${YELLOW}Stopping existing container...${NC}"
    docker stop "$CONTAINER_NAME" > /dev/null 2>&1
    docker rm "$CONTAINER_NAME" > /dev/null 2>&1
elif docker ps -aq -f name="$CONTAINER_NAME" | grep -q .; then
    docker rm "$CONTAINER_NAME" > /dev/null 2>&1
fi

# Pull latest image
echo "Pulling latest image..."
docker pull "$IMAGE"

# Run
echo "Starting TorrentClou..."
docker run -d \
    --name "$CONTAINER_NAME" \
    -p 47100:47100 \
    -p 47200:47200 \
    -p 47500:47500 \
    -p 47600:47600 \
    -p 5432:5432 \
    -p 6379:6379 \
    -v torrencloud-pgdata:/data/postgres \
    -v torrencloud-redis:/data/redis \
    -v torrencloud-downloads:/data/downloads \
    --env-file "$ENV_FILE" \
    --restart unless-stopped \
    "$IMAGE"

echo ""
echo -e "${GREEN}TorrentClou is starting up!${NC}"
echo ""
echo -e "  ${GREEN}── Network URLs (sslip.io) ──${NC}"
echo "  Frontend:           ${FRONTEND_PUBLIC}"
echo "  API:                ${BACKEND_PUBLIC}/api"
echo "  Hangfire Dashboard: ${BACKEND_PUBLIC}/hangfire"
echo "  Grafana:            ${GRAFANA_PUBLIC}"
echo "  Prometheus:         ${PROMETHEUS_PUBLIC}"
echo ""
echo -e "  ${GREEN}── Localhost URLs ──${NC}"
echo "  Frontend:           http://localhost:47100"
echo "  API:                http://localhost:47200/api"
echo ""
echo -e "  ${YELLOW}── Google Drive OAuth ──${NC}"
echo "  Register this Redirect URI in Google Cloud Console:"
echo "  ${GDRIVE_REDIRECT}"
echo ""
echo "  View logs:  docker logs -f torrencloud"
echo "  Stop:       docker stop torrencloud"
echo ""
