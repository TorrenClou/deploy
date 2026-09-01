# TorrenCloud

Self-hosted torrent-to-cloud. Point it at a `.torrent`, pick the files you want, and it
downloads them on your server and uploads them straight to Google Drive or any
S3-compatible storage.

One container. No configuration files.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/TorrenClou/deploy/main/install.sh | bash
```

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/TorrenClou/deploy/main/install.ps1 | iex
```

Then open the URL it prints and create your account.

Requires Docker. Nothing else — no `.env` to edit, no secrets to generate. The container
creates its own on first boot and keeps them on its data volume.

## What happens on first run

1. The container generates its database password, signing keys and session secret.
2. You open the app and it shows a setup wizard.
3. You create the admin account — this is the only account, and there is no password
   reset, so keep it somewhere safe.
4. You connect Google Drive or S3. Both use your own credentials; nothing is proxied
   through a third party.
5. That is it. Everything else has a working default and lives in **Settings**.

## Services

| Service | Port | What it is |
|---------|------|------------|
| App | 47100 | The web interface |
| API | 47200 | REST API, and `/hangfire` for the job dashboard |
| Grafana | 47500 | Dashboards. Password is in `/data/postgres/secrets.env` |
| Prometheus | 47600 | Metrics |

Only 47100 needs to be reachable for normal use.

## Everyday commands

```bash
docker logs -f torrencloud
```

```bash
docker restart torrencloud
```

To upgrade, run the install command again. It replaces the container and keeps your
database, downloads and secrets.

## Configuration

In the app, under **Settings** — transfer concurrency, upload failover, what happens to
local files after an upload, and disk cleanup.

Environment variables exist only for the cases the app cannot work out for itself: an
external database, a reverse proxy that rewrites the host, or shipping logs off-box. See
[`.env.example`](.env.example), or the
[Configuration](https://github.com/TorrenClou/deploy/wiki/Configuration) wiki page.

> Your data lives in three Docker volumes: `torrencloud-pgdata`, `torrencloud-redis` and
> `torrencloud-downloads`. `torrencloud-pgdata` also holds the generated secrets — delete
> it and everyone is logged out.

## Documentation

Everything else is in the [wiki](https://github.com/TorrenClou/deploy/wiki):

- [Installation](https://github.com/TorrenClou/deploy/wiki/Installation) — manual `docker run`, custom domains, reverse proxies
- [First-run setup](https://github.com/TorrenClou/deploy/wiki/First-Run-Setup) — Google Drive and S3 walkthroughs
- [Configuration](https://github.com/TorrenClou/deploy/wiki/Configuration) — every setting, and the environment overrides
- [Updating](https://github.com/TorrenClou/deploy/wiki/Updating) — upgrades, backups, rollbacks
- [Architecture](https://github.com/TorrenClou/deploy/wiki/Architecture) — what runs inside the container
- [Security](https://github.com/TorrenClou/deploy/wiki/Security) — where secrets live, what to put behind a proxy
- [Troubleshooting](https://github.com/TorrenClou/deploy/wiki/Troubleshooting)

## Repositories

| Repository | Contents |
|------------|----------|
| [backend](https://github.com/TorrenClou/backend) | .NET 9 API and workers |
| [frontend](https://github.com/TorrenClou/frontend) | Next.js 15 web app |
| [deploy](https://github.com/TorrenClou/deploy) | Dockerfile, installer, CI — this repo |

Contributions welcome: see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Proprietary. All rights reserved.
