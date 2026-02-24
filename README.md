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
docker run -d --name torrencloud -p 3000:3000 -p 5000:5000 -v torrencloud-pgdata:/data/postgres -v torrencloud-redis:/data/redis -v torrencloud-downloads:/data/downloads --env-file .env ghcr.io/torrenclou/torrentclou:latest
```

### 3. Open

| Service | URL |
|---------|-----|
| Frontend | http://localhost:3000 |
| API | http://localhost:5000/api |
| API Health | http://localhost:5000/api/health/ready |
| Hangfire Dashboard | http://localhost:5000/hangfire |

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

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `POSTGRES_PASSWORD` | Yes | - | PostgreSQL password |
| `JWT_SECRET` | Yes | - | JWT signing key (min 32 chars) |
| `NEXTAUTH_SECRET` | Yes | - | NextAuth.js secret |
| `GOOGLE_CLIENT_ID` | Yes | - | Google OAuth client ID |
| `ADMIN_EMAIL` | No | `admin@example.com` | Admin login email |
| `ADMIN_PASSWORD` | Yes | - | Admin login password |
| `ADMIN_NAME` | No | `Admin` | Admin display name |
| `NEXTAUTH_URL` | No | `http://localhost:3000` | Public URL of the frontend |
| `POSTGRES_DB` | No | `torrenclo` | Database name |
| `POSTGRES_USER` | No | `torrenclo_user` | Database user |
| `JWT_ISSUER` | No | `TorrenClou_API` | JWT issuer |
| `JWT_AUDIENCE` | No | `TorrenClou_Client` | JWT audience |
| `HANGFIRE_WORKER_COUNT` | No | `10` | Background job concurrency |

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
