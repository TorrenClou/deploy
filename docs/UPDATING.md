# TorrentClou — Updating Guide

## Standard Update (No Database Changes)

Most updates are safe and require no special steps:

```bash
# Pull the latest image
docker pull ghcr.io/torrenclou/torrentclou:latest

# Restart the container
docker stop torrencloud && docker rm torrencloud

# Re-run (Linux/macOS)
./run.sh

# Re-run (Windows)
.\run.ps1
```

Your data (database, Redis, downloads) is stored in Docker volumes and persists across container recreations.

## Update With Database Schema Changes

When a release includes database migrations, the API applies them automatically on startup (`APPLY_MIGRATIONS=true`). However, you should back up your data first.

### Before updating

**1. Create a database backup:**
```bash
docker exec torrencloud pg_dump -U torrenclo_user torrenclo > backup_$(date +%Y%m%d_%H%M%S).sql
```

**Windows PowerShell:**
```powershell
docker exec torrencloud pg_dump -U torrenclo_user torrenclo > "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').sql"
```

**2. Pull and restart:**
```bash
docker pull ghcr.io/torrenclou/torrentclou:latest
docker stop torrencloud && docker rm torrencloud
./run.sh
```

**3. Verify:**
```bash
# Check logs for migration success
docker logs torrencloud 2>&1 | grep -i "migrat"

# Check API health
curl http://localhost:47200/api/health/ready
```

### If something goes wrong

**Restore from backup:**
```bash
# Stop the container
docker stop torrencloud && docker rm torrencloud

# Start a fresh container (old volumes still attached)
./run.sh

# Wait for PostgreSQL to start, then restore
sleep 15
docker exec -i torrencloud psql -U torrenclo_user torrenclo < backup_20260223_143000.sql
```

**Roll back to a previous image version:**
```bash
# Find available tags
docker pull ghcr.io/torrenclou/torrentclou:2026.02.20-abc1234-def5678

# Or check GitHub packages for available tags:
# https://github.com/orgs/TorrenClou/packages/container/torrentclou/versions
```

## Pinning a Specific Version

Instead of using `latest`, pin to a specific tag in your run command or script:

```bash
docker run -d --name torrencloud \
  -p 47100:47100 -p 47200:47200 \
  -v torrencloud-pgdata:/data/postgres \
  -v torrencloud-redis:/data/redis \
  -v torrencloud-downloads:/data/downloads \
  --env-file .env \
  ghcr.io/torrenclou/torrentclou:2026.02.23-57e3b9d-132725a
```

## Checking Your Current Version

```bash
docker inspect ghcr.io/torrenclou/torrentclou:latest --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}'
```

## Release Schedule

New images are built automatically whenever code is merged to `main` in either the backend or frontend repository. There is no fixed release schedule — updates ship when they're ready.

Check the [GitHub Actions runs](https://github.com/TorrenClou/deploy/actions) for build history and the [container registry](https://github.com/orgs/TorrenClou/packages/container/torrentclou/versions) for all available versions.
