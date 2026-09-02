# TorrentClou — Usage Guide

## Prerequisites

- **Docker** 20.10 or later ([Install Docker](https://docs.docker.com/get-docker/))
- At least **2 GB of free RAM**
- At least **3 GB of free disk space** (for the Docker image)
- A **Google OAuth Client ID** if you want Google login ([Setup Guide](https://console.cloud.google.com/))

## Installation

### Step 1: Get the configuration files

```bash
git clone https://github.com/TorrenClou/deploy.git
cd deploy
```

Or download just the files you need:
- [`.env.example`](https://github.com/TorrenClou/deploy/blob/main/.env.example)
- [`run.sh`](https://github.com/TorrenClou/deploy/blob/main/run.sh) (Linux/macOS)
- [`run.ps1`](https://github.com/TorrenClou/deploy/blob/main/run.ps1) (Windows)

### Step 2: Configure environment

```bash
cp .env.example .env
```

Open `.env` in your editor and fill in the required values:

| Variable | What to put |
|----------|-------------|
| `POSTGRES_PASSWORD` | Any strong password (used internally, you won't type it) |
| `JWT_SECRET` | A random string, at least 32 characters |
| `NEXTAUTH_SECRET` | A different random string |
| `GOOGLE_CLIENT_ID` | From Google Cloud Console → APIs & Services → Credentials |
| `ADMIN_EMAIL` | Your login email |
| `ADMIN_PASSWORD` | Your login password |

You can generate random secrets with:

```bash
# Linux/macOS
openssl rand -base64 32

# PowerShell
[Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Max 256 }) -as [byte[]])
```

### Step 3: Run

**Linux / macOS:**
```bash
chmod +x run.sh
./run.sh
```

**Windows (PowerShell):**
```powershell
.\run.ps1
```

The script will:
1. Validate your `.env` file
2. Pull the latest Docker image
3. Start the container with proper volumes

### Step 4: Verify

Wait about 30 seconds for all services to initialize, then open:

- **http://localhost:47100** — Login page
- **http://localhost:47200/api/health/ready** — Should return a healthy status

Check logs if something isn't working:
```bash
docker logs -f torrencloud
```

## Using TorrentClou

### Login

Navigate to `http://localhost:47100` and log in with the `ADMIN_EMAIL` and `ADMIN_PASSWORD` you set in `.env`.

### Adding Torrents

1. Go to the Torrents page
2. Upload a `.torrent` file or paste a magnet link
3. The torrent will start downloading in the background
4. Monitor progress on the dashboard

### Google Drive Integration

1. Go to Storage → Google Drive
2. Add your Google OAuth credentials (Client ID + Client Secret)
3. Authorize access to your Google Drive
4. Configure auto-sync rules for completed downloads

### S3 Integration

1. Go to Storage → S3
2. Add your S3-compatible credentials (AWS, Backblaze B2, MinIO, etc.)
3. Configure upload rules

### Hangfire Dashboard

Access the background job dashboard at `http://localhost:47200/hangfire` to monitor:
- Active downloads
- Queued jobs
- Failed jobs and retry status

## Common Operations

### View logs
```bash
docker logs -f torrencloud
```

### Stop the application
```bash
docker stop torrencloud
```

### Start again (data persists)
```bash
docker start torrencloud
```

### Access the database directly
```bash
docker exec -it torrencloud psql -U torrenclo_user -d torrenclo
```

### Access downloaded files
```bash
docker exec -it torrencloud ls /data/downloads
```

Or mount a local directory instead of a Docker volume:
```bash
docker run -d --name torrencloud \
  -p 47100:47100 -p 47200:47200 \
  -v torrencloud-pgdata:/data/postgres \
  -v torrencloud-redis:/data/redis \
  -v /path/to/your/downloads:/data/downloads \
  --env-file .env \
  ghcr.io/torrenclou/torrentclou:latest
```

### Check disk usage
```bash
docker system df -v | grep torrencloud
```

## Custom Domain Setup

If you deploy on a server with a domain name:

1. Update `.env`:
   ```
   NEXTAUTH_URL=https://your-domain.com:47100
   ```

2. For Google Drive OAuth to work with a custom domain, the image must be rebuilt with:
   ```
   docker build --build-arg NEXT_PUBLIC_BACKEND_URL=https://your-domain.com:47200 -t torrencloud-custom .
   ```

## Troubleshooting

### Container starts but frontend shows errors

Check that all required `.env` values are filled in (no `<CHANGE_ME>` placeholders remaining).

### "Connection refused" when accessing the API

The API takes about 15-20 seconds to start up (database migrations run on first boot). Wait and try again.

### Database migration errors in logs

This usually happens on first start. If the API fails to start after 60 seconds, check:
```bash
docker logs torrencloud 2>&1 | grep -i "error\|exception"
```

### Port already in use

Another application is using port 47100 or 47200. Either stop that application or change the port mapping:
```bash
docker run -d --name torrencloud -p 47101:47100 -p 47201:47200 ...
```

Then update `NEXTAUTH_URL=http://localhost:47101` in your `.env`.
