# Building TorrentClou: A Full-Stack Cloud Torrent Platform in a Single Docker Image

## The Problem

Managing torrent downloads on remote servers is painful. You SSH in, run a CLI client, babysit the process, then manually transfer files to cloud storage. If you want a web interface, you're stitching together multiple tools that don't talk to each other.

I wanted something different: a single, self-hosted platform where I could upload a torrent, watch it download, and have it automatically sync to my Google Drive or S3 — all from a clean web UI. And I wanted anyone to be able to run it with one command.

That's TorrentClou.

## What It Does

TorrentClou is a self-hosted web application that handles the entire torrent-to-cloud pipeline:

- **Upload** a `.torrent` file or paste a magnet link from a modern web interface
- **Monitor** download progress in real-time on a dashboard
- **Auto-sync** completed downloads to Google Drive or any S3-compatible storage (AWS, Backblaze B2, MinIO)
- **Manage** everything from a responsive web UI that works on desktop and mobile

The entire platform — frontend, backend, database, cache, and background workers — ships as a single Docker image. Getting it running takes one command and about 30 seconds.

## The Tech Stack

Building a platform that bundles this much functionality required careful technology choices across every layer.

### Frontend: Next.js 15 with TypeScript

The frontend is built with **Next.js 15** using the App Router, **React 18**, and **TypeScript** in strict mode. The UI uses **Tailwind CSS** with **Radix UI** primitives for accessible, composable components.

Server state is managed with **React Query** (TanStack Query), which handles caching, background refetching, and optimistic updates — essential for a dashboard that needs to show real-time download progress. Client state is minimal and managed with **Zustand**.

Authentication uses **NextAuth.js v5** with a credentials provider backed by the .NET API, plus Google OAuth for seamless login.

### Backend: .NET 9.0 Clean Architecture

The backend follows **Clean Architecture** with a clear separation across four layers:

- **Core**: Domain entities, interfaces, and business rules
- **Application**: Use cases, DTOs, and validation logic
- **Infrastructure**: Entity Framework Core (PostgreSQL), Redis integration, external API clients
- **API**: ASP.NET Core controllers, middleware, dependency injection

This separation means the business logic has zero dependencies on frameworks or databases — making it testable and maintainable as the project grows.

### Background Processing: Distributed Workers

Torrent downloads and cloud uploads are long-running operations that don't belong in an API request-response cycle. TorrentClou uses **Hangfire** for background job processing with three dedicated worker processes:

1. **Torrent Worker** — Handles the actual torrent downloads
2. **Google Drive Worker** — Syncs completed files to Google Drive via OAuth
3. **S3 Worker** — Uploads to any S3-compatible storage

Each worker runs as an independent .NET process, connected to the same PostgreSQL database and Redis instance. This architecture means a slow download doesn't block cloud uploads, and vice versa.

### Data Layer: PostgreSQL + Redis

**PostgreSQL 15** serves as the primary database — storing user data, job records, download metadata, and cloud storage configurations. **Redis 7** handles caching, Hangfire job queues, and distributed locks to prevent duplicate processing.

## The DevOps Challenge: One Image to Rule Them All

The hardest part of this project wasn't the application code — it was the deployment story.

Most Docker projects use docker-compose with separate containers for each service. That's the "right" way, but it's also a barrier for users who just want to try something out. I wanted TorrentClou to be as easy to run as `docker run`.

### Multi-Stage Dockerfile

The solution is a multi-stage Dockerfile that builds everything in isolated stages and combines them into a single runtime image:

**Stage 1** builds the Next.js frontend in a Node.js Alpine container, producing an optimized standalone output.

**Stage 2** builds the .NET backend in a .NET SDK container, publishing four separate binaries (API + 3 workers).

**Stage 3** assembles the runtime on Ubuntu 22.04, installing PostgreSQL 15, Redis 7, the .NET ASP.NET runtime, Node.js 20, and supervisord. Built artifacts from the first two stages are copied in, and supervisord is configured to manage all seven processes.

The build stages are discarded — only the slim runtime artifacts make it into the final image. No SDKs, no build tools, no source code.

### Process Management with supervisord

Running seven processes (PostgreSQL, Redis, API, frontend, three workers) inside a single container requires a process manager. Supervisord handles startup ordering (database first, then API, then workers), automatic restarts on crash, and graceful shutdown propagation.

### Smart Initialization

The container's entrypoint script handles first-run setup automatically: initializing the PostgreSQL data directory, creating the database and user, setting permissions, and mapping user-friendly environment variables to the formats each service expects. On subsequent starts, it detects the existing data and skips initialization.

## CI/CD: Cross-Repository Automation

TorrentClou is split across three GitHub repositories — frontend, backend, and deployment. The CI/CD pipeline uses **GitHub Actions** with a cross-repository dispatch pattern:

When code is merged to `main` in either the frontend or backend repo, a lightweight workflow sends a `repository_dispatch` event to the deployment repo. The deployment repo's workflow checks out both source repos, builds the combined Docker image, and pushes it to the **GitHub Container Registry**.

Images are tagged with a date and the Git SHA from both repos (e.g., `2026.02.23-57e3b9d-132725a`), making it trivial to trace exactly which code is in each image.

A concurrency control ensures that if both repos merge simultaneously, only one build runs — preventing wasted compute and race conditions on the `latest` tag.

## Engineering Decisions Worth Noting

**Why a single image instead of docker-compose?**
User experience. `docker run` is universally understood. Docker Compose adds a YAML file, version compatibility concerns, and networking concepts that trip up less experienced users. The all-in-one image trades some operational flexibility for dramatically lower barrier to entry.

**Why supervisord over alternatives?**
Simplicity and maturity. Alternatives like s6-overlay or tini+bash are lighter, but supervisord's INI configuration is readable by anyone, its priority-based startup ordering is straightforward, and it's been battle-tested for over a decade.

**Why .NET for the backend?**
Performance, type safety, and the mature ecosystem. ASP.NET Core consistently ranks among the fastest web frameworks in benchmarks. Entity Framework Core's migration system handles schema evolution cleanly. And the background processing ecosystem (Hangfire) is production-grade.

**Why separate workers instead of in-process background tasks?**
Isolation. A memory leak in the torrent download code shouldn't take down the API. A slow S3 upload shouldn't block Google Drive syncs. Independent processes can be monitored, restarted, and scaled independently.

## What I Learned

Building TorrentClou reinforced a few lessons:

- **Deployment is a feature.** The best application in the world doesn't matter if people can't run it. Investing in the Docker image and run scripts paid off more than any individual feature.

- **Cross-repo CI/CD is tricky but worth it.** Keeping frontend and backend in separate repos with independent lifecycles, while still producing a unified artifact, required careful orchestration. The `repository_dispatch` pattern solved it cleanly.

- **Clean Architecture scales down too.** Even for a project of this size, the layered architecture made it possible to add the three workers without touching the API code — they share the Core and Infrastructure layers but run completely independently.

## Try It

TorrentClou is open source and available on GitHub. Running it takes one command:

```bash
git clone https://github.com/TorrenClou/deploy.git
cd deploy
cp .env.example .env
# Edit .env with your secrets
./run.sh
```

Frontend at `http://localhost:3000`. API at `http://localhost:5000/api`.

---

**Tech Stack Summary:** Next.js 15 | React 18 | TypeScript | Tailwind CSS | .NET 9.0 | ASP.NET Core | Entity Framework Core | PostgreSQL 15 | Redis 7 | Hangfire | Docker | GitHub Actions | supervisord

**GitHub:** [github.com/TorrenClou](https://github.com/TorrenClou)
