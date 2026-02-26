$ErrorActionPreference = "Stop"

# ─── Config ───────────────────────────────────────────────
$Image = "ghcr.io/torrenclou/torrentclou:latest"
$ContainerName = "torrencloud"
$InstallDir = ".\torrencloud"
$RepoUrl = "https://github.com/TorrenClou/deploy.git"

$AdminEmail = "admin@torrencloud.local"
$AdminPassword = "TorrenCloud@2024"
$AdminName = "Admin"

# ─── Helpers ──────────────────────────────────────────────
function Write-Info    { param($msg) Write-Host "  > $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn    { param($msg) Write-Host "  ! $msg" -ForegroundColor Yellow }
function Write-Fail    { param($msg) Write-Host "  ✗ $msg" -ForegroundColor Red; exit 1 }

function New-Secret {
    param([int]$Bytes = 32)
    [Convert]::ToBase64String((1..$Bytes | ForEach-Object { Get-Random -Max 256 }) -as [byte[]])
}

# ─── Banner ───────────────────────────────────────────────
Write-Host ""
Write-Host "  ╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║         TorrenCloud Installer          ║" -ForegroundColor Cyan
Write-Host "  ╚════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ─── Prerequisites ────────────────────────────────────────
Write-Info "Checking prerequisites..."

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Fail "git is not installed. Install it from https://git-scm.com"
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Fail "Docker is not installed. Install it from https://docs.docker.com/get-docker/"
}

try {
    docker info 2>&1 | Out-Null
} catch {
    Write-Fail "Docker daemon is not running. Please start Docker and try again."
}

Write-Success "All prerequisites met"

# ─── Clone / Update Repo ─────────────────────────────────
if (Test-Path "$InstallDir\.git") {
    Write-Info "Existing installation found, updating..."
    Push-Location $InstallDir
    git pull --quiet
} else {
    Write-Info "Cloning deploy repository..."
    git clone --quiet $RepoUrl $InstallDir
    Push-Location $InstallDir
}

Write-Success "Repository ready"

# ─── Generate .env ────────────────────────────────────────
if (Test-Path ".env") {
    Write-Warn "Existing .env found - keeping current configuration"
} else {
    if (-not (Test-Path ".env.example")) {
        Write-Fail ".env.example not found in the repository"
    }

    Write-Info "Generating configuration..."
    Copy-Item ".env.example" ".env"

    # Generate secrets
    $PostgresPassword = New-Secret -Bytes 16
    $JwtSecret = New-Secret -Bytes 32
    $NextAuthSecret = New-Secret -Bytes 32

    # Replace placeholders
    $envContent = Get-Content ".env" -Raw
    $envContent = $envContent -replace "POSTGRES_PASSWORD=.*", "POSTGRES_PASSWORD=$PostgresPassword"
    $envContent = $envContent -replace "JWT_SECRET=.*", "JWT_SECRET=$JwtSecret"
    $envContent = $envContent -replace "NEXTAUTH_SECRET=.*", "NEXTAUTH_SECRET=$NextAuthSecret"
    $envContent = $envContent -replace "ADMIN_EMAIL=.*", "ADMIN_EMAIL=$AdminEmail"
    $envContent = $envContent -replace "ADMIN_PASSWORD=.*", "ADMIN_PASSWORD=$AdminPassword"
    $envContent = $envContent -replace "ADMIN_NAME=.*", "ADMIN_NAME=$AdminName"

    # Enable observability
    $envContent = $envContent -replace "# OBSERVABILITY_ENABLE_PROMETHEUS=.*", "OBSERVABILITY_ENABLE_PROMETHEUS=true"
    $envContent = $envContent -replace "# OBSERVABILITY_ENABLE_TRACING=.*", "OBSERVABILITY_ENABLE_TRACING=true"

    $envContent | Set-Content ".env" -NoNewline

    Write-Success "Configuration generated with secure random secrets"
}

# ─── Stop Existing Container ─────────────────────────────
$existing = docker ps -aq -f "name=$ContainerName" 2>$null
if ($existing) {
    Write-Info "Stopping existing container..."
    docker stop $ContainerName 2>$null | Out-Null
    docker rm $ContainerName 2>$null | Out-Null
    Write-Success "Old container removed"
}

# ─── Pull Image ──────────────────────────────────────────
Write-Info "Pulling latest Docker image..."
docker pull $Image
Write-Success "Image pulled"

# ─── Run Container ────────────────────────────────────────
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
    --env-file .env `
    $Image | Out-Null

Write-Success "Container started"

# ─── Wait for Healthy ────────────────────────────────────
Write-Info "Waiting for services to start (this may take up to 60 seconds)..."
$HealthUrl = "http://localhost:47200/api/health/ready"
$MaxWait = 90
$Elapsed = 0
$Healthy = $false

while ($Elapsed -lt $MaxWait) {
    try {
        $response = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            $Healthy = $true
            break
        }
    } catch {
        # Not ready yet
    }
    Start-Sleep -Seconds 3
    $Elapsed += 3
    Write-Host "`r    ${Elapsed}s elapsed..." -NoNewline -ForegroundColor DarkGray
}

Write-Host "`r                              `r" -NoNewline

if (-not $Healthy) {
    Write-Warn "Health check timed out - services may still be starting"
    Write-Host "    Run 'docker logs -f torrencloud' to check progress" -ForegroundColor DarkGray
} else {
    Write-Success "All services are healthy"
}

# ─── Print Credentials ───────────────────────────────────
$ConfigPath = (Resolve-Path ".env").Path

Write-Host ""
Write-Host "  ══════════════════════════════════════════════" -ForegroundColor Green
Write-Host "    ✓ TorrenCloud is ready!" -ForegroundColor Green
Write-Host "  ══════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "  -- Services --" -ForegroundColor White
Write-Host "  Frontend        " -NoNewline; Write-Host "http://localhost:47100" -ForegroundColor Cyan
Write-Host "  API             " -NoNewline; Write-Host "http://localhost:47200/api" -ForegroundColor Cyan
Write-Host "  Hangfire        " -NoNewline; Write-Host "http://localhost:47200/hangfire" -ForegroundColor Cyan
Write-Host ""
Write-Host "  -- Login --" -ForegroundColor White
Write-Host "  Email           " -NoNewline; Write-Host "$AdminEmail" -ForegroundColor Yellow
Write-Host "  Password        " -NoNewline; Write-Host "$AdminPassword" -ForegroundColor Yellow
Write-Host ""
Write-Host "  -- Monitoring --" -ForegroundColor White
Write-Host "  Grafana         " -NoNewline; Write-Host "http://localhost:47500" -ForegroundColor Cyan -NoNewline; Write-Host "     (admin / admin)" -ForegroundColor DarkGray
Write-Host "  Prometheus      " -NoNewline; Write-Host "http://localhost:47600" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ══════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  Config: $ConfigPath" -ForegroundColor DarkGray
Write-Host "  Change credentials and restart:" -ForegroundColor DarkGray
Write-Host "    docker restart torrencloud" -ForegroundColor DarkGray
Write-Host "  ══════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

Pop-Location
