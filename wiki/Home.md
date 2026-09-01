# TorrenCloud

Self-hosted torrent-to-cloud. It downloads torrents on your server and uploads them to
Google Drive or S3-compatible storage, then cleans up after itself.

Everything ships as one container that generates its own secrets and is configured in the
browser. If you find yourself editing a config file to do something ordinary, that is a
bug — please open an issue.

## Getting started

- **[Installation](Installation)** — the one-liner, manual `docker run`, reverse proxies,
  custom domains
- **[First-Run Setup](First-Run-Setup)** — the setup wizard, connecting Google Drive,
  connecting S3

## Running it

- **[Configuration](Configuration)** — every setting, what is live and what needs a
  restart, and the environment overrides
- **[Updating](Updating)** — upgrades, backups, rollbacks
- **[Troubleshooting](Troubleshooting)** — when something does not work

## Understanding it

- **[Architecture](Architecture)** — what runs inside the container and how a torrent
  becomes a file in your Drive
- **[Security](Security)** — where secrets live, what is exposed, what to put behind a
  proxy

## Ports

| Port | Service |
|------|---------|
| 47100 | Web interface |
| 47200 | API, plus `/hangfire` |
| 47500 | Grafana |
| 47600 | Prometheus |

Only 47100 needs to be reachable for normal use.

## Repositories

- [backend](https://github.com/TorrenClou/backend) — .NET 9 API and workers
- [frontend](https://github.com/TorrenClou/frontend) — Next.js 15 web app
- [deploy](https://github.com/TorrenClou/deploy) — Dockerfile, installer, CI
