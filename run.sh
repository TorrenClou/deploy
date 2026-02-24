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
        echo -e "${RED}Please edit .env and replace all <CHANGE_ME> values, then re-run this script.${NC}"
        exit 1
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
    -p 3000:3000 \
    -p 5000:5000 \
    -v torrencloud-pgdata:/data/postgres \
    -v torrencloud-redis:/data/redis \
    -v torrencloud-downloads:/data/downloads \
    --env-file "$ENV_FILE" \
    --restart unless-stopped \
    "$IMAGE"

echo ""
echo -e "${GREEN}TorrentClou is starting up!${NC}"
echo ""
echo "  Frontend:           http://localhost:3000"
echo "  API:                http://localhost:5000/api"
echo "  Hangfire Dashboard: http://localhost:5000/hangfire"
echo ""
echo "  View logs:  docker logs -f torrencloud"
echo "  Stop:       docker stop torrencloud"
echo ""
