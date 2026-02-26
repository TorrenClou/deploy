$ErrorActionPreference = "Stop"

$Image = "ghcr.io/torrenclou/torrentclou:latest"
$ContainerName = "torrencloud"
$EnvFile = ".env"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  TorrentClou - All-in-One Launcher" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Check Docker is running
try {
    docker info 2>&1 | Out-Null
} catch {
    Write-Host "Error: Docker is not running. Please start Docker and try again." -ForegroundColor Red
    exit 1
}

# Check .env file exists
if (-not (Test-Path $EnvFile)) {
    Write-Host "No .env file found. Creating from .env.example..." -ForegroundColor Yellow
    if (Test-Path ".env.example") {
        Copy-Item ".env.example" ".env"
        Write-Host "Please edit .env and replace all <CHANGE_ME> values, then re-run this script." -ForegroundColor Red
        exit 1
    } else {
        Write-Host "Error: .env.example not found. Please create a .env file." -ForegroundColor Red
        exit 1
    }
}

# Validate required env vars
$Missing = $false
Get-Content $EnvFile | ForEach-Object {
    if ($_ -match "^[^#].*=.*(<CHANGE_ME>|your_)") {
        $key = ($_ -split "=")[0]
        Write-Host "  Missing: $key still has a placeholder value" -ForegroundColor Red
        $Missing = $true
    }
}

if ($Missing) {
    Write-Host "Please update the values above in .env before running." -ForegroundColor Red
    exit 1
}

# Stop existing container if running
$existing = docker ps -aq -f "name=$ContainerName" 2>$null
if ($existing) {
    Write-Host "Stopping existing container..." -ForegroundColor Yellow
    docker stop $ContainerName 2>$null | Out-Null
    docker rm $ContainerName 2>$null | Out-Null
}

# Pull latest image
Write-Host "Pulling latest image..."
docker pull $Image

# Run
Write-Host "Starting TorrentClou..."
docker run -d `
    --name $ContainerName `
    -p 47100:47100 `
    -p 47200:47200 `
    -v torrencloud-pgdata:/data/postgres `
    -v torrencloud-redis:/data/redis `
    -v torrencloud-downloads:/data/downloads `
    --env-file $EnvFile `
    --restart unless-stopped `
    $Image

Write-Host ""
Write-Host "TorrentClou is starting up!" -ForegroundColor Green
Write-Host ""
Write-Host "  Frontend:           http://localhost:47100"
Write-Host "  API:                http://localhost:47200/api"
Write-Host "  Hangfire Dashboard: http://localhost:47200/hangfire"
Write-Host ""
Write-Host "  View logs:  docker logs -f torrencloud"
Write-Host "  Stop:       docker stop torrencloud"
Write-Host ""
