# Contributing to TorrentClou

Thank you for your interest in contributing to TorrentClou. This document provides guidelines for contributing to the deployment repository and the overall project.

## Repository Structure

TorrentClou is split across three repositories:

| Repository | Purpose |
|------------|---------|
| [TorrenClou/backend](https://github.com/TorrenClou/backend) | .NET 9.0 API and background workers |
| [TorrenClou/frontend](https://github.com/TorrenClou/frontend) | Next.js 15 web application |
| [TorrenClou/deploy](https://github.com/TorrenClou/deploy) | Dockerfile, CI/CD, deployment scripts (this repo) |

## How to Contribute

### Reporting Issues

- Use the **Issues** tab on the relevant repository
- Include steps to reproduce, expected behavior, and actual behavior
- For Docker/deployment issues, include `docker logs torrencloud` output

### Pull Requests

1. Fork the relevant repository
2. Create a feature branch from `main`
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Make your changes
4. Test locally
5. Submit a pull request to `main`

### Branch Naming

| Prefix | Purpose |
|--------|---------|
| `feature/` | New functionality |
| `fix/` | Bug fixes |
| `docs/` | Documentation changes |
| `refactor/` | Code restructuring |

## Development Setup

### Backend

```bash
git clone https://github.com/TorrenClou/backend.git
cd backend
cp .env.example .env
docker-compose up -d
```

Requires: .NET 9.0 SDK, Docker

### Frontend

```bash
git clone https://github.com/TorrenClou/frontend.git
cd frontend
cp .env.example .env.local
yarn install
yarn dev
```

Requires: Node.js 20+, yarn

### Deploy Repo

Changes to the Dockerfile, entrypoint, or supervisord config should be tested by building the image locally:

```bash
git clone https://github.com/TorrenClou/deploy.git
cd deploy

# Clone source repos for build context
git clone https://github.com/TorrenClou/backend.git
git clone https://github.com/TorrenClou/frontend.git

# Build locally
docker build -t torrencloud-test .
```

## Build & Release Process

Merging to `main` in **any** of the three repos triggers an automated build:

```
Backend merge to main  ──┐
                          ├──> deploy repo builds combined image
Frontend merge to main ──┘     and pushes to ghcr.io/torrenclou/torrentclou
```

- Direct pushes to `main` are discouraged; use pull requests
- All PRs should be reviewed before merging
- The deploy repo workflow can also be triggered manually via `workflow_dispatch`

## Code Style

### Backend (.NET)
- Follow existing Clean Architecture patterns
- Use async/await consistently
- Environment variables via `IConfiguration` (no hardcoded values)

### Frontend (Next.js)
- TypeScript strict mode
- Tailwind CSS for styling
- Zod for runtime validation
- React Query for server state

### Deploy Repo
- Shell scripts must be POSIX-compatible where possible
- Dockerfile instructions should be ordered for optimal layer caching
- All environment variables must have defaults in `entrypoint.sh`

## Questions?

Open an issue or reach out to the maintainers.
