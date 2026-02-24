# TorrentClou — Technical Architecture

## System Overview

TorrentClou is a self-hosted torrent management platform with cloud storage integration. It's packaged as a single Docker image containing all components needed to run the full stack.

```
┌─────────────────────────────────────────────────────────┐
│                   Docker Container                       │
│                                                          │
│  ┌──────────────┐    ┌──────────────────────────────┐   │
│  │   Next.js    │    │         .NET 9.0 API          │   │
│  │  Frontend    │───>│     (Clean Architecture)      │   │
│  │  :3000       │    │          :5000                │   │
│  └──────────────┘    └──────────┬───────────────────┘   │
│                                  │                       │
│                    ┌─────────────┼─────────────┐        │
│                    │             │             │         │
│              ┌─────┴──┐   ┌─────┴──┐   ┌─────┴──┐     │
│              │Torrent │   │ GDrive │   │   S3   │     │
│              │Worker  │   │ Worker │   │ Worker │     │
│              └────────┘   └────────┘   └────────┘     │
│                    │             │             │         │
│              ┌─────┴─────────────┴─────────────┘        │
│              │                                          │
│         ┌────┴─────┐         ┌──────────┐               │
│         │PostgreSQL│         │  Redis   │               │
│         │  15      │         │  7       │               │
│         │ :5432    │         │ :6379    │               │
│         └──────────┘         └──────────┘               │
│                                                          │
│  Process Manager: supervisord                            │
└─────────────────────────────────────────────────────────┘
     │              │               │
     ▼              ▼               ▼
 /data/postgres  /data/redis   /data/downloads
 (Volume)        (Volume)      (Volume)
```

## Technology Stack

### Frontend
| Technology | Version | Purpose |
|-----------|---------|---------|
| Next.js | 15 | React framework with SSR and App Router |
| React | 18 | UI library |
| TypeScript | 5.6 | Type safety |
| Tailwind CSS | 3.4 | Utility-first styling |
| NextAuth.js | 5 (beta) | Authentication (credentials + OAuth) |
| React Query | 5 | Server state management |
| Zustand | 5 | Client state management |
| Zod | 4 | Runtime schema validation |
| Radix UI | - | Accessible UI primitives |

### Backend
| Technology | Version | Purpose |
|-----------|---------|---------|
| .NET | 9.0 | Runtime and framework |
| ASP.NET Core | 9.0 | Web API framework |
| Entity Framework Core | - | ORM and migrations |
| Hangfire | - | Background job processing |
| PostgreSQL | 15 | Primary database |
| Redis | 7 | Caching, job state, distributed locks |

### Infrastructure
| Technology | Purpose |
|-----------|---------|
| Docker | Containerization |
| supervisord | Process management (8 processes) |
| GitHub Actions | CI/CD pipeline |
| GitHub Container Registry | Docker image hosting |

## Backend Architecture (Clean Architecture)

```
TorreClou.sln
├── TorreClou.Core/              # Domain entities, interfaces
├── TorreClou.Application/       # Use cases, DTOs, validators
├── TorreClou.Infrastructure/    # EF Core, Redis, external services
├── TorreClou.API/               # Controllers, middleware, DI setup
├── TorreClou.Worker/            # Torrent download background jobs
├── TorreClou.GoogleDrive.Worker/# Google Drive sync background jobs
└── TorreClou.S3.Worker/         # S3 upload background jobs
```

**Dependency flow:** API/Workers → Application → Core ← Infrastructure

The API and all workers share the Core, Application, and Infrastructure layers. Each worker is an independent .NET process that connects to the same PostgreSQL and Redis instances.

## CI/CD Pipeline

### Cross-Repository Dispatch Architecture

```
┌───────────────────┐     repository_dispatch     ┌────────────────────┐
│ TorrenClou/backend│ ──────────────────────────> │                    │
│  (merge to main)  │                             │ TorrenClou/deploy  │
└───────────────────┘                             │                    │
                                                  │                    │
┌────────────────────┐    repository_dispatch     │  Builds combined   │
│ TorrenClou/frontend│ ─────────────────────────> │  Docker image and  │
│  (merge to main)   │                            │  pushes to ghcr.io │
└────────────────────┘                            └────────────────────┘
```

### Build Workflow

1. **Trigger**: `repository_dispatch` from either repo (on merge to main) or `workflow_dispatch` (manual)
2. **Checkout**: Deploy repo + Backend repo (into `backend/`) + Frontend repo (into `frontend/`)
3. **Build**: Multi-stage Dockerfile
   - Stage 1: `node:20-alpine` — Build Next.js frontend with standalone output
   - Stage 2: `dotnet/sdk:9.0` — Publish API + 3 workers
   - Stage 3: `ubuntu:22.04` — Runtime with PostgreSQL, Redis, supervisord, .NET runtime, Node.js
4. **Tag**: `YYYY.MM.DD-<backend-sha>-<frontend-sha>` + `latest`
5. **Push**: `ghcr.io/torrenclou/torrentclou`

### Concurrency Control

The workflow uses `concurrency: { group: build-combined, cancel-in-progress: true }` to ensure only one build runs at a time. If both repos merge simultaneously, the later build cancels the in-progress one (both would produce identical images since they both check out `main`).

### Secrets Required

| Secret | Where | Purpose |
|--------|-------|---------|
| `DEPLOY_PAT` | All 3 repos | GitHub PAT with `repo` scope for cross-repo access |
| `GITHUB_TOKEN` | Deploy repo (auto) | Push images to ghcr.io |

## Container Internals

### Process Management (supervisord)

| Process | Priority | Port | User |
|---------|----------|------|------|
| PostgreSQL 15 | 10 | 5432 (localhost only) | `postgres` |
| Redis 7 | 20 | 6379 (localhost only) | `redis` |
| .NET API | 30 | 5000 | `root` |
| Next.js Frontend | 40 | 3000 | `root` |
| Torrent Worker | 50 | - | `root` |
| Google Drive Worker | 50 | - | `root` |
| S3 Worker | 50 | - | `root` |

Priority determines startup order. PostgreSQL and Redis start first, then the API (which runs migrations), then the frontend and workers.

Workers have `stopwaitsecs=360` (6 minutes) to allow graceful shutdown of in-progress downloads.

### Entrypoint Initialization

On container start, `entrypoint.sh` runs:

1. **PostgreSQL init** (first run only): `initdb`, create user, create database
2. **Permissions**: Set ownership on data directories
3. **Environment mapping**: Convert user-facing env vars (e.g., `JWT_SECRET`) to .NET convention (e.g., `Jwt__Key`)
4. **Launch supervisord**: Starts all 7 processes

### Network Architecture (Internal)

All services communicate over `127.0.0.1` inside the container:

```
Browser → :3000 (Next.js)
Browser → :5000 (.NET API)
Next.js SSR → 127.0.0.1:5000 (server-side auth calls)
.NET API → 127.0.0.1:5432 (PostgreSQL)
.NET API → 127.0.0.1:6379 (Redis)
Workers → 127.0.0.1:5432 (PostgreSQL)
Workers → 127.0.0.1:6379 (Redis)
```

PostgreSQL and Redis are not exposed outside the container.

### Environment Variable Mapping

User-facing env vars are mapped to .NET's `Section__Key` convention in `entrypoint.sh`:

| User Sets | .NET Receives |
|-----------|---------------|
| `POSTGRES_PASSWORD` | `ConnectionStrings__DefaultConnection` (assembled) |
| `JWT_SECRET` | `Jwt__Key` |
| `JWT_ISSUER` | `Jwt__Issuer` |
| `GOOGLE_CLIENT_ID` | `Google__ClientId` |
| `HANGFIRE_WORKER_COUNT` | `Hangfire__WorkerCount` |

### Build-Time vs Runtime Variables

| Variable | When Set | Can Change Without Rebuild? |
|----------|----------|---------------------------|
| `NEXT_PUBLIC_API_URL` | Docker build | No (baked into JS bundle) |
| `NEXT_PUBLIC_BACKEND_URL` | Docker build | No (baked into JS bundle) |
| `BACKEND_URL` | Container start | Yes (server-side only) |
| `NEXTAUTH_URL` | Container start | Yes |
| All other env vars | Container start | Yes |

### Data Flow: Torrent Download

```
1. User uploads .torrent → API receives file
2. API creates job record in PostgreSQL
3. API enqueues download job via Hangfire → Redis
4. Torrent Worker picks up job from Redis
5. Worker downloads torrent to /data/downloads
6. Worker updates progress in PostgreSQL
7. On completion, Worker enqueues cloud sync job (if configured)
8. GDrive/S3 Worker picks up sync job
9. Worker uploads files to cloud storage
10. Worker updates status in PostgreSQL
```

## Image Versioning

Tags follow the format: `YYYY.MM.DD-<backend-7char-sha>-<frontend-7char-sha>`

Example: `2026.02.23-57e3b9d-132725a`

- The date identifies when the image was built
- The SHAs identify exactly which commits from each repo are included
- `latest` always points to the most recent build

## Observability (Optional)

The backend supports optional observability integration:

| Feature | Configuration |
|---------|---------------|
| Structured logging | Serilog (built-in) |
| Log aggregation | Loki (`OBSERVABILITY_LOKI_URL`) |
| Metrics | Prometheus (`/metrics` endpoint) |
| Tracing | OpenTelemetry (`OBSERVABILITY_OTLP_ENDPOINT`) |

The existing `docker-compose.yml` in the backend repo includes a full observability stack (Loki + Prometheus + Grafana) for development.
