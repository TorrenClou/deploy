# TorrentClou

**Self-hosted torrent management platform — download, organize, and sync torrents to Google Drive or S3.**

One Docker image. One command. Everything included.

## Quick Start

**Prerequisites:** [Docker](https://docs.docker.com/get-docker/) installed on your machine.

### 1. Clone and configure

```bash
git clone https://github.com/TorrenClou/deploy.git
cd deploy
cp .env.example .env
```

Edit `.env` and replace all `<CHANGE_ME>` values with your own secrets.

### 2. Run

**Linux / macOS:**
```bash
./run.sh
```

**Windows (PowerShell):**
```powershell
.\run.ps1
```

**Or run directly:**
```bash
docker run -d --name torrencloud -p 47100:47100 -p 47200:47200 -v torrencloud-pgdata:/data/postgres -v torrencloud-redis:/data/redis -v torrencloud-downloads:/data/downloads --env-file .env ghcr.io/torrenclou/torrentclou:latest
```

### 3. Open

| Service | URL |
|---------|-----|
| Frontend | http://localhost:47100 |
| API | http://localhost:47200/api |
| API Health | http://localhost:47200/api/health/ready |
| Hangfire Dashboard | http://localhost:47200/hangfire |

---

## What's Inside

The all-in-one image bundles everything needed to run TorrentClou:

| Component | Technology |
|-----------|------------|
| Frontend | Next.js 15 (React 18, TypeScript, Tailwind CSS) |
| Backend API | .NET 9.0 (Clean Architecture) |
| Torrent Worker | Background job processor for torrent downloads |
| Google Drive Worker | Syncs completed downloads to Google Drive |
| S3 Worker | Uploads completed downloads to S3-compatible storage |
| Database | PostgreSQL 15 |
| Cache & Jobs | Redis 7 |
| Process Manager | supervisord |

## Data Persistence

Data is stored in Docker volumes that survive container restarts:

| Volume | Container Path | Purpose |
|--------|---------------|---------|
| `torrencloud-pgdata` | `/data/postgres` | PostgreSQL database |
| `torrencloud-redis` | `/data/redis` | Redis data |
| `torrencloud-downloads` | `/data/downloads` | Downloaded torrent files |

## Environment Variables

### Required Variables
| Variable | Description |
|----------|-------------|
| `POSTGRES_PASSWORD` | PostgreSQL password |
| `JWT_SECRET` | JWT signing key (min 32 chars) |
| `NEXTAUTH_SECRET` | NextAuth.js secret for session encryption |
| `ADMIN_PASSWORD` | Admin account password |

### Important Notes

**Frontend API Discovery:**

**Client-side requests** (browser → backend):
- If `NEXT_PUBLIC_API_URL` is set: Uses that URL explicitly
- If `NEXT_PUBLIC_API_PORT` is set: Constructs URL as `http://hostname:$NEXT_PUBLIC_API_PORT/api`
  - Works great for Docker Compose: frontend :3000 + backend :5000 → queries :5000/api ✅
- Fallback: `http://localhost:47200/api` (for local development)

**Server-side requests** (NextAuth login):
- Configured via `BACKEND_URL` env var (required for server-side auth)
  - **All-in-one container:** `http://127.0.0.1:47200` (default, internal localhost)
  - **Docker Compose:** `http://backend:8080` (uses internal Docker network)

### Optional Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `NEXTAUTH_URL` | `http://localhost:47100` | Public URL of the frontend (for OAuth redirects) |
| `POSTGRES_DB` | `torrenclo` | Database name |
| `POSTGRES_USER` | `torrenclo_user` | Database user |
| `GOOGLE_CLIENT_ID` | - | Google OAuth client ID |
| `ADMIN_EMAIL` | `admin@example.com` | Admin login email |
| `ADMIN_NAME` | `Admin` | Admin display name |
| `JWT_ISSUER` | `TorrenClou_API` | JWT issuer claim |
| `JWT_AUDIENCE` | `TorrenClou_Client` | JWT audience claim |
| `HANGFIRE_WORKER_COUNT` | `10` | Background job concurrency |
| `BACKEND_URL` | `http://127.0.0.1:47200` | Override backend URL for server-side requests |

See [`.env.example`](.env.example) for the full list including optional observability settings.

## Stopping and Restarting

```bash
# Stop
docker stop torrencloud

# Start again (data persists)
docker start torrencloud

# Remove container (data still persists in volumes)
docker rm torrencloud

# Remove everything including data
docker rm torrencloud
docker volume rm torrencloud-pgdata torrencloud-redis torrencloud-downloads
```

## Production Deployment (Separate Services)

For production deployments, use **docker-compose.prod.yml** to run frontend, backend, and workers as separate scalable services:

```bash
docker-compose -f docker-compose.prod.yml up -d
```

**Key differences:**
- Frontend auto-detects backend API using `window.location`
- Backend URL for server-side auth configured via `BACKEND_URL=http://backend:8080` (internal Docker network)
- Separate containers allow independent scaling
- No supervisord — each service managed independently

See [docker-compose.prod.yml](docker-compose.prod.yml) for the full configuration.

## Updating

```bash
docker pull ghcr.io/torrenclou/torrentclou:latest
docker stop torrencloud && docker rm torrencloud
# Re-run with the same command or script — volumes persist
./run.sh
```

See [docs/UPDATING.md](docs/UPDATING.md) for the full update guide including database migration considerations.

## Documentation

- [Usage Guide](docs/USAGE.md) — Detailed setup and configuration
- [Technical Architecture](docs/TECHNICAL.md) — System design, CI/CD pipeline, internals
- [Updating Guide](docs/UPDATING.md) — How to update to new versions safely

## CI/CD

Images are built automatically when code is merged to `main` in either the [backend](https://github.com/TorrenClou/backend) or [frontend](https://github.com/TorrenClou/frontend) repository. The build pipeline uses GitHub Actions with cross-repository dispatch.

Image tags follow the format: `YYYY.MM.DD-<backend-sha>-<frontend-sha>`

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to this project.

## License

This project is proprietary software. All rights reserved.
