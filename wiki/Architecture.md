# Architecture

## Why one container

TorrenCloud is really eight processes and two datastores. Shipping them as one image is a
deliberate trade: it is not how you would run this at scale, but it means a self-hoster
runs one command instead of orchestrating a compose file, and there is no version skew
between the parts.

If you would rather split it up, the pieces are ordinary .NET and Next.js applications and
the repositories build independently.

## What runs inside

Supervisord manages nine programs:

| Program | Port | What it does |
|---------|------|--------------|
| `postgres` | 5432 | PostgreSQL 15. Bound to `127.0.0.1`, never published |
| `redis` | 6379 | Cache, job state, cancellation signals. Bound to localhost |
| `api` | 47200 | ASP.NET Core API, and the Hangfire dashboard at `/hangfire` |
| `frontend` | 47100 | Next.js 15, standalone output |
| `torrent-worker` | — | Downloads torrents via MonoTorrent |
| `gdrive-worker` | — | Uploads to Google Drive |
| `s3-worker` | — | Uploads to S3-compatible storage |
| `prometheus` | 47600 | Scrapes metrics |
| `grafana` | 47500 | Dashboards |

Only 47100, 47200, 47500 and 47600 are exposed. PostgreSQL and Redis listen on loopback
inside the container and are not reachable from the host.

## Startup

`entrypoint.sh` does the following before supervisord takes over:

1. **Generates secrets** into `/data/postgres/secrets.env` if that file does not exist — the
   database password, the JWT signing key, the session secret and the Grafana password.
   Anything already in the environment wins.
2. **Initializes PostgreSQL** if the data directory is empty, then syncs the user's
   password on every boot.
3. **Reads the settings the app owns** — worker count and the observability toggles — from
   the `SystemSettings` table, so a change you made in the Settings tab takes effect on
   restart.
4. **Exports the runtime configuration**, translating friendly variable names into the
   `Section__Key` form .NET expects.

The API and the three workers each start behind `wait-for-db.sh`, which polls `pg_isready`
before handing over.

## How a torrent becomes a file in your Drive

1. You upload a `.torrent`. The API parses it and scrapes trackers for health data.
2. You pick files and a destination. The API creates a job and enqueues it on the
   `torrents` Hangfire queue.
3. `torrent-worker` picks it up and downloads to `/data/downloads/<jobId>`, holding its
   worker for the whole transfer — which is why the worker count is a hard ceiling on
   concurrency.
4. On completion the job moves to the `googledrive` or `s3` queue.
5. The upload worker streams each file to your storage, resuming from Redis state if it is
   retried.
6. When every file has uploaded, the local directory is deleted — unless you turned that
   off.

If a destination fails partway through and rerouting is on, the job moves to another
healthy drive rather than failing, up to the reroute cap.

## Configuration model

Two tables, both read through the app:

- **`SystemSettings`** — one row, instance-wide. Transfer concurrency, upload failover
  tuning, observability toggles, and the timestamp that records setup as complete.
- **`UserSettings`** — per account. Currently just delete-after-upload.

Routing values are cached in-process for 30 seconds and refreshed by a background service,
so a change is live across the API and both upload workers without a restart. The three
values read only at process start — worker count and the two observability toggles — are
labelled as needing a restart in the UI, and the entrypoint reads them back on boot.

Environment variables seed the row the first time it is created, then stop mattering. That
is what lets an install configured through the environment keep its tuning across the
upgrade.

## Data

| Volume | Contents |
|--------|----------|
| `torrencloud-pgdata` | PostgreSQL data **and `/data/postgres/secrets.env`** |
| `torrencloud-redis` | Redis persistence |
| `torrencloud-downloads` | In-flight torrent downloads |

`torrencloud-pgdata` is the one that matters. See [Updating](Updating) for backups.

## Build and release

The deploy repository holds the Dockerfile; the application code lives in the backend and
frontend repositories. Merging to `main` in either fires a `repository_dispatch` at the
deploy repo, which checks out both, builds the combined image, and pushes it to
`ghcr.io/torrenclou/torrentclou` as `latest` and as
`YYYY.MM.DD-<backend-sha>-<frontend-sha>`.

Built for `linux/amd64` and `linux/arm64`.

## Stack

**Backend** — .NET 9, EF Core 9 with Npgsql, Hangfire for background jobs, MonoTorrent for
the BitTorrent client, Serilog, OpenTelemetry.

**Frontend** — Next.js 15 App Router, React 18, TypeScript strict, Tailwind, TanStack
Query, Zustand, Zod, NextAuth 5.

The backend follows a Clean Architecture split: `Core` holds entities and interfaces,
`Application` holds services, `Infrastructure` holds implementations and data access, and
`API` plus the three worker projects are the hosts.
