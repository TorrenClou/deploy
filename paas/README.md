# Deploying on a PaaS

Full instructions are at **[tc.gitnasr.com/docs](https://tc.gitnasr.com/docs)**.
This directory holds the files each platform reads.

| Platform | File | Notes |
|----------|------|-------|
| [Dokploy](dokploy/) | `docker-compose.yml` | Traefik fronts it; attach a domain to port 47100 |
| [Coolify](coolify/) | `docker-compose.yml` | Uses Coolify's `SERVICE_FQDN_*` magic variables |
| [Render](render/) | `render.yaml` | Blueprint. Needs the `standard` plan and a 20 GB disk |
| [Railway](railway/) | `railway.json` + README | Needs a volume at `/data`; not a one-click template yet |

## They all run the all-in-one image, and that is deliberate

The obvious design is one service per component, with managed PostgreSQL and
Redis. It does not work, for a reason that is easy to miss until you deploy it:

**The three workers share a filesystem.** The torrent worker downloads to
`/data/downloads`; the Google Drive and S3 workers read those files back to
upload them. On Render and Railway a disk attaches to exactly one service, so
split across services the upload workers cannot see what the torrent worker
produced and every upload fails. Neither platform offers a shared filesystem to
fix it with.

Mounting a single volume at `/data` on the all-in-one image solves that, and
persists the database, Redis and the first-boot secrets at the same time. The
usual objection — that a PaaS filesystem is ephemeral, so the bundled database
dies on redeploy — stops applying once there is a disk.

The trade is a larger instance, because it runs nine processes and PostgreSQL.
Budget at least 2 GB of memory.

If you do want split services, `../compose/docker-compose.split.yml` does it
properly, because a Docker named volume **can** be shared between containers.
That is a self-hosting topology, not a PaaS one.

## The volume is the whole game

Everything that must survive a redeploy is under `/data`:

| Path | Contents |
|------|----------|
| `/data/postgres` | The database **and** the secrets generated on first boot |
| `/data/redis` | Job state |
| `/data/downloads` | In-flight downloads, shared by all three workers |

Without it, every deploy is a fresh install: new database, new signing keys,
every account and storage connection gone. Nothing warns you, because from the
container's point of view it is simply booting for the first time again.

## Pinning a version

Every file defaults to `latest` and honours `TORRENCLOU_VERSION`:

```
TORRENCLOU_VERSION=1.1.0
```

See [Updating](https://tc.gitnasr.com/docs/updating) for what rolling back does
to the database, and why the guard exists.
