# Configuration

Almost everything is in the app, under **Settings**. Environment variables exist only for
the handful of things the container cannot work out for itself.

## In the app

### Account

Change your password. Requires the current one; minimum 12 characters.

### Transfers

| Setting | Default | What it does |
|---------|---------|--------------|
| Reroute failed uploads | on | When a drive stops accepting uploads, move the job to another healthy one instead of failing it |
| Reroute attempts per job | 3 | Cap on automatic reroutes. Stops one job walking every drive you own when the real fault is the file |
| Failures before a drive is unhealthy | 3 | Consecutive upload failures on one drive before it stops being offered |
| Concurrent transfers | 10 | **Restart required.** How many torrents run at once |

Concurrent transfers is the one to understand. A download occupies a worker for its entire
transfer, so this is a hard ceiling: with it set to 10, the eleventh torrent waits, however
idle the machine looks. Raise it if you have bandwidth and disk to spare; lower it on a
small VPS.

Changes to the others take effect within about 30 seconds, with no restart.

### Downloads

**Delete downloads after upload** (on by default) removes a job's local directory once
every file has reached your cloud storage. Turn it off to keep local copies — they then
only go away when you purge.

### Local Storage

Shows what the downloads volume holds, split three ways:

- **Purgeable** — directories for completed and cancelled jobs. What **Purge** deletes.
- **Retained** — jobs still running, retrying or failed. Kept, because those jobs may still
  need the files.
- **Orphaned** — directories with no matching job. Counted so the space is visible, never
  deleted automatically.

**Purge** only ever removes the purgeable set.

## Environment variables

All optional. Setting one overrides the built-in behaviour for that value only.

### Public address

| Variable | Default | When you need it |
|----------|---------|------------------|
| `PUBLIC_FRONTEND_URL` | derived from the request | A proxy that does not send `X-Forwarded-Host` |
| `NEXTAUTH_URL` | derived from the request | Same |
| `FRONTEND_URL` | falls back to `PUBLIC_FRONTEND_URL` | Overrides just the OAuth return address |

Normally the app works out its own address from the incoming request, which is why it
works on any host or IP with no configuration.

### Database

| Variable | Default |
|----------|---------|
| `POSTGRES_DB` | `torrenclo` |
| `POSTGRES_USER` | `torrenclo_user` |
| `POSTGRES_PASSWORD` | generated on first run |

### Secrets

| Variable | Default |
|----------|---------|
| `JWT_SECRET` | generated on first run |
| `NEXTAUTH_SECRET` | generated on first run |
| `GRAFANA_ADMIN_USER` | `admin` |
| `GRAFANA_ADMIN_PASSWORD` | generated on first run |

Generated values live in `/data/postgres/secrets.env` on the `torrencloud-pgdata` volume. Read them
with:

```bash
docker exec torrencloud cat /data/postgres/secrets.env
```

Set `JWT_SECRET` and `NEXTAUTH_SECRET` explicitly if you want sessions to survive a rebuilt
data volume.

### Observability

| Variable | Default |
|----------|---------|
| `OBSERVABILITY_LOKI_URL` | unset |
| `OBSERVABILITY_LOKI_USERNAME` | unset |
| `OBSERVABILITY_LOKI_API_KEY` | unset |
| `OBSERVABILITY_OTLP_ENDPOINT` | unset |
| `OBSERVABILITY_OTLP_HEADERS` | unset |

For shipping logs and traces off-box. The bundled Grafana and Prometheus work without any
of this.

### Legacy admin

| Variable | Default |
|----------|---------|
| `ADMIN_EMAIL` | unset |
| `ADMIN_PASSWORD` | unset |
| `ADMIN_NAME` | unset |

Only for installs that predate the setup wizard. **Setting these disables the wizard**,
because an instance whose owner already has a way in must not offer itself to whoever
arrives first. See [First-Run Setup](First-Run-Setup#upgrading-an-older-install).

### Other

| Variable | Default | Notes |
|----------|---------|-------|
| `HANGFIRE_WORKER_COUNT` | 10 | Overridden by the Settings value once you save one |
| `APPLY_MIGRATIONS` | `true` | Run database migrations on start |
| `BACKEND_URL` | `http://127.0.0.1:47200` | Where the frontend finds the API |
| `JWT_ISSUER` / `JWT_AUDIENCE` | `TorrenClou_API` / `TorrenClou_Client` | No reason to change these |

## Precedence

For the three settings that exist in both places — worker count and the two observability
toggles — the order is:

1. The value saved in **Settings**, read at container start
2. The environment variable
3. The built-in default

So once you save a worker count in the app, `HANGFIRE_WORKER_COUNT` no longer has any
effect.

## Using a .env file

```bash
docker run -d --env-file .env ... ghcr.io/torrenclou/torrentclou:latest
```

[`.env.example`](https://github.com/TorrenClou/deploy/blob/main/.env.example) lists the
overrides, all commented out. You do not need the file.
