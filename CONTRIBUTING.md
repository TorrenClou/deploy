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

Merging to `main` in any of the three repos triggers the deploy repo to build and push the
combined image. Details are on the
[Architecture](https://github.com/TorrenClou/deploy/wiki/Architecture) wiki page.

Use pull requests rather than pushing to `main` directly.

## Code Style

### Backend (.NET)
- Follow existing Clean Architecture patterns
- Use async/await consistently
- Configuration a user should be able to change belongs in `SystemSettings` or
  `UserSettings`, not in an environment variable. The environment is for things the app
  cannot discover itself: connection strings, and overrides for unusual deployments.

### Frontend (Next.js)
- TypeScript strict mode
- Tailwind CSS for styling
- Zod for runtime validation
- React Query for server state

### Deploy Repo
- Shell scripts must be POSIX-compatible where possible
- Dockerfile instructions should be ordered for optimal layer caching
- Every environment variable must have a default in `entrypoint.sh`. `docker run` with
  no `--env-file` and no `-e` flags has to produce a working install — that is the
  property the installer depends on, so a change that breaks it is a bug.

## Questions?

Open an issue or reach out to the maintainers.
