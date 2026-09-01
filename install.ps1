# TorrenCloud installer for Windows.
#
#   irm https://raw.githubusercontent.com/TorrenClou/deploy/main/install.ps1 | iex
#
# Pulls the image, starts it, and prints the URL to open. There is no configuration
# step: the container generates its own secrets on first boot and everything else
# is set up in the browser.

$ErrorActionPreference = "Stop"

$Image = "ghcr.io/torrenclou/torrentclou:latest"
$ContainerName = "torrencloud"

function Write-Info    { param($m) Write-Host "  > $m" -ForegroundColor Cyan }
function Write-Ok      { param($m) Write-Host "  + $m" -ForegroundColor Green }
function Write-Warn    { param($m) Write-Host "  ! $m" -ForegroundColor Yellow }
function Write-Fail    { param($m) Write-Host "  x $m" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Cyan
Write-Host "           TorrenCloud Installer" -ForegroundColor Cyan
Write-Host "  ==========================================" -ForegroundColor Cyan
Write-Host ""

# --- Prerequisites -------------------------------------------------
# Docker is the only one. Nothing is cloned and no secrets are generated here.
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Fail "Docker is not installed. Install Docker Desktop from https://docs.docker.com/get-docker/"
}

docker info 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Docker daemon is not running. Start Docker Desktop and try again."
}

Write-Ok "Docker is ready"

# --- Replace any existing container ---------------------------------
# The named volumes are left alone, so an upgrade keeps its database, downloads
# and generated secrets.
$existing = docker ps -aq -f "name=^$ContainerName$"
if ($existing) {
    Write-Info "Replacing the existing container (data volumes are kept)..."
    docker stop $ContainerName 2>&1 | Out-Null
    docker rm $ContainerName 2>&1 | Out-Null
}

Write-Info "Pulling $Image..."
docker pull $Image
if ($LASTEXITCODE -ne 0) { Write-Fail "Could not pull the image." }

Write-Info "Starting TorrenCloud..."
docker run -d `
    --name $ContainerName `
    --restart unless-stopped `
    -p 47100:47100 `
    -p 47200:47200 `
    -p 47500:47500 `
    -p 47600:47600 `
    -v torrencloud-pgdata:/data/postgres `
    -v torrencloud-redis:/data/redis `
    -v torrencloud-downloads:/data/downloads `
    $Image | Out-Null

if ($LASTEXITCODE -ne 0) { Write-Fail "Could not start the container." }
Write-Ok "Container started"

# --- Wait for it to come up -----------------------------------------
Write-Info "Waiting for services to start (up to 90 seconds)..."
$elapsed = 0
$healthy = $false
while ($elapsed -lt 90) {
    try {
        Invoke-WebRequest -Uri "http://localhost:47200/api/health/ready" -UseBasicParsing -TimeoutSec 3 | Out-Null
        $healthy = $true
        break
    } catch {
        Start-Sleep -Seconds 3
        $elapsed += 3
        Write-Host "`r    $elapsed s elapsed..." -NoNewline -ForegroundColor DarkGray
    }
}
Write-Host "`r                            `r" -NoNewline

if ($healthy) {
    Write-Ok "All services are healthy"
} else {
    Write-Warn "Health check timed out - services may still be starting"
    Write-Host "  Run 'docker logs -f $ContainerName' to watch progress" -ForegroundColor DarkGray
}

# --- Print where to go ----------------------------------------------
Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Green
Write-Host "    TorrenCloud is running" -ForegroundColor Green
Write-Host "  ==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Open this and create your account:"
Write-Host "  http://localhost:47100" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Grafana on :47500, Prometheus on :47600." -ForegroundColor DarkGray
Write-Host "  Grafana's password: docker exec $ContainerName cat /data/postgres/secrets.env" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Logs:    docker logs -f $ContainerName" -ForegroundColor DarkGray
Write-Host "  Restart: docker restart $ContainerName" -ForegroundColor DarkGray
Write-Host "  Docs:    https://github.com/TorrenClou/deploy/wiki" -ForegroundColor DarkGray
Write-Host ""
