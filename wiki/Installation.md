# Installation

## Requirements

- Docker, and a machine that can run Linux containers
- About 2 GB of RAM
- Enough disk for the torrents you intend to download — they land on a volume before being
  uploaded, and are deleted afterwards by default

Images are built for `linux/amd64` and `linux/arm64`, so an ARM VPS or a Raspberry Pi
works.

## The one-liner

```bash
curl -fsSL https://raw.githubusercontent.com/TorrenClou/deploy/main/install.sh | bash
```

Windows, in PowerShell:

```powershell
irm https://raw.githubusercontent.com/TorrenClou/deploy/main/install.ps1 | iex
```

It checks Docker is running, pulls the image, starts it, waits for it to become healthy,
and prints the URL to open. There is no configuration step.

If you would rather read the script before running it — a reasonable habit — it is
[install.sh](https://github.com/TorrenClou/deploy/blob/main/install.sh), about 90 lines.

## Manual install

The installer runs exactly this:

```bash
docker run -d \
    --name torrencloud \
    --restart unless-stopped \
    -p 47100:47100 \
    -p 47200:47200 \
    -p 47500:47500 \
    -p 47600:47600 \
    -v torrencloud-pgdata:/data/postgres \
    -v torrencloud-redis:/data/redis \
    -v torrencloud-downloads:/data/downloads \
    ghcr.io/torrenclou/torrentclou:latest
```

No `-e` flags and no `--env-file`. The container works out the rest.

If you only want the app, drop the `-p 47500` and `-p 47600` lines — those are Grafana and
Prometheus, and the app does not need them.

## Reaching it

The installer prints an `sslip.io` address, which is a public DNS service that resolves
`203-0-113-5.sslip.io` to `203.0.113.5`. That gives you a working hostname on a fresh
server with no DNS set up. It is only a convenience for the printed link — the app works on
whatever address you reach it by.

Open port 47100 in your firewall:

```bash
sudo ufw allow 47100/tcp
```

## Custom domain

Point an A record at the server and open the app on it. Nothing to configure — the app
derives its own address from the request.

## Behind a reverse proxy

A minimal nginx server block:

```nginx
server {
    listen 443 ssl;
    server_name torrents.example.com;

    # ... your certificate directives ...

    location / {
        proxy_pass http://127.0.0.1:47100;
        proxy_set_header Host              $host;
        proxy_set_header X-Forwarded-Host  $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;

        # Large uploads and long-lived progress streams
        client_max_body_size 100M;
        proxy_read_timeout   3600s;
    }
}
```

The `X-Forwarded-Host` and `X-Forwarded-Proto` headers matter: the app uses them to work
out its own public address, which is what the Google Drive OAuth callback returns to. If
your proxy cannot send them, set the address explicitly instead:

```bash
docker run -d ... \
    -e PUBLIC_FRONTEND_URL=https://torrents.example.com \
    -e NEXTAUTH_URL=https://torrents.example.com \
    ghcr.io/torrenclou/torrentclou:latest
```

Traefik and Caddy both send those headers by default.

## Storing downloads on a specific disk

Bind-mount a path instead of using the named volume:

```bash
-v /mnt/big-disk/torrents:/data/downloads
```

Torrents can be large, and this is the volume that grows.

## Uninstall

```bash
docker rm -f torrencloud
docker volume rm torrencloud-pgdata torrencloud-redis torrencloud-downloads
```

The second command deletes everything, including your account. See [Updating](Updating)
for how to take a backup first.
